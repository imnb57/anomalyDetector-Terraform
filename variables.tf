variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resources"
  type        = string
  default     = "anomaly-workshop"
}

variable "s3_bucket_suffix" {
  description = "Optional suffix for S3 bucket (unique). If empty, terraform generates one."
  type        = string
  default     = ""
}

variable "kinesis_shards" {
  description = "Number of shards for Kinesis stream"
  type        = number
  default     = 1
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "lambda_handler" {
  description = "Lambda handler"
  type        = string
  default     = "anomaly_lambda.lambda_handler"
}

variable "firehose_buffer_size_mb" {
  description = "Firehose buffer size in MB"
  type        = number
  default     = 1
}

variable "firehose_buffer_interval_seconds" {
  description = "Firehose buffer interval (seconds)"
  type        = number
  default     = 60
}
