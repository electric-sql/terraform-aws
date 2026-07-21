import * as aws from "@pulumi/aws"
import * as pulumi from "@pulumi/pulumi"
import { renderUserData } from "./user-data"

/**
 * Storage backing for the host's /mnt/nvme mount:
 * - "nvme": the instance type's local NVMe instance store (i4i/m6id).
 *   AWS wires the devices up automatically; data does not survive host
 *   replacement (Electric rebuilds from Postgres).
 * - "ebs-gp3": attached gp3 data volume for compute-only instance types
 *   (m6a/m6i/m7a/m7i). IOPS/throughput are tunable in place.
 */
export type DataStorage =
  | { kind: "nvme" }
  | { kind: "ebs-gp3"; sizeGb: number; iops?: number; throughputMbps?: number }

/**
 * EC2 capacity for the ECS cluster: ECS-optimized AL2023 launch template,
 * single-instance autoscaling group with scale-in protection, and a
 * capacity provider with managed termination protection. The user-data
 * (shared/user-data.sh.tpl) formats the data disk(s) and mounts them at
 * /mnt/nvme before joining the cluster.
 */
export function createEc2Capacity(args: {
  clusterName: pulumi.Input<string>
  vpcId: pulumi.Input<string>
  subnetIds: pulumi.Input<string[]>
  instanceType: string
  dataStorage: DataStorage
  instanceLabel: string
}): {
  capacityProvider: aws.ecs.CapacityProvider
  asg: aws.autoscaling.Group
  instanceSecurityGroup: aws.ec2.SecurityGroup
} {
  // Task ENIs (awsvpc) carry their own security group; the instance
  // only needs outbound access (ECS agent, image pulls, SSM).
  const instanceSecurityGroup = new aws.ec2.SecurityGroup("ec2-instance", {
    vpcId: args.vpcId,
    description: "Container instance SG for Electric",
    egress: [
      {
        protocol: "-1",
        fromPort: 0,
        toPort: 0,
        cidrBlocks: ["0.0.0.0/0"],
        ipv6CidrBlocks: ["::/0"],
      },
    ],
  })

  const role = new aws.iam.Role("ec2-instance", {
    assumeRolePolicy: JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Principal: { Service: "ec2.amazonaws.com" },
          Action: "sts:AssumeRole",
        },
      ],
    }),
  })

  const policies = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
  policies.forEach((policyArn) => {
    new aws.iam.RolePolicyAttachment(
      `ec2-instance-${policyArn.split("/").pop()}`,
      { role: role.name, policyArn }
    )
  })

  const instanceProfile = new aws.iam.InstanceProfile("ec2-instance", {
    role: role.name,
  })

  // Latest x86_64 ECS-optimized Amazon Linux 2023 AMI.
  const ami = aws.ssm.getParameterOutput({
    name: "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id",
  }).value

  const blockDeviceMappings: aws.types.input.ec2.LaunchTemplateBlockDeviceMapping[] =
    [
      {
        deviceName: "/dev/xvda",
        ebs: {
          volumeSize: 30,
          volumeType: "gp3",
          deleteOnTermination: "true",
          encrypted: "true",
        },
      },
    ]
  if (args.dataStorage.kind === "ebs-gp3") {
    // /dev/sdf shows up as /dev/nvme1n1 on Nitro hosts, which the
    // user-data picks up via its non-root NVMe scan.
    blockDeviceMappings.push({
      deviceName: "/dev/sdf",
      ebs: {
        volumeSize: args.dataStorage.sizeGb,
        volumeType: "gp3",
        iops: args.dataStorage.iops ?? 3000,
        throughput: args.dataStorage.throughputMbps ?? 125,
        deleteOnTermination: "true",
        encrypted: "true",
      },
    })
  }

  const launchTemplate = new aws.ec2.LaunchTemplate("electric-ec2", {
    imageId: ami,
    instanceType: args.instanceType,
    iamInstanceProfile: { arn: instanceProfile.arn },
    userData: renderUserData(args.clusterName, args.instanceLabel),
    metadataOptions: {
      httpTokens: "required",
      httpEndpoint: "enabled",
    },
    networkInterfaces: [
      {
        // Instances live in public subnets without a NAT gateway; the
        // host ENI needs a public IP for image pulls and the ECS agent.
        associatePublicIpAddress: "true",
        securityGroups: [instanceSecurityGroup.id],
      },
    ],
    blockDeviceMappings,
  })

  const asg = new aws.autoscaling.Group("electric-ec2", {
    minSize: 1,
    maxSize: 1,
    desiredCapacity: 1,
    vpcZoneIdentifiers: args.subnetIds,
    launchTemplate: { id: launchTemplate.id, version: "$Latest" },
    // Required for ECS managed termination protection.
    protectFromScaleIn: true,
    healthCheckType: "EC2",
    healthCheckGracePeriod: 300,
    tags: [
      // Required tag for ECS-managed ASGs.
      { key: "AmazonECSManaged", value: "", propagateAtLaunch: true },
      { key: "Name", value: "electric-ec2", propagateAtLaunch: true },
    ],
  })

  // Gives ECS time to drain the container instance before termination.
  new aws.autoscaling.LifecycleHook("electric-ec2-terminate", {
    autoscalingGroupName: asg.name,
    lifecycleTransition: "autoscaling:EC2_INSTANCE_TERMINATING",
    heartbeatTimeout: 600,
    defaultResult: "CONTINUE",
  })

  const capacityProvider = new aws.ecs.CapacityProvider("electric-ec2", {
    autoScalingGroupProvider: {
      autoScalingGroupArn: asg.arn,
      managedTerminationProtection: "ENABLED",
      managedScaling: {
        status: "ENABLED",
        targetCapacity: 100,
        instanceWarmupPeriod: 120,
        minimumScalingStepSize: 1,
        maximumScalingStepSize: 1,
      },
    },
  })

  new aws.ecs.ClusterCapacityProviders("electric", {
    clusterName: args.clusterName,
    capacityProviders: [capacityProvider.name],
  })

  return { capacityProvider, asg, instanceSecurityGroup }
}
