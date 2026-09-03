
# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "ctl-dev-vpc"
    Environment = "dev"
  }
}


# ============================================================
# VPC FLOW LOGS
# ============================================================

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/ctl-dev-flow-logs"
  retention_in_days = 30
}


# ------------------------------------------------------------
# IAM trust policy for VPC Flow Logs
# ------------------------------------------------------------

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    sid    = "AllowVpcFlowLogsService"
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "vpc-flow-logs.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}


# ------------------------------------------------------------
# IAM role
# ------------------------------------------------------------

resource "aws_iam_role" "vpc_flow_logs" {
  name = "ctl-dev-vpc-flow-logs-role"

  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json
}


# ------------------------------------------------------------
# Permissions for CloudWatch Logs
# ------------------------------------------------------------

data "aws_iam_policy_document" "vpc_flow_logs" {
  statement {
    sid    = "AllowWriteToCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]

    resources = [
      aws_cloudwatch_log_group.vpc_flow_logs.arn,
      "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    ]
  }
}


# ------------------------------------------------------------
# IAM inline policy
# ------------------------------------------------------------

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "ctl-dev-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = data.aws_iam_policy_document.vpc_flow_logs.json
}


# ------------------------------------------------------------
# Enable VPC Flow Logs
# ------------------------------------------------------------

resource "aws_flow_log" "dev_vpc" {
  vpc_id = aws_vpc.dev_vpc.id

  traffic_type = "ALL"

  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  tags = {
    Name        = "ctl-dev-vpc-flow-logs"
    Environment = "dev"
  }

  depends_on = [
    aws_iam_role_policy.vpc_flow_logs
  ]
}


# ============================================================
# S3 BUCKET
# ============================================================

resource "aws_s3_bucket" "test" {
  bucket = "ctl-dev-bootstrap-test"

  tags = {
    Name        = "ctl-dev-bootstrap-test"
    Environment = "dev"
  }
}


# ============================================================
# S3 PUBLIC ACCESS BLOCK
# ============================================================

resource "aws_s3_bucket_public_access_block" "test" {
  bucket = aws_s3_bucket.test.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ============================================================
# S3 VERSIONING
# ============================================================

resource "aws_s3_bucket_versioning" "test" {
  bucket = aws_s3_bucket.test.id

  versioning_configuration {
    status = "Enabled"
  }
}


# ============================================================
# KMS KEY
# ============================================================

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "s3_kms" {
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "kms:*"
    ]

    resources = [
      "*"
    ]
  }
}


resource "aws_kms_key" "s3" {
  description         = "KMS key for S3 encryption"
  enable_key_rotation = true

  policy = data.aws_iam_policy_document.s3_kms.json

  tags = {
    Name        = "ctl-dev-s3-kms"
    Environment = "dev"
  }
}


# ============================================================
# S3 SERVER-SIDE ENCRYPTION
# ============================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "test" {
  bucket = aws_s3_bucket.test.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }

    bucket_key_enabled = true
  }
}


# ============================================================
# S3 LIFECYCLE
# ============================================================

resource "aws_s3_bucket_lifecycle_configuration" "test" {
  bucket = aws_s3_bucket.test.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    expiration {
      days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

