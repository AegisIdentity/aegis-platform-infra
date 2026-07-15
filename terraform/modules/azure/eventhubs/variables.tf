variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "capacity" {
  type = number
}

variable "auto_inflate" {
  type    = bool
  default = false
}

variable "max_throughput_units" {
  type    = number
  default = 10
}

variable "public_network_access" {
  type = bool
}

variable "private_endpoint_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_id" {
  type    = string
  default = null
}
