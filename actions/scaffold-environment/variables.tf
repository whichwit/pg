variable "github_token" {
  description = "GitHub token with repo and environment access."
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "The name of the GitHub repository"
  type        = string
}

variable "environment_secrets" {
  description = "Map of environment name to secret name/value pairs."
  type        = map(map(string))
  default     = {}
}

variable "environment_variables" {
  description = "Map of environment name to variable name/value pairs."
  type        = map(map(string))
  default     = {}
}
variable "repository_variables" {
  description = "Map of repository variable name to value pairs. Merged over defaults (HAS_UAT=false)."
  type        = map(string)
  default     = {}
}