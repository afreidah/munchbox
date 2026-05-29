# -----------------------------------------------------------------------------
# REMOTE-FILES MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "targets" {
  description = "Hosts to ship every bundle to."
  type = list(object({
    name = string # short identifier used as the for_each key
    host = string # ssh-reachable address
  }))
}

variable "ssh_user" {
  description = "SSH user for remote-exec; auth uses the local ssh-agent."
  type        = string
  default     = "root"
}

variable "bundles" {
  description = <<-EOT
    Named groups of files that share a validate/restart lifecycle. Any change
    inside a bundle (file content, destination, mode) recreates one
    null_resource per (target * bundle), re-uploading every file in the
    bundle and re-running its check + restart command.
  EOT
  type = map(object({
    files = map(object({
      content     = string
      destination = string
      mode        = optional(string, "0644")
    }))
    # Optional sanity check; runs after upload, before restart. Non-zero aborts.
    check_command = optional(string, "")
    # Service reload/restart command; runs only if check_command exits 0.
    restart_command = string
  }))
}
