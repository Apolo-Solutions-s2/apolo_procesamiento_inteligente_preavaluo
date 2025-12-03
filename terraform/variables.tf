variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The region where resources will be deployed."
  type        = string
  default     = "us-south1"
}

variable "service_name" {
  description = "The name of the Cloud Run service."
  type        = string
}

variable "container_image" {
  description = "The container image to deploy."
  type        = string
}

variable "environment" {
  description = "The environment (dev, qa, prod)."
  type        = string
}

variable "invoker_identity" {
  description = "The identity allowed to invoke the service."
  type        = string
}