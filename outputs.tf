# NOTE: See respective modules' outputs.tf file for descriptions of these outputs.

output "cloudfront_domain" {
  value = module.cloudfront.distribution_domain
}

output "load_balancer_domain" {
  value = module.load_balancer.dns_name
}

output "rds_connection_uri" {
  value     = module.rds.connection_uri
  sensitive = true
}

output "rds_db_name" {
  value = module.rds.db_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_username" {
  value = module.rds.username
}
