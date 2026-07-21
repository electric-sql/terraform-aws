import * as aws from "@pulumi/aws"
import * as pulumi from "@pulumi/pulumi"

/**
 * The Electric task definition + ECS service. On EC2, the shape-log
 * storage is a bind mount from the host's bootstrap-formatted data disk
 * (/mnt/nvme/electric/<label>) and ELECTRIC_STORAGE_DIR points at the
 * container-side mount path.
 */
export function createElectricService(args: {
  clusterArn: pulumi.Input<string>
  vpcId: pulumi.Input<string>
  publicSubnetIds: pulumi.Input<string[]>
  targetGroupArn: pulumi.Input<string>
  lbSecurityGroupId: pulumi.Input<string>
  launchType: "FARGATE" | "EC2"
  capacityProviderName?: pulumi.Input<string>
  taskCpu: number
  taskMemoryMib: number
  dockerImageTag: string
  environment: pulumi.Input<{ name: string; value: pulumi.Input<string> }[]>
  instanceLabel: string
  region: pulumi.Input<string>
  dependsOn?: pulumi.Resource[]
}): { service: aws.ecs.Service; taskDefinition: aws.ecs.TaskDefinition } {
  const isEc2 = args.launchType === "EC2"

  const logGroup = new aws.cloudwatch.LogGroup("electric", {
    retentionInDays: 1,
  })

  const executionRole = new aws.iam.Role("task-execution", {
    assumeRolePolicy: JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Principal: { Service: "ecs-tasks.amazonaws.com" },
          Action: "sts:AssumeRole",
        },
      ],
    }),
  })
  new aws.iam.RolePolicyAttachment("task-execution", {
    role: executionRole.name,
    policyArn:
      "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  })

  const containerDefinitions = pulumi
    .all([pulumi.output(args.environment), logGroup.name, args.region])
    .apply(([environment, logGroupName, region]) =>
      JSON.stringify([
        {
          essential: true,
          name: "electric-sync",
          image: `docker.io/electricsql/electric:${args.dockerImageTag}`,
          portMappings: [
            {
              name: "http",
              containerPort: 3000,
              hostPort: 3000,
              protocol: "tcp",
              appProtocol: "http",
            },
          ],
          mountPoints: isEc2
            ? [
                {
                  sourceVolume: "electric-data",
                  containerPath: "/var/lib/electric",
                },
              ]
            : [],
          environment: [
            ...environment,
            ...(isEc2
              ? [
                  {
                    name: "ELECTRIC_STORAGE_DIR",
                    value: "/var/lib/electric",
                  },
                ]
              : []),
          ],
          logConfiguration: {
            logDriver: "awslogs",
            options: {
              "awslogs-create-group": "true",
              "awslogs-group": logGroupName,
              "awslogs-region": region,
              "awslogs-stream-prefix": "electric-sync",
            },
          },
        },
      ])
    )

  const taskDefinition = new aws.ecs.TaskDefinition("electric-sync", {
    family: "electric-sync",
    networkMode: "awsvpc",
    requiresCompatibilities: [args.launchType],
    cpu: String(args.taskCpu),
    memory: String(args.taskMemoryMib),
    executionRoleArn: executionRole.arn,
    runtimePlatform: {
      operatingSystemFamily: "LINUX",
      cpuArchitecture: "X86_64",
    },
    volumes: isEc2
      ? [
          {
            name: "electric-data",
            hostPath: `/mnt/nvme/electric/${args.instanceLabel}`,
          },
        ]
      : undefined,
    containerDefinitions,
  })

  // Task ENI security group: HTTP from the load balancer only.
  const taskSecurityGroup = new aws.ec2.SecurityGroup("electric-task", {
    vpcId: args.vpcId,
    description: "Electric task ENI SG",
    ingress: [
      {
        protocol: "tcp",
        fromPort: 3000,
        toPort: 3000,
        securityGroups: [args.lbSecurityGroupId],
      },
    ],
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

  const service = new aws.ecs.Service("electric-sync", {
    cluster: args.clusterArn,
    taskDefinition: taskDefinition.arn,
    desiredCount: 1,
    healthCheckGracePeriodSeconds: 60,
    // launchType and capacityProviderStrategies are mutually exclusive.
    ...(isEc2
      ? {
          capacityProviderStrategies: [
            {
              capacityProvider: args.capacityProviderName!,
              weight: 1,
              base: 1,
            },
          ],
        }
      : { launchType: "FARGATE" }),
    // Single-host deployment: stop the old task before starting the new
    // one (it needs the same host's storage and the replication slot).
    deploymentMinimumHealthyPercent: 0,
    deploymentMaximumPercent: 100,
    networkConfiguration: {
      securityGroups: [taskSecurityGroup.id],
      subnets: args.publicSubnetIds,
      // Fargate pulls images via the task ENI, so it needs a public IP.
      // EC2 task ENIs cannot have one (pulls go via the host ENI).
      assignPublicIp: !isEc2,
    },
    loadBalancers: [
      {
        targetGroupArn: args.targetGroupArn,
        containerName: "electric-sync",
        containerPort: 3000,
      },
    ],
  }, { ignoreChanges: ["desiredCount"], dependsOn: args.dependsOn }) // keeps Pulumi from fighting AWS when the task fails to start and desired count is adjusted

  return { service, taskDefinition }
}
