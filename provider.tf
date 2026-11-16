# Terraform + provider setup for the Floci local AWS emulator.
# Every AWS API call is redirected to Floci (default http://localhost:4566).

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = "floci" # any non-empty value works with Floci
  secret_key = "floci"

  # Floci is not real AWS: skip the checks that call real AWS endpoints.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  # Required so S3 calls work against a single local endpoint.
  s3_use_path_style = true

  endpoints {
    ec2            = var.floci_endpoint
    elbv2          = var.floci_endpoint
    s3             = var.floci_endpoint
    dynamodb       = var.floci_endpoint
    sqs            = var.floci_endpoint
    sns            = var.floci_endpoint
    iam            = var.floci_endpoint
    sts            = var.floci_endpoint
    cloudwatch     = var.floci_endpoint
    cloudwatchlogs = var.floci_endpoint
  }

  default_tags {
    tags = var.tags
  }
}
