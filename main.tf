locals {
  rand_suffix = var.s3_bucket_suffix != "" ? var.s3_bucket_suffix : random_id.bucket_suffix[0].hex
  bucket_name = "${var.name_prefix}-${replace(lower(local.rand_suffix), "/","")}"
  kinesis_stream_name = "player-events-stream"
  firehose_name       = "delivery-to-s3"
  lambda_name         = "anomaly-detector"
  s3_prefix           = "enriched-anomalies/"
}

# random suffix only used if s3_bucket_suffix not provided
resource "random_id" "bucket_suffix" {
  count = var.s3_bucket_suffix == "" ? 1 : 0
  byte_length = 4
}

# S3 bucket for data lake
resource "aws_s3_bucket" "data_lake" {
  bucket = local.bucket_name
  acl    = "private"
  force_destroy = true

  tags = {
    Name = local.bucket_name
  }

  versioning {
    enabled = false
  }

  # keep public access blocked (default)
}

# optionally create the prefix folder by uploading an empty object with trailing slash
resource "aws_s3_object" "prefix_marker" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "${local.s3_prefix}.keep"
  content = "This object keeps the prefix folder for enriched anomalies."
  acl = "private"
}

# Kinesis Data Stream
resource "aws_kinesis_stream" "player_events" {
  name             = local.kinesis_stream_name
  shard_count      = var.kinesis_shards
  retention_period = 24
}

# # Firehose IAM role (assume role for Firehose service)
# resource "aws_iam_role" "firehose_role" {
#   name = "${var.name_prefix}-firehose-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "firehose.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

#  Firehose policy to write to S3 (and basic logging)
# resource "aws_iam_role_policy" "firehose_policy" {
#   name = "${var.name_prefix}-firehose-policy"
#   role = aws_iam_role.firehose_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid = "WriteToS3"
#         Effect = "Allow"
#         Action = [
#           "s3:PutObject",
#           "s3:PutObjectAcl",
#           "s3:ListBucket",
#           "s3:GetBucketLocation"
#         ]
#         Resource = [
#           aws_s3_bucket.data_lake.arn,
#           "${aws_s3_bucket.data_lake.arn}/*"
#         ]
#       },
#       {
#         Sid = "KMSIfNeeded"
#         Effect = "Allow"
#         Action = [
#           "kms:Encrypt",
#           "kms:Decrypt",
#           "kms:GenerateDataKey*",
#           "kms:DescribeKey"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid = "CloudWatchLogs"
#         Effect = "Allow"
#         Action = [
#           "logs:PutLogEvents",
#           "logs:CreateLogStream",
#           "logs:DescribeLogGroups",
#           "logs:DescribeLogStreams"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# Firehose Delivery Stream (Direct PUT -> S3)
resource "aws_kinesis_firehose_delivery_stream" "to_s3" {
  name        = local.firehose_name
  destination = "extended_s3"       # CHANGE 1: Switch from "s3" to "extended_s3"

  extended_s3_configuration {       # CHANGE 2: Rename block to "extended_s3_configuration"
    role_arn = "arn:aws:iam::<AccountID>:role/LabRole"
    bucket_arn          = aws_s3_bucket.data_lake.arn
    prefix              = local.s3_prefix
    error_output_prefix = "errors/!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/"

    
    # These arguments remain the same but now live in the extended block
    buffering_size         = var.firehose_buffer_size_mb
    buffering_interval     = var.firehose_buffer_interval_seconds
    compression_format  = "UNCOMPRESSED"
  }

  
}
# # Lambda execution role (Lambda will read Kinesis and call Firehose)
# resource "aws_iam_role" "lambda_role" {
#   name = "${var.name_prefix}-lambda-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# Lambda role policy
# resource "aws_iam_role_policy" "lambda_policy" {
#   name = "${var.name_prefix}-lambda-policy"
#   role = aws_iam_role.lambda_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid = "KinesisRead"
#         Effect = "Allow"
#         Action = [
#           "kinesis:GetRecords",
#           "kinesis:GetShardIterator",
#           "kinesis:DescribeStream",
#           "kinesis:ListShards"
#         ]
#         Resource = aws_kinesis_stream.player_events.arn
#       },
#       {
#         Sid = "FirehosePut"
#         Effect = "Allow"
#         Action = [
#           "firehose:PutRecord",
#           "firehose:PutRecordBatch"
#         ]
#         Resource = aws_kinesis_firehose_delivery_stream.to_s3.arn
#       },
#       {
#         Sid = "CloudWatchLogs"
#         Effect = "Allow"
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# Package Lambda: uses the local file lambda/anomaly_lambda.py
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_package/anomaly_lambda.zip"
  source {
    content  = file("${path.module}/lambda/anomaly_lambda.py")
    filename = "anomaly_lambda.py"
  }
}

resource "aws_lambda_function" "anomaly_detector" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.lambda_name
  role = "arn:aws:iam::<AccountID>:role/LabRole"
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout = 60

  environment {
    variables = {
      FIREHOSE_NAME = local.firehose_name
      
    }
  }

  
}

# Event source mapping: Kinesis -> Lambda
resource "aws_lambda_event_source_mapping" "kinesis_to_lambda" {
  event_source_arn = aws_kinesis_stream.player_events.arn
  function_name    = aws_lambda_function.anomaly_detector.arn
  starting_position = "LATEST"
  batch_size       = 10
  enabled          = true
}

# allow Lambda to be invoked by event source mapping - Terraform creates necessary permissions

