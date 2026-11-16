# ============================================================
# CATEGORY 4 - SECURITY (IAM, key pairs, security groups)
# ============================================================

# ---------- Security groups (chained: ALB -> web) ----------

resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Public HTTP into the load balancer"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-alb-sg" }
}

resource "aws_security_group" "web" {
  name        = "${var.project}-web-sg"
  description = "Web instance: HTTP only from the ALB, SSH only from admin ranges"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description     = "HTTP from the ALB security group only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH from admin ranges"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-web-sg" }
}

# ---------- SSH key pair ----------

resource "aws_key_pair" "lab" {
  key_name   = "${var.project}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ---------- IAM role for the web instance (least privilege) ----------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${var.project}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "web_least_privilege" {
  statement {
    sid       = "ReadUsersTableOnly"
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.app_users.arn]
  }

  statement {
    sid       = "ReadStaticAssetsOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static.arn}/*"]
  }
}

resource "aws_iam_policy" "web" {
  name   = "${var.project}-web-least-privilege"
  policy = data.aws_iam_policy_document.web_least_privilege.json
}

resource "aws_iam_role_policy_attachment" "web" {
  role       = aws_iam_role.web.name
  policy_arn = aws_iam_policy.web.arn
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project}-web-profile"
  role = aws_iam_role.web.name
}

# ---------- Human operator: IAM group, user, read-only policy ----------

resource "aws_iam_group" "operators" {
  name = "${var.project}-operators"
}

data "aws_iam_policy_document" "operators_readonly" {
  statement {
    sid = "ReadOnlyInfra"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "s3:ListBucket",
      "s3:GetObject",
      "dynamodb:DescribeTable",
      "dynamodb:Scan",
      "cloudwatch:Describe*",
      "cloudwatch:GetMetricStatistics",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_group_policy" "operators" {
  name   = "${var.project}-operators-readonly"
  group  = aws_iam_group.operators.name
  policy = data.aws_iam_policy_document.operators_readonly.json
}

resource "aws_iam_user" "operator" {
  name = "${var.project}-operator-1"
}

resource "aws_iam_user_group_membership" "operator" {
  user   = aws_iam_user.operator.name
  groups = [aws_iam_group.operators.name]
}

# WARNING: this stores the secret key in terraform.tfstate. Lab only, never commit state.
resource "aws_iam_access_key" "operator" {
  user = aws_iam_user.operator.name
}
