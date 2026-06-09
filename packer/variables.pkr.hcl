variable "project_id" {
  type        = string
  description = "The GCP project ID where the image will be built"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{5,29}$", var.project_id))
    error_message = "Variable project_id must be 6-30 characters, start with a lowercase letter, and contain only lowercase letters, digits, and hyphens."
  }
}

variable "region" {
  type        = string
  description = "The GCP region for the build"
  default     = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "base_image_family" {
  type        = string
  description = "The GCP public image family to use as the build base"
  default     = "ubuntu-2404-lts-amd64"
}

variable "image_family" {
  type        = string
  description = "The image family name to assign to the baked output image"
  default     = "hardened-ubuntu"
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

variable "network" {
  type    = string
  default = "default"
}

variable "subnetwork" {
  type    = string
  default = "default"
}
