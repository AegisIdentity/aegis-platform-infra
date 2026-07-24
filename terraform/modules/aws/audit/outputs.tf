output "audit_bucket" {
  value = aws_s3_bucket.audit.id
}

output "cloudtrail_arn" {
  value = aws_cloudtrail.this.arn
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.this.id
}

output "config_recorder_name" {
  value = aws_config_configuration_recorder.this.name
}
