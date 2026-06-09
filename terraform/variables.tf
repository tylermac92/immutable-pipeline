# ==============================================================================
# Required Variables (No Defaults)
# ==============================================================================

variable "project_id" {
  type        = string
  description = "The GCP project ID where resources will be provisioned."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "The project_id must be 6-30 characters, start with a lowercase letter, contain only lowercase letters, numbers, or hyphens, and cannot end with a hyphen."
  }
}

variable "image_name" {
  type        = string
  description = "The explicit Compute Engine image name or image family artifact ID from the Packer manifest."
}

variable "sa_instance_runtime_email" {
  type = string
  description = "The minimal service account email to attach to MIG instances."
}

# ==============================================================================
# Variables with Defaults
# ==============================================================================

variable "region" {
  type        = string
  description = "The GCP region for regional resources."
  default     = "us-central1"
}

variable "zone_a" {
  type        = string
  description = "The primary availability zone within the chosen region."
  default     = "us-central1-a"
}

variable "zone_b" {
  type        = string
  description = "The secondary availability zone within the chosen region."
  default     = "us-central1-b"
}

variable "network_name" {
  type        = string
  description = "The name of the custom VPC network."
  default     = "immutable-pipeline-vpc"
}

variable "subnet_cidr_a" {
  type        = string
  description = "The IPv4 CIDR block for subnet A."
  default     = "10.0.1.0/24"
}

variable "subnet_cidr_b" {
  type        = string
  description = "The IPv4 CIDR block for subnet B."
  default     = "10.0.2.0/24"
}

variable "machine_type" {
  type        = string
  description = "The Compute Engine machine type for the managed instance group instances."
  default     = "e2-medium"
}

variable "min_replicas" {
  type        = number
  description = "The minimum number of running instances in the autoscaler."
  default     = 2

  validation {
    condition     = var.min_replicas >= 2
    error_message = "The min_replicas value must be greater than or equal to 2."
  }
}

variable "max_replicas" {
  type        = number
  description = "The maximum number of running instances in the autoscaler. Must be greater than min_replicas."
  default     = 6
}

variable "named_port" {
  type        = number
  description = "The port number configured for the instance group named port."
  default     = 80
}

# ==============================================================================
# Cross-Variable Validation Workaround
# ==============================================================================

locals {
  # Terraform does not allow cross-variable references inside variable validation blocks.
  # This block will force a plan-time evaluation failure if max_replicas <= min_replicas.
  validate_replicas = var.max_replicas > var.min_replicas ? null : file("ERROR: max_replicas must be strictly greater than min_replicas")
}
