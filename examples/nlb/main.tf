terraform {
  # backend "s3" {
  #   region               = "ap-southeast-2"
  #   bucket               = ""
  #   dynamodb_table       = ""
  #   encrypt              = true
  #   key                  = "terraform_state"
  #   workspace_key_prefix = ""
  #   profile              = ""
  # }

}

###############################################################
##########################VPC##################################
###############################################################


module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.1.0"

  ipv4_primary_cidr_block  = "10.0.0.0/16"

  context = module.this.context
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.1"

  availability_zones   = var.availability_zones
  vpc_id               = module.vpc.vpc_id
  igw_id               = [module.vpc.igw_id]
  ipv4_cidr_block = [ "10.0.0.0/16" ]
  nat_gateway_enabled  = true
  nat_instance_enabled = false

  context = module.this.context
}

###############################################################
###################ELASTIC BEANSTALK###########################
###############################################################

module "elastic_beanstalk_application" {
  source  = "cloudposse/elastic-beanstalk-application/aws"
  version = "0.11.1"

  description = "Test Elastic Beanstalk application"

  context = module.this.context
}
#Elastic Beanstalk Environment works if all resources in one account 
#If R53 resources are in a different account clone this module code down 
#to you local workspace and uncomment provider blocks in the R53 
#resources and update provider.tf files in the same directory. 
module "elastic_beanstalk_environment" {
  #source = "BITBUCKET URL"
  source = "../../"
  description                = var.description
  region                     = var.region
  availability_zone_selector = var.availability_zone_selector
  dns_zone_id                = var.dns_zone_id 
  
  wait_for_ready_timeout             = var.wait_for_ready_timeout
  elastic_beanstalk_application_name = module.elastic_beanstalk_application.elastic_beanstalk_application_name
  environment_type                   = var.environment_type
  loadbalancer_type                  = var.loadbalancer_type
  elb_scheme                         = var.elb_scheme
  tier                               = var.tier
  version_label                      = var.version_label
  force_destroy                      = var.force_destroy

  instance_type    = var.instance_type
  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type

  autoscale_min             = var.autoscale_min
  autoscale_max             = var.autoscale_max
  autoscale_measure_name    = var.autoscale_measure_name
  autoscale_statistic       = var.autoscale_statistic
  autoscale_unit            = var.autoscale_unit
  autoscale_lower_bound     = var.autoscale_lower_bound
  autoscale_lower_increment = var.autoscale_lower_increment
  autoscale_upper_bound     = var.autoscale_upper_bound
  autoscale_upper_increment = var.autoscale_upper_increment

  vpc_id               = module.vpc.vpc_id
  loadbalancer_subnets = module.subnets.public_subnet_ids
  application_subnets  = module.subnets.private_subnet_ids

  allow_all_egress = true

  additional_security_group_rules = [
    {
      type                     = "ingress"
      from_port                = 0
      to_port                  = 65535
      protocol                 = "-1"
      source_security_group_id = module.vpc.vpc_default_security_group_id
      description              = "Allow all inbound traffic from trusted Security Groups"
    }
  ]

  rolling_update_enabled  = var.rolling_update_enabled
  rolling_update_type     = var.rolling_update_type
  updating_min_in_service = var.updating_min_in_service
  updating_max_batch      = var.updating_max_batch

  application_port = var.application_port

  # https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html
  # https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html#platforms-supported.docker
  solution_stack_name = var.solution_stack_name

  additional_settings = var.additional_settings
  env_vars            = var.env_vars

  extended_ec2_policy_document = data.aws_iam_policy_document.minimal_s3_permissions.json
  prefer_legacy_ssm_policy     = false
  prefer_legacy_service_policy = false
  scheduled_actions            = var.scheduled_actions

  # Unhealthy threshold count and healthy threshold count must be the same for Network Load Balancers
  healthcheck_healthy_threshold_count   = 3
  healthcheck_unhealthy_threshold_count = 3

  # Health check interval must be either 10 seconds or 30 seconds for Network Load Balancers
  healthcheck_interval = 30

  context = module.this.context
}

data "aws_iam_policy_document" "minimal_s3_permissions" {
  statement {
    sid = "AllowS3OperationsOnElasticBeanstalkBuckets"
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation"
    ]
    resources = ["*"]
  }
}

locals {
    default_tags = {
    # Mandatory tags
    "msd:application-id"          = "RCA"
    "msd:cost-centre"             = "183500"
    "msd:environment-type"        = "dev" # FIXME. it isn't always dev
    "msd:environment-name"        = "RCA"
    "msd:resource-accountability" = "ocowa001"
    "msd:resource-responsibility" = "ocowa001"

    # Optional/useful tags
    "msd:resource-customer" = "Data Science and Products" # FIXME: this should be the general public maybe
    "msd:infra-management"  = "Olly Test Environment"
  }
}