output "s3_bucket_name" {
  description = "Name of the created Terraform Remote State S3 bucket"
  value       = aws_s3_bucket.state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB state locking table"
  value       = aws_dynamodb_table.locks.name
}

output "aws_region" {
  description = "AWS Region of the remote state infrastructure"
  value       = var.region
}
