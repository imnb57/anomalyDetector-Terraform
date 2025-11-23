# producer/producer.py
import boto3
import json
import time
import random
from datetime import datetime

STREAM_NAME = "player-events-stream"
REGION = "us-east-1"

kinesis = boto3.client("kinesis", region_name=REGION)

def generate_player_event(event_number):
    player_id = f"player_{random.randint(1, 20)}"
    if random.random() < 0.95:
        score = random.uniform(10, 100)
    else:
        score = random.uniform(500, 9999)

    return {
        "player_id": player_id,
        "score": round(score, 2),
        "event_timestamp": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
    }

def send_to_kinesis(event):
    try:
        kinesis.put_record(
            StreamName=STREAM_NAME,
            Data=json.dumps(event),
            PartitionKey=event["player_id"],
        )
        return True
    except Exception as e:
        print(f"[ERROR] {e}")
        return False

def print_header():
    print("\n" + "=" * 65)
    print(f"   Real-Time Game Event Producer".center(65))
    print("=" * 65)
    print(f"   Stream: {STREAM_NAME}   |   Region: {REGION}")
    print("-" * 65 + "\n")

def print_event(event, is_anomaly=False, anomaly_id=None):
    player = event["player_id"].ljust(10)
    score = str(event["score"]).rjust(8)
    ts = event["event_timestamp"]

    if is_anomaly:
        print(
            f" 🔴 ANOMALY {str(anomaly_id).rjust(3)} | "
            f"Player: {player} | Score: {score} | Time: {ts}"
        )
    else:
        print(
            f" 🟢 Event     | Player: {player} | Score: {score} | Time: {ts}"
        )

def print_progress(total, anomalies):
    print("\n" + "-" * 65)
    print(
        f" Sent: {str(total).rjust(6)} events   |   "
        f"Anomalies: {str(anomalies).rjust(4)}"
    )
    print("-" * 65 + "\n")

print_header()

event_count = 0
anomaly_count = 0

try:
    while True:
        event = generate_player_event(event_count)

        if send_to_kinesis(event):
            event_count += 1
            is_anomaly = event["score"] > 200

            if is_anomaly:
                anomaly_count += 1
                print_event(event, True, anomaly_count)
            else:
                print_event(event, False)

            if event_count % 10 == 0:
                print_progress(event_count, anomaly_count)

        time.sleep(0.1)

except KeyboardInterrupt:
    print("\n" + "=" * 65)
    print("   Producer Stopped")
    print("=" * 65)
    print(f" Total Events Sent: {event_count}")
    print(f" Total Anomalies  : {anomaly_count}")
    print("=" * 65 + "\n")
