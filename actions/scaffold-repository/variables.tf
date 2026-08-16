variable "github_token" {
  description = "GitHub token with repo and environment access."
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "The name of the GitHub repository"
  type        = string
}