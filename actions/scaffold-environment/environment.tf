locals {
  # The ephemeral "pr" environment deploys into the development account, so it
  # mirrors development's secrets/variables by default. Callers can override by
  # supplying an explicit "pr" key in environment_secrets/environment_variables.
  pr_environment_secrets   = try(var.environment_secrets["development"], {})
  pr_environment_variables = try(var.environment_variables["development"], {})

  effective_environment_secrets = merge(
    { pr = local.pr_environment_secrets },
    var.environment_secrets,
  )

  effective_environment_variables = merge(
    { pr = local.pr_environment_variables },
    var.environment_variables,
  )

  # Hotfix UAT entry is opt-in per repo (see repository_seed cicd.yml).
  default_repository_variables = {
    HAS_UAT = "false"
  }

  effective_repository_variables = merge(
    local.default_repository_variables,
    var.repository_variables,
  )

  environment_secret_pairs = flatten([
    for env, secrets in local.effective_environment_secrets : [
      for name, value in secrets : {
        environment = env
        name        = name
        value       = value
      }
    ]
  ])

  environment_variable_pairs = flatten([
    for env, variables in local.effective_environment_variables : [
      for name, value in variables : {
        environment = env
        name        = name
        value       = value
      }
    ]
  ])
}

# ========== Create a 'development' environment
resource "github_repository_environment" "development" {
  repository  = data.github_repository.this.name
  environment = "development"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "development" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.development.environment
  branch_pattern = "develop"
}

# ========== Create a 'pr' environment for ephemeral per-PR deployments
# No deployment_branch_policy block => all branches allowed, which is required
# because PR-triggered deploys run on the merge ref (refs/pull/<n>/merge) that
# branch/tag policies cannot match. No reviewers so PR runs are not gated.
resource "github_repository_environment" "pr" {
  repository  = data.github_repository.this.name
  environment = "pr"
}

# ========== Create a 'staging' environment
resource "github_repository_environment" "staging" {
  repository  = data.github_repository.this.name
  environment = "staging"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "staging" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.staging.environment
  branch_pattern = "develop"
}

resource "github_repository_environment_deployment_policy" "staging_hotfix" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.staging.environment
  branch_pattern = "zp-hotfix/*"
}

# ========== Create a 'uat' environment
resource "github_repository_environment" "uat" {
  repository  = data.github_repository.this.name
  environment = "uat"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "uat" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.uat.environment
  branch_pattern = "develop"
}

resource "github_repository_environment_deployment_policy" "uat_hotfix" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.uat.environment
  branch_pattern = "zp-hotfix/*"
}

# ========== Create an 'infrastructure-review' gate environment
# Approval-only checkpoint before production; it has no deploy target/tfvars and
# runs no Terraform. Reviewed by Infrastructure-Admins so infrastructure changes
# are signed off before the production apply (a separate gate). prevent_self_review
# keeps the run triggerer from approving their own review.
resource "github_repository_environment" "infrastructure_review" {
  repository          = data.github_repository.this.name
  environment         = "infrastructure-review"
  prevent_self_review = true

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }

  reviewers {
    teams = [data.github_team.infrastructure_admins.id]
  }
}

resource "github_repository_environment_deployment_policy" "infrastructure_review" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.infrastructure_review.environment
  branch_pattern = "develop"
}

resource "github_repository_environment_deployment_policy" "infrastructure_review_hotfix" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.infrastructure_review.environment
  branch_pattern = "zp-hotfix/*"
}

# ========== Create a 'production' environment
# Infrastructure sign-off happens at the preceding 'infrastructure-review' gate
# (Infrastructure-Admins); the production gate is the product-owner (PO) release
# approval.
resource "github_repository_environment" "production" {
  repository          = data.github_repository.this.name
  environment         = "production"
  prevent_self_review = true

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }

  reviewers {
    teams = [data.github_team.product_owners.id]
  }
}

resource "github_repository_environment_deployment_policy" "production" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.production.environment
  branch_pattern = "develop"
}

resource "github_repository_environment_deployment_policy" "production_hotfix" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.production.environment
  branch_pattern = "zp-hotfix/*"
}

# ========== Create environment secrets

resource "github_actions_environment_secret" "this" {
  for_each = {
    for pair in local.environment_secret_pairs : "${pair.environment}.${pair.name}" => pair
  }

  repository      = data.github_repository.this.name
  environment     = each.value.environment
  secret_name     = each.value.name
  plaintext_value = each.value.value

  depends_on = [
    github_repository_environment.development,
    github_repository_environment.pr,
    github_repository_environment.staging,
    github_repository_environment.uat,
    github_repository_environment.infrastructure_review,
    github_repository_environment.production
  ]
}

# Variables are set via the gh CLI (an upsert) rather than the
# github_actions_environment_variable resource, because Terraform state here is
# ephemeral (no remote backend) and the provider's create fails when a variable
# already exists. `gh variable set` creates or overrides idempotently.
resource "null_resource" "environment_variable" {
  for_each = {
    for pair in local.environment_variable_pairs : "${pair.environment}.${pair.name}" => pair
  }

  triggers = {
    environment = each.value.environment
    name        = each.value.name
    value       = each.value.value
    repository  = data.github_repository.this.name
  }

  provisioner "local-exec" {
    environment = {
      GH_TOKEN = var.github_token
    }
    command = "gh variable set ${each.value.name} --env ${each.value.environment} --repo Zotec-Product-Development/${data.github_repository.this.name} --body ${jsonencode(each.value.value)}"
  }

  depends_on = [
    github_repository_environment.development,
    github_repository_environment.pr,
    github_repository_environment.staging,
    github_repository_environment.uat,
    github_repository_environment.infrastructure_review,
    github_repository_environment.production
  ]
}



# ========== Create repository variables

resource "null_resource" "repository_variable" {
  for_each = {
    for key, value in local.effective_repository_variables : key => value
    if value != ""
  }

  triggers = {
    name       = each.key
    value      = each.value
    repository = data.github_repository.this.name
  }

  provisioner "local-exec" {
    environment = {
      GH_TOKEN = var.github_token
    }
    command = "gh variable set ${each.key} --repo Zotec-Product-Development/${data.github_repository.this.name} --body ${jsonencode(each.value)}"
  }
}
