#!/bin/bash

StackName=$1
AwsProfile=$2

echo "StackName=${StackName}"
echo "AwsProfile=${AwsProfile}"

if [ -z "${StackName}" ]; then
  echo 'StackName can not be empty'
  exit 1
fi

echo '====> Start to delete log groups'
./delete_log_group.sh "${StackName}-SignFunc"

echo '====> Start to delete stack'
aws cloudformation delete-stack \
  --stack-name "${StackName}" \
  --region us-east-1 \
  --profile "${AwsProfile}"

echo '====> Wait for the stack to be deleted'
aws cloudformation wait stack-delete-complete \
  --stack-name "${StackName}" \
  --region us-east-1 \
  --profile "${AwsProfile}"

echo "====> Clean stack '${StackName}' completed!"
