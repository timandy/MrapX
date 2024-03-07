#!/bin/bash

# required
# 1. The function name of Lambda@Edge
# 2. The retention days of log group, valid values are: [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653]

FunctionName=$1
RetentionDays=$2
AwsProfile=$3

if [ -z "${FunctionName}" ]; then
  echo 'FunctionName can not be empty'
  exit 1
fi

if [ -z "${RetentionDays}" ]; then
  echo 'RetentionDays can not be empty'
  exit 1
fi

Regions=$(aws ec2 describe-regions --query 'Regions[].{Name:RegionName}' --output text --profile "${AwsProfile}")
for Region in ${Regions}
do
  LogGroupName="/aws/lambda/us-east-1.${FunctionName}"
  echo "  creating: ${LogGroupName} (${Region})"
  aws logs create-log-group --log-group-name "${LogGroupName}" --region "${Region}" --profile "${AwsProfile}"
  aws logs put-retention-policy --log-group-name "${LogGroupName}" --retention-in-days "${RetentionDays}" --region "${Region}" --profile "${AwsProfile}"
done
