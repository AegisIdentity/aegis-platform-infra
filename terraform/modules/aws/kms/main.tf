resource "aws_kms_key" "this" {
  for_each                = var.keys
  description             = each.value
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
}

resource "aws_kms_alias" "this" {
  for_each      = var.keys
  name          = "alias/${var.name}-${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
