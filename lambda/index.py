# Lambda function to detect labels in an image using Amazon Rekognition

import boto3
import os
import json
from decimal import Decimal

MIN_CONFIDENCE = 60

def handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        process_image(bucket, key)
  
def process_image(bucket, key):
    print(f"Processing image in S3 - Bucket: {bucket}, Key: {key}")

    rekognition_client = boto3.client("rekognition")

    labels_response = rekognition_client.detect_labels(
        Image={"S3Object": {"Bucket": bucket,"Name": key}},
        MaxLabels=10,
        MinConfidence=MIN_CONFIDENCE
    )

    faces_response = rekognition_client.detect_faces(
        Image={"S3Object": {"Bucket": bucket,"Name": key}},
        Attributes=["ALL"]
    )

    text_response = rekognition_client.detect_text(
        Image={"S3Object": {"Bucket": bucket,"Name": key}},
    )

    celebrities_response = rekognition_client.recognize_celebrities(
        Image={"S3Object": {"Bucket": bucket,"Name": key}},
    )

    dynamodb = boto3.resource("dynamodb")
    imageDataTable = os.environ.get("TABLE")
    table = dynamodb.Table(imageDataTable)

    item = {
        "Image": key,
        "Labels": labels_response.get("Labels", []),
        "Faces": faces_response.get("FaceDetails", []),
        "Texts": text_response.get("TextDetections", []),
        "Celebrities": celebrities_response.get("CelebrityFaces", [])
    }

    table.put_item(
        Item = json.loads(json.dumps(item), parse_float=Decimal)
    )

    print("Image processing complete.")
