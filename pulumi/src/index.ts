import * as aws from "@pulumi/aws"
import * as pulumi from "@pulumi/pulumi"
import { createVpc } from "./vpc"
import { createDatabase } from "./rds"
import { createLoadBalancer } from "./alb"
import { createEc2Capacity, DataStorage } from "./ec2-capacity"
import { createElectricService } from "./service"

const config = new pulumi.Config()

// "FARGATE" (simplest) or "EC2" (persistent NVMe/EBS storage).
const launchType = (config.get("launchType") ?? "FARGATE") as
  | "FARGATE"
  | "EC2"
if (launchType !== "FARGATE" && launchType !== "EC2") {
  throw new Error(`launchType must be FARGATE or EC2, got ${launchType}`)
}

// EC2-only settings (ignored for FARGATE). m6id.large has 118 GB of
// local NVMe instance store; pair m6a/m6i/m7a/m7i with kind "ebs-gp3".
const instanceType = config.get("instanceType") ?? "m6id.large"
const dataStorage =
  config.getObject<DataStorage>("dataStorage") ?? ({ kind: "nvme" } as const)
// Task sized to the host: full vCPUs; host memory minus ~2 GiB for the
// OS, Docker and ECS agent. Defaults fit m6id.large (2 vCPU / 8 GiB).
const taskCpu = config.getNumber("taskCpu") ?? (launchType === "EC2" ? 2048 : 256)
const taskMemoryMib =
  config.getNumber("taskMemoryMib") ?? (launchType === "EC2" ? 6144 : 512)

const dockerImageTag = config.get("dockerImageTag") ?? "latest"
const electricSecret = config.requireSecret("electricSecret")
const tlsCertificateArn = config.get("tlsCertificateArn")
const rdsUsername = config.get("rdsUsername") ?? "postgres"
const rdsPassword = config.requireSecret("rdsPassword")
const rdsDbName = config.get("rdsDbName") ?? "main"
const instanceLabel = "main"

const region = aws.getRegionOutput().name

const vpc = createVpc()

const database = createDatabase({
  vpcId: vpc.vpcId,
  privateSubnetIds: vpc.privateSubnetIds,
  username: rdsUsername,
  password: rdsPassword,
  dbName: rdsDbName,
})

const cluster = new aws.ecs.Cluster("electric", {})

const capacity =
  launchType === "EC2"
    ? createEc2Capacity({
        clusterName: cluster.name,
        vpcId: vpc.vpcId,
        subnetIds: vpc.publicSubnetIds,
        instanceType,
        dataStorage,
        instanceLabel,
      })
    : undefined

const lb = createLoadBalancer({
  vpcId: vpc.vpcId,
  publicSubnetIds: vpc.publicSubnetIds,
  tlsCertificateArn,
})

createElectricService({
  clusterArn: cluster.arn,
  vpcId: vpc.vpcId,
  publicSubnetIds: vpc.publicSubnetIds,
  targetGroupArn: lb.targetGroup.arn,
  lbSecurityGroupId: lb.securityGroup.id,
  launchType,
  capacityProviderName: capacity?.capacityProvider.name,
  taskCpu,
  taskMemoryMib,
  dockerImageTag,
  environment: [
    { name: "ELECTRIC_LOG_LEVEL", value: "info" },
    { name: "DATABASE_URL", value: database.connectionUri },
    { name: "ELECTRIC_SECRET", value: electricSecret },
    { name: "ELECTRIC_INSTANCE_ID", value: "electric-aws-example" },
  ],
  instanceLabel,
  region,
})

export const loadBalancerDomain = lb.dnsName
export const rdsEndpoint = database.instance.endpoint
