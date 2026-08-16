# ECR Repository for Docker image
resource "aws_ecr_repository" "this" {
  for_each = toset(local.ecr_repository_names)

  name                 = each.value
  force_delete         = var.force_delete
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  image_tag_mutability_exclusion_filter {
    filter      = "local*"
    filter_type = "WILDCARD"
  }

  # Environment pointer tags are single, mutable tags (one per environment) that
  # get re-pointed as an image is promoted. No wildcard: match the exact tag only.
  image_tag_mutability_exclusion_filter {
    filter      = "development"
    filter_type = "WILDCARD"
  }

  image_tag_mutability_exclusion_filter {
    filter      = "staging"
    filter_type = "WILDCARD"
  }

  image_tag_mutability_exclusion_filter {
    filter      = "uat"
    filter_type = "WILDCARD"
  }

  image_tag_mutability_exclusion_filter {
    filter      = "production"
    filter_type = "WILDCARD"
  }
}

# ECR Lifecycle Policy to manage image retention across environments
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  # Lifecycle rules evaluated by priority (lower number = higher priority).
  #
  # ECR count/protection semantics (important for the ci rule below):
  #   - An image matches a tagPrefixList rule if the prefix matches ANY of the image's tags. A digest
  #     tagged both "ci-<sha>" and "r<version>" is therefore counted by BOTH the r* rule and the ci rule.
  #   - A higher-priority rule that keeps an image protects it: a lower-priority rule may still "see" and
  #     count that image, but can NEVER expire it (AWS ECR lifecycle evaluation rules; see the docs'
  #     "Filtering on multiple rules" Example A). So r-tagged digests are permanently safe from rule 3.
  #   - imageCountMoreThan sorts matches youngest -> oldest and only marks the overflow OLDER than
  #     countNumber. The newest N matches are always kept; protected r* images older than that window are
  #     simply skipped (bonus retention), never subtracted from the count.
  #
  # Tagging model:
  #   - "ci-<sha>"  : the single image built per commit. Every environment deploys this image;
  #     promotion only moves pointer tags. Retained by count.
  #   - "production"/"staging"/"uat"/"development" : single mutable pointer tags marking what is live
  #     in each environment. They share a digest with the deployed ci-<sha> image.
  #   - "r<version>" : immutable durable release tag, applied ONLY after a successful production
  #     deploy. A release image usually shares its digest with the ci-<sha> image it was promoted
  #     from, so it is claimed by a dedicated high-priority keep rule (priority 1) that runs before
  #     the ci expiry rule, ensuring co-tagged ci/r digests are never deleted.
  #   - "local-*"   : local/dev pushes.
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep all release (r*) images indefinitely; matched before ci expiry so co-tagged ci-<sha>/r<version> digests are never deleted",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["r"],
          countType     = "imageCountMoreThan",
          countNumber   = 999999
        },
        action = {
          type               = "transition",
          targetStorageClass = "archive"
        }
      },
      {
        rulePriority = 2,
        description  = "Guard env pointer images (production/staging/uat/development) from ci expiry; action never fires (kept in standard storage for fast pulls). Durable production retention is handled by the r* rule above.",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["production", "staging", "uat", "development"],
          countType     = "imageCountMoreThan",
          countNumber   = 999999
        },
        action = {
          type = "expire"
        }
      },
      # Keeps the newest N ci-matching digests. Because a promoted image keeps its ci-<sha> tag in
      # addition to r<version>, release digests are counted here too, but rule 1 prevents them from ever
      # being expired. In practice releases sit at the OLDER end of the ci set (new ci-<sha> images are
      # pushed on every commit), so the newest N slots are recent ci-only builds; a release only ever
      # occupies a slot when it is among the newest N, and it is kept regardless. Net effect: distinct
      # ci-only images retained may dip slightly below N during bursts of releases, never to zero.
      {
        rulePriority = 3,
        description  = "Keep only last N ci images (default 15); see co-tagging note in header",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["ci"],
          countType     = "imageCountMoreThan",
          countNumber   = var.lower_env_image_retention_count
        },
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4,
        description  = "Keep local images for N days (default 15)",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["local"],
          countType     = "sinceImagePushed",
          countUnit     = "days",
          countNumber   = var.image_local_day_retention_count
        },
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 5,
        description  = "Remove untagged images older than 5 days",
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 5
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}


data "aws_iam_policy_document" "this" {
  statement {
    sid    = "Higher Environments"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::001553724852:root",
        "arn:aws:iam::870288520478:root"
      ]
    }
    # Pull access plus PutImage so each higher environment's own deployment role
    # (s-/p-zeus-deployment) can promote the mutable environment pointer tag onto
    # an existing image in this central repository, without assuming the central
    # d-zeus-deployment role cross-account. DescribeImages lets those higher-env
    # workspaces resolve a tag to its immutable digest (data.aws_ecr_image) so
    # Lambdas can be pinned by @sha256 instead of a mutable tag.
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:PutImage"
    ]
  }

  # AWS Lambda container images require the repository policy to grant the
  # Lambda service principal pull access, even when the function lives in the
  # same account as the repository. Scoped by source account so only functions
  # in the known Data Platform accounts can pull.
  dynamic "statement" {
    for_each = length(var.lambda_pull_account_ids) > 0 ? [1] : []
    content {
      sid    = "LambdaImagePull"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }

      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ]

      condition {
        test     = "StringEquals"
        variable = "aws:sourceAccount"
        values   = var.lambda_pull_account_ids
      }
    }
  }
}

resource "aws_ecr_repository_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy     = data.aws_iam_policy_document.this.json
}

# Outputs
output "ecr_repository_url" {
  description = "ECR repository URL for the Docker image"
  value = {
    for k, v in aws_ecr_repository.this : k => v.repository_url
  }
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value = {
    for k, v in aws_ecr_repository.this : k => v.name
  }
}
