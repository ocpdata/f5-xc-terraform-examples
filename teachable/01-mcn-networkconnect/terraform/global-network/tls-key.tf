resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Use externally provided public key when SSH_PRIVATE_KEY secret is configured;
# otherwise fall back to the auto-generated key.
locals {
  resolved_ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.key.public_key_openssh
}