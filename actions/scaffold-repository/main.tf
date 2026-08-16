terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
  }
}

# Configure the GitHub provider
provider "github" {
  # The token will be sourced from GITHUB_TOKEN environment variable in the workflow
  token = var.github_token
  owner = "Zotec-Product-Development"
}

resource "github_repository" "new" {
  name = "${var.github_repository}" # Replace with your repository full name
  description = "This repository was created using Terraform and GitHub Actions"
  visibility = "internal"
  has_discussions = false
  has_projects = false
  has_wiki = false

  allow_squash_merge = true
  squash_merge_commit_title = "PR_TITLE"
  squash_merge_commit_message = "BLANK"

  allow_merge_commit = false
  allow_auto_merge = true
  allow_rebase_merge = false
  delete_branch_on_merge = true
  auto_init = false
}