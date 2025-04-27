# Rekognition image pipeline

During Stephane Maarek's AWS Certified Data Engineer - Associate course on Udemy, there was a hands on lesson for AWS CDK that I opted to try in Terraform. This repo is the result.

Certainly not a module nor really intended to be reused by others.

The gist of it is that you drop an image in an S3 bucket, a Lambda is triggered that uses Rekognition to get image labels, and those are persisted to DynamoDB.