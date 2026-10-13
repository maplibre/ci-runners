variable "ssh_public_key_file" {
  description = "Path to the administrator SSH public key (private key stays local)."
  type        = string
}
variable "ssh_allowed_cidr" {
  description = "Administrator IPv4 CIDR allowed to connect over SSH."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.ssh_allowed_cidr)) && var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "Provide a restricted IPv4 CIDR, not 0.0.0.0/0."
  }
}
