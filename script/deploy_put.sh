#!/bin/bash

# $1:StackName, Required
# $2:S3LambdaDeployBucketName, Required
# $3:S3FailoverBucketName, Required
# $4:MrapAliasName, Required
# $5:AwsProfile, Optional
./deploy.sh 'file://../template/mrapx_put.template' "$@"
