#!/bin/bash

# required
# 1. install nvm, nvm install nodever, nvm use nodever.
# 2. install aws cli and configure access key.
# 3. install zip, less utils.
# 4. Manually pre-created ${S3LambdaDeployBucketName} bucket in region us-east-1.
# 5. Manually pre-created multi-region access points.

TemplatePath=$1
StackName=$2
S3LambdaDeployBucketName=$3
S3FailoverBucketName=$4
MrapAliasName=$5
AwsProfile=$6

echo "TemplatePath=${TemplatePath}"
echo "StackName=${StackName}"
echo "S3LambdaDeployBucketName=${S3LambdaDeployBucketName}"
echo "S3FailoverBucketName=${S3FailoverBucketName}"
echo "MrapAliasName=${MrapAliasName}"
echo "AwsProfile=${AwsProfile}"

if [ -z "${TemplatePath}" ]; then
  echo 'TemplatePath can not be empty'
  exit 1
fi

if [ -z "${StackName}" ]; then
  echo 'StackName can not be empty'
  exit 1
fi

if [ -z "${S3LambdaDeployBucketName}" ]; then
  echo 'S3LambdaDeployBucketName can not be empty'
  exit 1
fi

if [ -z "${S3FailoverBucketName}" ]; then
  echo 'S3FailoverBucketName can not be empty'
  exit 1
fi

if [ -z "${MrapAliasName}" ]; then
  echo 'MrapAliasName can not be empty'
  exit 1
fi

echo '====> Change directory to lambda directory'
cd ../lambda || exit
pwd

echo '====> Package lambda function'
npm run clean
npm run build
npm run package

echo '====> Upload lambda function package to s3'
aws s3 cp dist/mrapx-sign.zip "s3://${S3LambdaDeployBucketName}/package/" --profile "${AwsProfile}"

echo '====> Change directory to script directory'
cd ../script || exit
pwd

echo '====> Get the region of failover bucket'
S3FailoverBucketRegion=$(aws s3api get-bucket-location --bucket "${S3FailoverBucketName}" --query 'LocationConstraint' --output text --profile "${AwsProfile}")
echo "S3FailoverBucketRegion=${S3FailoverBucketRegion}"

echo '====> Start to create stack'
StackId=$(aws cloudformation create-stack \
          --stack-name "${StackName}" \
          --template-body "${TemplatePath}" \
          --parameters \
            ParameterKey=S3LambdaDeployBucketName,ParameterValue="${S3LambdaDeployBucketName}" \
            ParameterKey=S3FailoverBucketName,ParameterValue="${S3FailoverBucketName}" \
            ParameterKey=S3FailoverBucketRegion,ParameterValue="${S3FailoverBucketRegion}" \
            ParameterKey=MrapAliasName,ParameterValue="${MrapAliasName}" \
          --capabilities CAPABILITY_NAMED_IAM \
          --query 'StackId' \
          --output text \
          --region us-east-1 \
          --profile "${AwsProfile}")

echo '====> Wait for the stack to be created'
aws cloudformation wait stack-create-complete \
  --stack-name "${StackId}" \
  --region us-east-1 \
  --profile "${AwsProfile}"

echo '====> Start to create log groups'
./create_log_group.sh "${StackName}-SignFunc" 7 "${AwsProfile}"

echo "====> Create stack '${StackName}' completed!"
