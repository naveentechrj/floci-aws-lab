output "vpc_id" {
  value = aws_vpc.lab.id
}

output "alb_dns_name" {
  description = "Test with: curl http://<this value>/ (through the ALB)"
  value       = aws_lb.app.dns_name
}

output "web_instance_id" {
  value = aws_instance.web.id
}

output "web_private_ip" {
  description = "SSH target from the Vagrant VM: ssh -i ~/.ssh/floci-lab root@<this IP>"
  value       = aws_instance.web.private_ip
}

output "static_bucket" {
  value = aws_s3_bucket.static.bucket
}

output "users_table" {
  value = aws_dynamodb_table.app_users.name
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "operator_access_key_id" {
  value = aws_iam_access_key.operator.id
}

output "operator_secret_access_key" {
  value     = aws_iam_access_key.operator.secret
  sensitive = true
}
