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

## Prerequisites

- AWS credentials in your environment, via `AWS_PROFILE`,
  `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, SSO or an instance role.
  Pulumi uses the standard AWS SDK credential chain, so there is no
  profile to set in the stack config.
- Node.js.

The Pulumi CLI ships as a dev dependency here rather than a global
install: `npm install` puts a `pulumi` shim in `node_modules/.bin`, and
the matching CLI binary is downloaded and cached the first time it runs.
Run every Pulumi command through `npx` (or `pnpm exec pulumi` /
`yarn pulumi`) so it uses that local copy.

## Usage

Install dependencies, which also sets up the local `pulumi` CLI:

```sh
npm install
```

Log in to a state backend, then create a stack. Use `pulumi login` for
Pulumi Cloud, or `pulumi login --local` to keep state on this machine
(with `--local`, `--secret` config values are encrypted with a passphrase
you're prompted for):

```sh
npx pulumi login
npx pulumi stack init dev
```

Set the region and the two required secrets:

```sh
npx pulumi config set aws:region us-east-1
npx pulumi config set --secret electricSecret $(openssl rand -hex 32)
npx pulumi config set --secret rdsPassword <password>
```

The defaults deploy Fargate. For the EC2 launch type and storage options,
copy the relevant settings from
[`Pulumi.example.yaml`](./Pulumi.example.yaml) into your stack's config
file (`Pulumi.dev.yaml`), or set them with `npx pulumi config set`.

Deploy:

```sh
npx pulumi up
```

The `loadBalancerDomain` output is your Electric endpoint. See the
[AWS integration docs](https://electric-sql.com/docs/sync/integrations/aws)
for guidance on choosing a launch type and sizing storage.

## Tearing it down

Remove everything the stack created — the ECS service and cluster, the
EC2 container instance and its autoscaling group, the load balancer, the
RDS instance and the VPC:

```sh
npx pulumi destroy
```

The autoscaling group has scale-in protection enabled, but the launch
template sets `forceDelete: true`, so the destroy tears the instance down
instead of hanging on it. To also remove the (now empty) stack itself:

```sh
npx pulumi stack rm dev
```

> [!WARNING] The database is deleted without a final snapshot
> RDS is created with `skipFinalSnapshot: true`, so `pulumi destroy`
> removes it and all of its data with no backup. Take a snapshot first, or
> set `skipFinalSnapshot: false` in `src/rds.ts`, if you need to keep the
> data.

The ACM certificate (if you set `tlsCertificateArn`) and any DNS records
pointing at the load balancer are not managed by this stack; remove them
separately if you no longer need them.
