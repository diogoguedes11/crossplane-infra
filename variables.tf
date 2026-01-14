variable "project_id" {
  description = "The ID of the project in which resources will be created."
  type        = string
}

variable "region" {
  description = "The region in which resources will be created."
  type        = string
  default     = "europe-west1"
}
