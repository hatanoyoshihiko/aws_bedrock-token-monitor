#!/bin/bash
set -euo pipefail

STACK_NAME="${STACK_NAME:-bedrock-token-monitor}"
REGION="${AWS_REGION:-ap-northeast-1}"
SNS_TOPIC_ARN="${SNS_TOPIC_ARN:?Set SNS_TOPIC_ARN}"

aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --parameter-overrides \
    SnsTopicArn="$SNS_TOPIC_ARN" \
  --no-fail-on-empty-changeset

echo "Deployed." 
