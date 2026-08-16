locals {
  project = var.project

  # Development, Staging, UAT, and Production images are all in the same ECR repository
  deployment_name = local.project
  name            = local.deployment_name
  name_prefix     = "${local.name}-"

  aws_tags = {
    ResourcePrefix = local.name
  }

  # Fully qualified ECR repository name(s). Keyed by the full name so the resource
  # address is consistent whether the name is composed from <project>/<sub-name>
  # or provided explicitly via the repository override.
  ecr_repository_names = var.repository != "" ? [var.repository] : [
    for r in split(",", var.ecr_repositories_string) : "${local.project}/${r}"
  ]
}
