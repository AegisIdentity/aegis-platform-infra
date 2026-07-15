output "role_arn" {
  value       = aws_iam_role.this.arn
  description = "Annotate the service account with eks.amazonaws.com/role-arn = this."
}
