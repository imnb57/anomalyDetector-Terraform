output "s3_bucket_name" {
  description = "S3 bucket name for enriched anomalies"
  value       = aws_s3_bucket.data_lake.bucket
}

output "kinesis_stream_name" {
  description = "Kinesis stream name"
  value       = aws_kinesis_stream.player_events.name
}

output "firehose_name" {
  description = "Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.to_s3.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.anomaly_detector.function_name
}
