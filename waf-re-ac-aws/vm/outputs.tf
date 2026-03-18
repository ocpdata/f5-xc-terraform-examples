output "vm_ip" {
  value       = aws_instance.dvwa.private_ip
  description = "Private IP of the DVWA EC2 instance"
  sensitive   = true
}

output "dvwa_port" {
  value       = 8080
  description = "Port where DVWA is listening"
}
