variable "repositories" {
  type        = list(string)
  description = "Service names; each gets an aegis/<name> repository."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK for image encryption (hardened); null uses AES256."
}

variable "keep_last_images" {
  type    = number
  default = 20
}
