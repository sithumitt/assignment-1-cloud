# S3 Bucket
resource "aws_s3_bucket" "app_bucket" {
  bucket_prefix = "my-node-app-storage-" 
  force_destroy = true 
}

# ECS S3 Policy
resource "aws_iam_role_policy" "ecs_s3_policy" {
  name = "ecs_s3_access_policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_bucket.arn,
          "${aws_s3_bucket.app_bucket.arn}/*"
        ]
      }
    ]
  })
}