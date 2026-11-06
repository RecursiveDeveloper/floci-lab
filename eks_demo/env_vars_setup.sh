#!/bin/bash

export IAM_USER="eks-admin"
export CLUSTER_NAME="dev-cluster"
export CLUSTER_ARN_ROLE="arn:aws:iam::000000000000:role/eks-role"
export SUBNET_ID="subnet-default-us-east-1-a"

export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test