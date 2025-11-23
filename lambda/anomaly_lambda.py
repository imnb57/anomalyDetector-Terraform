# lambda/anomaly_lambda.py
import json
import boto3
import base64
import os
from datetime import datetime
from collections import defaultdict
import statistics

FIREHOSE_NAME = os.environ.get("FIREHOSE_NAME", "delivery-to-s3")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

firehose = boto3.client("firehose", region_name=AWS_REGION)

player_scores = defaultdict(list)
MAX_HISTORY = 20

def print_header(records_received):
    print("\n" + "=" * 70)
    print(" Real-Time Anomaly Detector — Lambda Invocation".center(70))
    print("=" * 70)
    print(f" Records Received : {records_received}")
    print("-" * 70)

def print_record_processing(player_id, score, timestamp):
    print(
        f" ▶ Processing | Player: {player_id.ljust(10)} | "
        f"Score: {str(score).rjust(8)} | Time: {timestamp}"
    )

def print_anomaly(player_id, score, anomaly_score):
    print(
        f" 🔴 ANOMALY  | Player: {player_id.ljust(10)} | "
        f"Score: {str(score).rjust(8)} | Z-Score: {str(anomaly_score).rjust(5)}"
    )

def print_error(seq, error):
    print(
        f" ⚠️  ERROR    | Sequence: {seq} | Details: {error}"
    )

def print_summary(processed, failed):
    print("-" * 70)
    print(f" Processed : {processed}")
    print(f" Failed    : {failed}")
    print("=" * 70 + "\n")

def calculate_anomaly_score(player_id, score):
    player_scores[player_id].append(score)

    if len(player_scores[player_id]) > MAX_HISTORY:
        player_scores[player_id] = player_scores[player_id][-MAX_HISTORY:]

    if len(player_scores[player_id]) < 3:
        return 0.1

    scores = player_scores[player_id]
    mean = statistics.mean(scores)
    stdev = statistics.stdev(scores)

    if stdev == 0:
        return 0.1

    z_score = abs(score - mean) / stdev
    return round(z_score, 2)

def lambda_handler(event, context):
    records_received = len(event.get('Records', []))
    print_header(records_received)

    processed_count = 0
    error_count = 0

    for record in event.get('Records', []):
        try:
            # Kinesis data is base64 encoded in record['kinesis']['data']
            payload = base64.b64decode(record['kinesis']['data'])
            data = json.loads(payload)

            player_id = data['player_id']
            score = data['score']
            event_timestamp = data.get('event_timestamp', datetime.utcnow().isoformat())

            print_record_processing(player_id, score, event_timestamp)

            anomaly_score = calculate_anomaly_score(player_id, score)

            enriched = {
                'player_id': player_id,
                'score': score,
                'event_timestamp': event_timestamp,
                'anomaly_score': anomaly_score,
                'is_anomaly': anomaly_score > 2.0
            }

            # deliver to firehose
            firehose.put_record(
                DeliveryStreamName=FIREHOSE_NAME,
                Record={'Data': json.dumps(enriched) + "\n"}
            )

            if enriched['is_anomaly']:
                print_anomaly(player_id, score, anomaly_score)

            processed_count += 1

        except Exception as e:
            seq = record.get('kinesis', {}).get('sequenceNumber', 'N/A')
            print_error(seq, e)
            error_count += 1

    print_summary(processed_count, error_count)

    return {
        'statusCode': 200,
        'body': json.dumps(
            f"Processed {processed_count} of {records_received} records."
        )
    }
