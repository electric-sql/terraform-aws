ElectricSQL on Amazon ECS
=========================

Terraform configuration for provisioning an ECS cluster to run [ElectricSQL](https://electric-sql.com/) behind a Network Load Balancer, connected to an instance of RDS for PostgreSQL, together with a CloudFront distribution backed by an S3 bucket for hosting assets of the local-first web app.

> [!WARNING]
> This Terraform configuration is a **work in progress**. We don't recommend using it
> in a production setting just yet.
>
> Please let us know if you notice any bugs, missing configuration or poorly chosen
> defaults. See "Contributing" and "Support" sections at the bottom.

## Overview

The top-level configuration is comprised of logical modules, providing a concise and high-level overview of the whole setup. Each module is defined in a subdirectory of the top-level `modules/` directory. The only external dependency used is the [hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) provider.

This is meant to be used as a starting point for a production deployment of your electrified local-first app to AWS. Feel free to make changes to it and adapt the included modules to your needs.

Running `terraform apply` for this configuration without any modifications will provision the following infrastructure:

  - a new VPC with two private subnets and one public subnet
  - an instance of RDS for PostgreSQL that has logical replication enabled
  - Electric sync service running the `electricsql/electric:latest` image [from Docker Hub](https://hub.docker.com/r/electricsql/electric) as a Fargate task on ECS
  - a new S3 bucket for hosting your web app's assets
  - a CloudFront distribution to serve the web app

Things you can customize with input variables:

  - the name of each logical component
  - database credentials
  - domain names used for the CloudFront distribution and the NLB

**NOTE:** when building a new infrastructure from scratch for the first time, a few manual steps will be required, such as initializing the remote state for Terraform, validating a TLS certificate request for your custom domain, etc. See the next section for a complete walkthrough.

## Usage

### Initial setup

To set up a new infra from scratch, follow these steps:

  1. Sign in to AWS CLI and input your access key id, secret key and region.

     ```shell
     aws configure --profile '<profile-name>'
     ```

  2. Initialize the provider and local modules.

     ```shell
     terraform init
     ```

  3. Copy the `terraform.tfvars.example` file and edit the variable values in it to match your
     preferences. Use the same `<profile-name>` you specified above for the `profile` variable in
     your `terraform.tfvars` file.

     ```shell
     cp terraform.tfvars.example terraform.tfvars
     ```

  4. Finally, provision the infrastructure.

     ```shell
     terraform apply
     ```

  5. TODO: Validate the certificate request.
  5. TODO: Add a CNAME to your domain pointing at the Load Balancer endpoint.
  5. TODO: Add a CNAME to your domain pointing at the Cloudfront distribution endpoint.

### Deploying the web app

With the S3-backend CloudFront setup created by the configuration in this repo, all you need to release a new version of your web app is upload its latest assets to the S3 bucket.

```shell
# Change directory to your web app. For example,
cd examples/web-wa-sqlite

# Build app assets
npm run build

# Upload the assets to the S3 bucket, deleting previous versions of the bundles
# and other remote files that are no longer included in the local build.
aws s3 sync dist/ s3://electric-aws-example-app-bucket --delete
```

### Updating the sync service

To upgrade the running Electric sync service to a new version of the Docker image, stop the current task and wait for the ECS scheduler to start a new task automatically. Every time a new Fargate task is started, it pulls the latest Docker image matching the configured tag from Docker Hub. The image tag to use is specified in `module.ecs_task_definition` in `main.tf`.

```shell
# Make sure you have the correct profile selected in your terminal
export AWS_DEFAULT_PROFILE='<profile-name>'

# Replace cluster_name below with your actual ECS cluster name
cluster_name=electric_ecs_cluster
aws ecs stop-task --cluster $cluster_name --task $(
  aws ecs list-tasks --cluster $cluster_name --query 'taskArns[0]' --output text
)
```

To update the sync service's configuration, edit `module.ecs_task_definition.container_environment` in `main.tf` and rerun the provisioning command:

```shell
terraform apply
```

## Components

The configuration in this repo is split into a set of local modules which service as more-or-less self-contained logical units, making it easier to read through and modify. They are not meant to be used as standalone building blocks for other projects.

Included modules:

  - [vpc](./modules/vpc) - custom VPC for the RDS instance, the ECS task, and the Network Load Balancer
  - [rds](./modules/rds) - instance of RDS for Postgres with logical replication enabled
  - [ecs_task_definition](./modules/ecs_task_definition) - Fargate task for the Electric sync service based on the [Docker Hub image](https://hub.docker.com/r/electricsql/electric)
  - [ecs_service](./modules/ecs_service) - custom ECS cluster with one Fargate service that uses the task definition from above
  - [load_balancer](./modules/load_balancer) - Network Load Balancer for SSL termination and routing traffic to the sync service's HTTP and TCP ports
  - [s3](./modules/s3) - S3 bucket to host the web app's assets
  - [cloudfront](./modules/cloudfront) - CloudFront distribution for serving the web app

## Input variables

Each local module defines a set of variables, allowing one to modify its internal configuration. Not all of those variables are exposed in the top-level `variables.tf` file since they have default values suitable for provisioning a test infra. If you want to set custom values for some of those module variables, reference them in the `main.tf` file directly or add new variable definitions to the top-level `variables.tf` to use in module arguments in the `main.tf` file.

## Use cases

### Connecting to existing RDS instance

TODO...

If you already have an externally-managed RDS instance that has logical replication enabled, you can add its connection URI as an input variable to this configuration and reference it in the `DATABASE_URL` config passed to the `ecs_task_definition`'s `container_environment`.

You will need to import the existing VPC in that case and adjust the CIDR blocks, instead of creating a brand new VPC to be managed by the Terraform configuration.

```shell
terraform import vpc ... subnets ...
```

### Connecting to external database

If the database you want Electric to connect to is running in a VPC you don't have control over or even outside of AWS, you can pass its full connection URI to the `DATABASE_URL` config. The database must either be accessible over the public Internet, or you need to create the necessary network link between your VPC and the external database.

### Importing existing VPC

TODO...

### Importing existing TLS certificates

TODO...


## Contributing

See the [Community Guidelines](https://github.com/electric-sql/electric/blob/main/CODE_OF_CONDUCT.md) including the [Guide to Contributing](https://github.com/electric-sql/electric/blob/main/CONTRIBUTING.md) and [Contributor License Agreement](https://github.com/electric-sql/electric/blob/main/CLA.md).

## Support

We'd be happy to learn about your experience using this Terraform configuration and adapting it to your needs! We have an [open community Discord](https://discord.electric-sql.com). Come and say hello and let us know if you have any questions or need any help getting things running.
