variable "region" {
  description = "AWS Region for Terraform Remote State infrastructure"
  type        = string
  default     = "us-east-2"
}

variable "bucket_prefix" {
  description = "Prefix for the remote state S3 bucket"
  type        = string
  default     = "scale-to-zero-tf-state"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for distributed state locking"
  type        = string
  default     = "scale-to-zero-tf-locks"
}
