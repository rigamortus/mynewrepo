#!/usr/bin/env python3

import json
import boto3
import qrcode
import io
import base64
from urllib.parse import urlparse

# Initialize a session using Amazon S3
s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Parse the URL from the event
    body = json.loads(event['body'])
    url = body['url']
    
    # Parse the URL using urlparse
    parsed_url = urlparse(url)
    netloc = parsed_url.netloc
    path = parsed_url.path

    # If the URL does not have a scheme (http/https), netloc will be empty
    if not netloc:
        netloc = parsed_url.path.split('/')[0]
        path = '/' + '/'.join(parsed_url.path.split('/')[1:])
    
    # Generate a unique filename
    filename = netloc.replace("/", "_") + path.replace("/", "_") + '.png'

    # Generate QR code
    img = qrcode.make(url)
    img_bytes = io.BytesIO()
    img.save(img_bytes)
    img_bytes = img_bytes.getvalue()
    
    # Upload the QR code to the S3 bucket
    s3.put_object(Bucket='rigas32', Key=filename, Body=img_bytes, ContentType='image/png')
    
    # Generate the URL of the uploaded QR code
    location = s3.get_bucket_location(Bucket='rigas32')['LocationConstraint']
    region = '' if location is None else f'{location}'
    qr_code_url = f"https://{'rigas32'}.s3.amazonaws.com/{filename}"
    
    # Construct response with CORS headers
    response = {
        'statusCode': 200,
        'headers': {
            "Access-Control-Allow-Headers" : "Content-Type",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
        },
        'body': json.dumps(qr_code_url)
    }
    
    return response
