terraform {
  required_version = ">= 1.13.3"

  backend "s3" {
    bucket = "terraform-559587901710"
    # workspace_key_prefix = var.project
    # key                  = "${var.project}-ecr-terraform.tfstate"
    encrypt      = true
    region       = "us-east-2"
    use_lockfile = true
  }


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.30.0"
    }
  }
}

provider "aws" {
  alias      = "tagged"
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  default_tags {
    tags = local.aws_tags
  }

  assume_role {
    role_arn     = var.aws_deployment_assume_role_arn
    session_name = "${local.name_prefix}terraform"
  }
}

data "aws_ssm_parameter" "aws_tags" {
  provider = aws.tagged
  name     = var.aws_tags_name
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  default_tags {
    tags = merge(jsondecode(data.aws_ssm_parameter.aws_tags.value), local.aws_tags)
  }

  assume_role {
    role_arn     = var.aws_deployment_assume_role_arn
    session_name = "${local.name_prefix}terraform"
  }
}
