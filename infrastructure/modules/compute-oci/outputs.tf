# -----------------------------------------------------------------------------
# COMPUTE MODULE (OCI) - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "instance_id" {
  description = "OCID of the instance"
  value       = oci_core_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = oci_core_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = oci_core_instance.this.private_ip
}

output "display_name" {
  description = "Display name of the instance"
  value       = oci_core_instance.this.display_name
}

output "shape" {
  description = "Shape of the instance"
  value       = oci_core_instance.this.shape
}

output "state" {
  description = "Current state of the instance"
  value       = oci_core_instance.this.state
}

output "availability_domain" {
  description = "Availability domain of the instance"
  value       = oci_core_instance.this.availability_domain
}

output "image_id" {
  description = "Image OCID used"
  value       = var.image_id != null ? var.image_id : data.oci_core_images.ubuntu.images[0].id
}

output "ssh_connection_string" {
  description = "SSH connection command"
  value       = "ssh ubuntu@${oci_core_instance.this.public_ip}"
}
