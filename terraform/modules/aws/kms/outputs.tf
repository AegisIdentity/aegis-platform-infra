output "key_arns" {
  value       = { for k, v in aws_kms_key.this : k => v.arn }
  description = "Map of key short-name => CMK ARN."
}

output "key_ids" {
  value       = { for k, v in aws_kms_key.this : k => v.key_id }
  description = "Map of key short-name => CMK key id."
}
