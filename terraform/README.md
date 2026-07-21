# Electric on AWS ECS — Terraform

Provisions an ECS cluster running the
[Electric sync service](https://electric-sql.com) behind an Application
Load Balancer, connected to an instance of RDS for PostgreSQL.

> [!WARNING]
> This configuration is a starting point, not a turn-key production
> deployment. Review it carefully — particularly the network and secrets
> handling — before running it in a production setting.

## Overview

`terraform apply` with no modifications provisions:

- a new VPC with two private and two public subnets
- an instance of RDS for PostgreSQL with logical replication enabled
- the Electric sync service, running the
  [`electricsql/electric`](https://hub.docker.com/r/electricsql/electric)
  image on ECS
- an Application Load Balancer with HTTP and HTTPS listeners, both routing
  to Electric's HTTP port and health-checked on `/v1/health`

## Choosing a launch type

`launch_type` selects how the Electric task runs:

- **`FARGATE`** (default) — simplest. Storage is ephemeral, so Electric
  rebuilds its shape-log cache from Postgres whenever a task restarts.
- **`EC2`** — runs one task on one container instance whose data disk is
  formatted and mounted at `/mnt/nvme` on boot (see
  [`../shared/user-data.sh.tpl`](../shared/user-data.sh.tpl)), then
  bind-mounted into the task as Electric's storage directory. The cache
  survives task restarts.

On EC2, `ec2_data_storage` selects the disk:

```hcl
# Local NVMe instance store — fastest. Requires an i4i/m6id instance type;
# capacity comes with the instance (m6id.large has 118 GB).
ec2_instance_type = "m6id.large"
ec2_data_storage  = { kind = "nvme" }

# Or an attached gp3 EBS volume — cheaper, and size/IOPS/throughput are
# tunable in place with a later `terraform apply`. Use a compute-only
# instance type (m6a/m6i/m7a/m7i).
ec2_instance_type = "m6a.large"
ec2_data_storage = {
  kind            = "ebs-gp3"
  size_gb         = 100
  iops            = 3000
  throughput_mbps = 125
}
```

Size the task to the host with `ec2_task_cpu` and `ec2_task_memory`: all
of the host's vCPUs, and its memory minus ~2 GiB left for the OS, Docker
and the ECS agent. The defaults (2048 / 6144) fit an `m6id.large`.

See the [AWS integration docs](https://electric-sql.com/docs/sync/integrations/aws)
for more on choosing between these.

## Usage

Run all commands from this `terraform/` directory.

1. Sign in to the AWS CLI, providing your access key id, secret key and
   region.

   ```shell
   aws configure --profile '<profile-name>'
   ```

2. Initialize the provider and local modules.

   ```shell
   terraform init
   ```

3. Copy the example variables file and edit the values to match your
   preferences. Use the same `<profile-name>` from step 1 for the
   `profile` variable.

   ```shell
   cp terraform.tfvars.example terraform.tfvars
   ```

   Set `electric_secret` to a long random string — clients need it to
   authenticate to the sync service.

4. Request a TLS certificate from
   [AWS Certificate Manager](https://console.aws.amazon.com/acm/home),
   providing a domain name such as `sync.example.com`. Note the domain
   down: you'll point it at the load balancer in step 8. (That is a
   *different* CNAME from the validation record in the next step.)

5. Verify your ownership of the domain by adding the validation CNAME
   record ACM shows you to your DNS provider, so AWS can issue the
   certificate. The "CNAME name" and "CNAME value" are in the "Domains"
   section of the certificate's page — scroll right if the table looks
   empty.

6. Put the ARN of the issued certificate in `tls_certificate_arn` in your
   `terraform.tfvars`.

7. Provision the infrastructure.

   ```shell
   terraform apply
   ```

8. Once the load balancer is up, create a CNAME record pointing the domain
   you chose in step 4 at the load balancer's generated domain name (the
   `load_balancer_domain` output). In Namecheap's advanced DNS view it
   looks like this:

   ![CNAME in Namecheap](../img/namecheap_cname.png)

9. Check that it's working. The health endpoint needs no authentication:

   ```shell
   $ curl -i https://sync.example.com/v1/health
   HTTP/2 200
   content-type: application/json

   {"status":"active"}
   ```

   A `202` with `{"status":"waiting"}` or `{"status":"starting"}` means
   Electric is still connecting to Postgres — give it a moment.

## Updating the sync service

Every new task pulls the latest image matching the configured tag, so to
upgrade Electric, stop the running task and let the ECS scheduler start a
replacement:

```shell
export AWS_DEFAULT_PROFILE='<profile-name>'

cluster_name=electric-cluster
aws ecs stop-task --cluster $cluster_name --task $(
  aws ecs list-tasks --cluster $cluster_name --query 'taskArns[0]' --output text
)
```

On EC2 the replacement task lands on the same host and picks up the
existing shape-log cache. Pin a specific version with `docker_image_tag`
rather than tracking `latest` if you want upgrades to be deliberate.

To change Electric's configuration, edit `container_environment` in the
`ecs_task_definition` module block in `main.tf` and rerun
`terraform apply`.

## Components

The configuration is split into local modules, each a more-or-less
self-contained logical unit. They're meant to be read and modified in
place, not consumed as standalone building blocks for other projects.

- [vpc](./modules/vpc) — VPC for the RDS instance, the ECS task and the
  load balancer
- [rds](./modules/rds) — RDS for Postgres with logical replication enabled
- [ecs_task_definition](./modules/ecs_task_definition) — the Electric task,
  including the storage bind mount on EC2
- [ecs_service](./modules/ecs_service) — the ECS service, placing tasks via
  Fargate or an EC2 capacity provider
- [ecs_ec2_capacity](./modules/ecs_ec2_capacity) — EC2 container instances:
  launch template, autoscaling group and capacity provider (`EC2` launch
  type only)
- [load_balancer](./modules/load_balancer) — Application Load Balancer for
  TLS termination and routing to Electric's HTTP port

## Input variables

Each module defines its own variables. Not all of them are exposed in the
top-level `variables.tf`, since their defaults suit a test deployment. To
customize one, either pass it in the module block in `main.tf` directly or
add a matching top-level variable and reference it there.

## Connecting to an external database

To use a database you already run, pass its connection URI as the
`DATABASE_URL` value in `container_environment` instead of
`module.rds.connection_uri`, and drop the `rds` module block. The database
needs [logical replication](https://electric-sql.com/docs/sync/guides/deployment#_1-running-postgres)
enabled, and must be reachable from the VPC — either over the public
internet or via a network link you provide.

## Support

We'd like to hear about your experience using this configuration and
adapting it to your needs. Come and say hello in our
[community Discord](https://discord.electric-sql.com) if you have
questions or need a hand getting things running.
