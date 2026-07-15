output "endpoint" {
  value = aws_db_instance.this.address
}

output "master_user_secret_arn" {
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
  description = "Secrets Manager secret holding the RDS-managed master credential."
}

output "security_group_id" {
  value = aws_security_group.this.id
}
