variable "project" {
  description = "Project name for tagging/abstraction."
  type        = string
}

variable "ecr_repositories_string" {
  description = "ECR repository sub-names to create/check (each becomes <project>/<name>). Ignored when repository is set."
  type        = string
  default     = "default"
}

variable "repository" {
  description = "Full ECR repository name to create/check, overriding the <project>/<ecr_repositories_string> convention. If empty, the convention is used."
  type        = string
  default     = ""
}

variable "force_delete" {
  description = "Allow the repository to be deleted even if it still contains images (on destroy)."
  type        = bool
  default     = false
}

variable "aws_deployment_assume_role_arn" {
  description = "Deployment role to assume"
  type        = string
}

variable "aws_tags_name" {
  description = "Infra tags name"
  type        = string
}

variable "aws_region" {
  default     = "us-east-2"
  description = "Targeted AWS region"
  type        = string
}

variable "aws_access_key" {
  type        = string
  description = "AWS access key"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key"
}


#----------------------------------------------------------
# Docker / ECR
#----------------------------------------------------------
variable "image_local_day_retention_count" {
  description = "Number of days past to delete dev images"
  type        = number
  default     = 15
}

variable "lower_env_image_retention_count" {
  description = "Number of images retained for lower environments"
  type        = number
  default     = 25
}

variable "lambda_pull_account_ids" {
  description = "AWS account IDs whose Lambda functions may pull images from this repository. Container-image Lambdas require the repository policy to grant the lambda.amazonaws.com service principal (even same-account). Defaults to the Data Platform development, staging, and production accounts."
  type        = list(string)
  default     = ["559587901710", "001553724852", "870288520478"]
}
