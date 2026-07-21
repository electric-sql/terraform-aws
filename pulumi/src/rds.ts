import * as aws from "@pulumi/aws"
import * as pulumi from "@pulumi/pulumi"

/**
 * RDS Postgres with logical replication enabled (required by Electric)
 * via the rds.logical_replication parameter.
 */
export function createDatabase(args: {
  vpcId: pulumi.Input<string>
  vpcCidrBlock: pulumi.Input<string>
  privateSubnetIds: pulumi.Input<string[]>
  username: string
  password: pulumi.Input<string>
  dbName: string
}): { instance: aws.rds.Instance; connectionUri: pulumi.Output<string> } {
  const securityGroup = new aws.ec2.SecurityGroup("rds", {
    vpcId: args.vpcId,
    description: "Postgres access from inside the VPC",
    // Taken from the VPC rather than hardcoded, so the rule cannot drift
    // from the network the instance actually sits in.
    ingress: [
      {
        protocol: "tcp",
        fromPort: 5432,
        toPort: 5432,
        cidrBlocks: [args.vpcCidrBlock],
      },
    ],
  })

  const subnetGroup = new aws.rds.SubnetGroup("electric", {
    subnetIds: args.privateSubnetIds,
  })

  const parameterGroup = new aws.rds.ParameterGroup("electric-logical", {
    family: "postgres15",
    parameters: [
      {
        name: "rds.logical_replication",
        value: "1",
        applyMethod: "pending-reboot",
      },
    ],
  })

  const instance = new aws.rds.Instance("electric", {
    engine: "postgres",
    engineVersion: "15",
    instanceClass: "db.t4g.micro",
    allocatedStorage: 20,
    dbName: args.dbName,
    username: args.username,
    password: args.password,
    dbSubnetGroupName: subnetGroup.name,
    vpcSecurityGroupIds: [securityGroup.id],
    parameterGroupName: parameterGroup.name,
    applyImmediately: true,
    skipFinalSnapshot: true,
  })

  // instance.endpoint is "host:port".
  const connectionUri = pulumi.interpolate`postgresql://${args.username}:${args.password}@${instance.endpoint}/${args.dbName}?sslmode=require`

  return { instance, connectionUri }
}
