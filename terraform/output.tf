output "s3_bucket_name" {
  value = aws_s3_bucket.this.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.this.name
}

output "lambda_function_name" {
  value = aws_lambda_function.this.function_name
}

output "lambda_role_name" {
  value = aws_iam_role.this.name
}

output "lambda_policy_name" {
  value = aws_iam_policy.this.name
}
