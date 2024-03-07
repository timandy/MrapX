#!/bin/bash

# required
# 1. The function name of Lambda@Edge

FunctionName=$1
AwsProfile=$2

if [ -z "${FunctionName}" ]; then
  echo 'FunctionName can not be empty'
  exit 1
fi

Regions=$(aws ec2 describe-regions --query 'Regions[].{Name:RegionName}' --output text --profile "${AwsProfile}")
for Region in ${Regions}
do
  LogGroupName="/aws/lambda/us-east-1.${FunctionName}"
  echo "  deleting: ${LogGroupName} (${Region})"
  aws logs delete-log-group --log-group-name "${LogGroupName}" --region "${Region}" --profile "${AwsProfile}"
done
