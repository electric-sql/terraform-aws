import * as awsx from "@pulumi/awsx"

/**
 * VPC with public subnets (load balancer, ECS hosts/tasks) and private
 * subnets (RDS). No NAT gateway: EC2 container instances get public IPs
 * instead, and nothing in the private subnets needs outbound internet.
 */
export function createVpc(): awsx.ec2.Vpc {
  return new awsx.ec2.Vpc("electric", {
    cidrBlock: "10.0.0.0/24",
    natGateways: { strategy: "None" },
    subnetSpecs: [
      { type: "Public", cidrMask: 28 },
      { type: "Private", cidrMask: 28 },
    ],
  })
}
