variable "name" {
  type        = string
  description = "Name prefix for key aliases (aegis-<environment>)."
}

variable "keys" {
  type        = map(string)
  description = "Map of key short-name => description. One CMK with rotation is created per entry."
}

variable "deletion_window_in_days" {
  type        = number
  default     = 30
  description = "Waiting period before a scheduled key deletion completes."
}
