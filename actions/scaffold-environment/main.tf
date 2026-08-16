terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

# Configure the GitHub provider
provider "github" {
  # The token will be sourced from GITHUB_TOKEN environment variable in the workflow
  token = var.github_token
  owner = "Zotec-Product-Development"
}

data "github_repository" "this" {
  name = var.github_repository
}

data "github_team" "infrastructure_admins" {
  slug = "Infrastructure-Admins"
}

data "github_team" "product_owners" {
  slug = "Data-Platform-PO"
}