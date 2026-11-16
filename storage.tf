# ============================================================
# CATEGORY 3 - STORAGE
# S3 (static site), DynamoDB (users table + seed item),
# SQS (dead-letter queue for failed alert deliveries).
# ============================================================

resource "aws_s3_bucket" "static" {
  bucket        = var.static_bucket_name
  force_destroy = true
  tags          = { Name = "${var.project}-static" }
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.static.id
  key          = "index.html"
  content      = "<h1>Welcome to the Floci Nginx Server</h1>"
  content_type = "text/html"
}

resource "aws_dynamodb_table" "app_users" {
  name           = var.users_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "UserId"

  attribute {
    name = "UserId"
    type = "S"
  }

  tags = { Name = "${var.project}-users" }
}

resource "aws_dynamodb_table_item" "usr_101" {
  table_name = aws_dynamodb_table.app_users.name
  hash_key   = aws_dynamodb_table.app_users.hash_key

  item = jsonencode({
    UserId = { S = "usr-101" }
    Name   = { S = "DevOps Admin" }
    Role   = { S = "Site Reliability Engineer" }
  })
}

# Added beyond the guides: a dead-letter queue catches alert messages
# that could not be delivered, so you can practise checking for them.
resource "aws_sqs_queue" "alerts_dlq" {
  name                      = "WebAppAlerts-DLQ"
  message_retention_seconds = 1209600
  tags                      = { Name = "${var.project}-alerts-dlq" }
}
