import * as aws from "@pulumi/aws"
import * as pulumi from "@pulumi/pulumi"

/**
 * Public application load balancer in front of Electric, with a target
 * group health-checked on /v1/health (200 = fully ready).
 */
export function createLoadBalancer(args: {
  vpcId: pulumi.Input<string>
  publicSubnetIds: pulumi.Input<string[]>
  tlsCertificateArn?: string
}): {
  alb: aws.lb.LoadBalancer
  targetGroup: aws.lb.TargetGroup
  securityGroup: aws.ec2.SecurityGroup
  dnsName: pulumi.Output<string>
} {
  const securityGroup = new aws.ec2.SecurityGroup("lb", {
    vpcId: args.vpcId,
    description: "Public HTTP/HTTPS access to the load balancer",
    ingress: [80, 443].map((port) => ({
      protocol: "tcp",
      fromPort: port,
      toPort: port,
      cidrBlocks: ["0.0.0.0/0"],
      ipv6CidrBlocks: ["::/0"],
    })),
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

  const alb = new aws.lb.LoadBalancer("electric", {
    internal: false,
    loadBalancerType: "application",
    securityGroups: [securityGroup.id],
    subnets: args.publicSubnetIds,
  })

  // target_type "ip" matches awsvpc task ENIs on both Fargate and EC2.
  const targetGroup = new aws.lb.TargetGroup("electric", {
    port: 80,
    protocol: "HTTP",
    vpcId: args.vpcId,
    targetType: "ip",
    deregistrationDelay: 5,
    healthCheck: {
      protocol: "HTTP",
      path: "/v1/health",
      matcher: "200",
      timeout: 3,
      interval: 30,
      healthyThreshold: 2,
      unhealthyThreshold: 2,
    },
  })

  new aws.lb.Listener("http", {
    loadBalancerArn: alb.arn,
    port: 80,
    protocol: "HTTP",
    defaultActions: [{ type: "forward", targetGroupArn: targetGroup.arn }],
  })

  if (args.tlsCertificateArn) {
    new aws.lb.Listener("https", {
      loadBalancerArn: alb.arn,
      port: 443,
      protocol: "HTTPS",
      certificateArn: args.tlsCertificateArn,
      defaultActions: [{ type: "forward", targetGroupArn: targetGroup.arn }],
    })
  }

  return { alb, targetGroup, securityGroup, dnsName: alb.dnsName }
}
