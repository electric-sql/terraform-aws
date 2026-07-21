# electric-aws

Example configurations for deploying the
[Electric sync service](https://electric-sql.com) to AWS ECS, in two
flavours:

- [`terraform/`](./terraform) — Terraform (>= 1.3)
- [`pulumi/`](./pulumi) — Pulumi (TypeScript)

Both provision the same stack: a VPC, an RDS Postgres with logical
replication enabled, an ECS cluster running the
[electricsql/electric](https://hub.docker.com/r/electricsql/electric)
container, and an application load balancer in front.

## Choosing a launch type

| | Storage | Best for |
|---|---|---|
| **Fargate** (default) | Ephemeral | Trying Electric out; light workloads |
| **EC2 + NVMe instance store** (`i4i`/`m6id` types) | Local NVMe, fastest | Disk-intensive production workloads |
| **EC2 + gp3 EBS data volume** (`m6a`/`m6i`/`m7a`/`m7i` types) | Attached EBS, tunable IOPS/throughput | Production workloads at lower cost |

Electric treats its on-disk shape logs as a rebuildable cache, so
losing the disk on host replacement is safe — but disk speed directly
drives sync performance. See the
[deployment guide](https://electric-sql.com/docs/sync/guides/deployment)
and the
[AWS integration docs](https://electric-sql.com/docs/sync/integrations/aws)
for details.

On EC2, the instance's boot script
([`shared/user-data.sh.tpl`](./shared/user-data.sh.tpl)) discovers every
non-root NVMe device — local instance store or attached EBS (both appear
as `/dev/nvme*` on Nitro hosts) — RAID0s multiples, formats XFS and
mounts at `/mnt/nvme`, then joins the ECS cluster. The Electric task
bind-mounts the resulting directory as its storage dir.

## Usage

See [`terraform/`](./terraform) (start from
`terraform.tfvars.example`) or [`pulumi/README.md`](./pulumi/README.md)
(start from `Pulumi.example.yaml`).

### TLS certificate

The load balancer serves HTTPS using an [AWS ACM](https://docs.aws.amazon.com/acm/latest/userguide/gettingstarted.html) certificate:

1. Request a public certificate in ACM, in the same region you deploy to.
2. Validate it via DNS by creating the CNAME record ACM shows you.
3. Pass its ARN as `tls_certificate_arn` (Terraform) or
   `electric-aws:tlsCertificateArn` (Pulumi).

In the Terraform config the certificate is required. In the Pulumi config
it is optional — omit it to serve plain HTTP only.

> This repo was previously `electric-sql/terraform-aws`; old links
> redirect here.
