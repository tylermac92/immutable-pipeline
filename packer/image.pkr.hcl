locals {
  timestamp  = formatdate("YYYYMMDDhhmmss", timestamp())
  image_name = "${var.image_family}-${local.timestamp}"
}

source "googlecompute" "hardened_ubuntu" {
  project_id = var.project_id
  zone       = var.zone

  # Base image to build from
  source_image_family = var.base_image_family
  image_name          = local.image_name
  image_family        = var.image_family

  image_description = "Hardened Ubuntu image built by Packer on ${local.timestamp}"

  image_labels = {
    built-by    = "packer"
    base-family = var.base_image_family
    environment = "production"
  }

  # Build VM configuration
  machine_type = var.machine_type
  disk_size    = 20
  disk_type    = "pd-ssd"

  # Network configuration — private build VM
  network    = var.network
  subnetwork = var.subnetwork

  # No external IP — use IAP for SSH
  omit_external_ip = true
  use_internal_ip  = true
  use_iap          = true

  # SSH configuration
  ssh_username            = var.ssh_username
  temporary_key_pair_type = "ed25519"

  tags = ["packer-build"]

  # Explicit SA impersonation — overrides ambient ADC if set
  # In CI, this is set via GOOGLE_IMPERSONATE_SERVICE_ACCOUNT env var instead
  # impersonate_service_account = "sa-packer-builder@${var.project_id}.iam.gserviceaccount.com"
}

build {
  name    = "hardened-ubuntu"
  sources = ["source.googlecompute.hardened_ubuntu"]

  provisioner "shell" {
    inline = [
      "echo 'Pre-flight: Build VM is alive'",
      "uname -a",
      "cat /etc/os-release | grep PRETTY_NAME"
    ]
  }

  provisioner "ansible" {
    playbook_file = "./ansible/playbook.yml"
    user          = var.ssh_username
    galaxy_file   = "./ansible/requirements.yml"

    extra_arguments = [
      "--become",
      "-e", "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
    ]

    ansible_env_vars = [
      "ANSIBLE_ROLES_PATH=./ansible/roles",
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_NOCOLOR=False"
    ]
  }

  provisioner "file" {
    source = "./validation/goss.yaml"
    destination = "/tmp/goss.yaml"
  }

  provisioner "shell" {
    script = "./validation/goss-install.sh"
    execute_command = "sudo bash '{{ .Path }}'"
  }

  post-processor "manifest" {
    output     = "packer/manifest.json"
    strip_path = true
  }
}
