#
# Lambda function detect labels in image using Amazon Rekognition
#

import boto3
import os

MIN_CONFIDENCE = 60

def handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
  
    process_image(bucket, key)

def process_image(bucket, key):
    print(f"Processing image in S3 - Bucket: {bucket}, Key: {key}")

    rekognition_client = boto3.client("rekognition")

    response = rekognition_client.detect_labels(
        Image={
            "S3Object": {
                "Bucket": bucket,
                "Name": key
            }
        },
        MaxLabels=10,
        MinConfidence=MIN_CONFIDENCE
    )

    labels = [label["Name"] for label in response.get("Labels", [])]
    print(f"Labels detected: {labels}")

    dynamodb = boto3.resource("dynamodb")
    imageLabelsTable = os.environ.get("TABLE")
    table = dynamodb.Table(imageLabelsTable)

    table.put_item(
        Item={"Image": key}
    )

    for index, label in enumerate(labels, start=1):
        attribute_name = f"object{index}"
        table.update_item(
            Key={"Image": key},
            UpdateExpression=f"SET {attribute_name} = :value",
            ExpressionAttributeValues={":value": label}
        )
        print(f"Updated {key} with {attribute_name}: {label}")
