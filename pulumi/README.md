# Electric on AWS ECS — Pulumi

Deploys the [Electric sync service](https://electric-sql.com) to AWS ECS,
with a choice of launch type:

- **Fargate** — simplest; ephemeral storage (Electric rebuilds its
  shape-log cache from Postgres on restart).
- **EC2** — a single container instance whose local NVMe instance store
  (i4i/m6id instance types) or attached gp3 EBS volume is formatted and
  mounted on boot by `../shared/user-data.sh.tpl`, then bind-mounted into
  the task as Electric's storage directory.

Also provisions a VPC, an RDS Postgres with logical replication enabled,
and an application load balancer health-checked on `/v1/health`.

## Usage

```sh
npm install
pulumi stack init dev
# copy config from Pulumi.example.yaml, then:
pulumi config set --secret electricSecret $(openssl rand -hex 32)
pulumi config set --secret rdsPassword <password>
pulumi up
```

The `loadBalancerDomain` output is your Electric endpoint. See the
[AWS integration docs](https://electric-sql.com/docs/sync/integrations/aws)
for guidance on choosing a launch type and sizing storage.
