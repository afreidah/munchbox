# -----------------------------------------------------------------------------
# COMPUTE SPOT MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "spot_request_id" {
  description = "ID of the spot instance request"
  value       = aws_spot_instance_request.this.id
}

output "spot_instance_id" {
  description = "ID of the spot instance (once fulfilled)"
  value       = aws_spot_instance_request.this.spot_instance_id
}

output "spot_request_state" {
  description = "State of the spot request"
  value       = aws_spot_instance_request.this.spot_request_state
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = var.assign_elastic_ip ? aws_eip.this[0].public_ip : aws_spot_instance_request.this.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_spot_instance_request.this.private_ip
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_spot_instance_request.this.public_dns
}

output "private_dns" {
  description = "Private DNS name of the instance"
  value       = aws_spot_instance_request.this.private_dns
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = var.ami_id != null ? var.ami_id : local.ami_id
}

output "key_name" {
  description = "Name of the SSH key pair"
  value       = var.ssh_public_key != null ? aws_key_pair.this[0].key_name : var.key_name
}

output "elastic_ip" {
  description = "Elastic IP address (if assigned)"
  value       = var.assign_elastic_ip ? aws_eip.this[0].public_ip : null
}

output "ssh_connection_string" {
  description = "SSH connection command"
  value       = "ssh ubuntu@${var.assign_elastic_ip ? aws_eip.this[0].public_ip : aws_spot_instance_request.this.public_ip}"
}
