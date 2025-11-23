# Deploy the Anomaly Detection Pipeline with Terraform

## Make sure to insert your AWS Account ID in main.tf line 120 and line 207.

## This code was written for a sandbox environment where the resources used a provisioned role called LabRole
## Uncomment the code for firehose and lambda role policy for creating a new role. 

1. Install Terraform >= 1.2 and AWS CLI. Configure AWS credentials (aws configure).


2. From project root (anomaly-iac/):
   terraform init
   terraform plan -out=planA
   terraform apply -auto-approve planA

3. Terraform will output:
   - s3_bucket_name
   - kinesis_stream_name
   - firehose_name
   - lambda_function_name

4. Start the producer:
   cd producer
   python3 producer.py

5. Wait a couple of minutes:
   - Lambda will consume Kinesis records and call Firehose
   - Firehose will flush to S3 (buffer size 1MB or interval 60s)

6. Check S3:
   - Use aws cli: aws s3 ls s3://<bucket-name>/enriched-anomalies/ --recursive
   - Or open S3 Console and view the folder

7. To destroy:
   terraform destroy
