variable "region" {
  default = "us-west-2"
}

variable "account_id" {
  default = "269742496681"
}

variable "project" {
  default = "brew-and-bean"
}

variable "s3_orders_bucket" {
  description = "Globally unique bucket name for Path C raw orders"
  default     = "brew-and-bean-orders-269742496681"
}
