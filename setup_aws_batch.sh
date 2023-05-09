#!/bin/bash

export AWS_ENDPOINT_URL=http://localhost:5555
export INSTANCE_ROLE_NAME=my-test-role
export JOB_NAME=test-job


echo "creating instance role"

aws --endpoint-url $AWS_ENDPOINT_URL iam create-role \
    --role-name $INSTANCE_ROLE_NAME \
    --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["batch.amazonaws.com", "ec2.amazonaws.com""]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

echo "creating instance profile"

aws --endpoint-url $AWS_ENDPOINT_URL iam create-instance-profile --instance-profile-name $INSTANCE_ROLE_NAME
# attach role to profile
aws --endpoint-url $AWS_ENDPOINT_URL iam add-role-to-instance-profile --instance-profile-name $INSTANCE_ROLE_NAME --role-name $INSTANCE_ROLE_NAME

echo "create batch service role"

aws --endpoint-url $AWS_ENDPOINT_URL iam create-role \
    --role-name AWSBatchServiceRole \
    --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["batch.amazonaws.com", "ec2.amazonaws.com""]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'
# set up existing service role
aws --endpoint-url $AWS_ENDPOINT_URL iam attach-role-policy \
    --role-name AWSBatchServiceRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole


# list security groups
SECURITY_GROUP_ID=$(aws --endpoint-url $AWS_ENDPOINT_URL \
    ec2 describe-security-groups \
    --query "SecurityGroups[*].[GroupId]" --output text)

echo "Found security group $SECURITY_GROUP_ID"

# list subnets
SUBNET_ID=$(aws --endpoint-url $AWS_ENDPOINT_URL ec2 describe-subnets --query "Subnets[*].[SubnetId][0]" --output text)

echo "Found subnet id $SUBNET_ID"

# query things
# aws --endpoint-url $AWS_ENDPOINT_URL iam get-role --role-name my-test-role
# aws --endpoint-url $AWS_ENDPOINT_URL iam delete-role-policy --role-name my-test-role --policy-name my-test-policy
# aws --endpoint-url $AWS_ENDPOINT_URL iam detach-role-policy --role-name my-test-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole
# aws --endpoint-url $AWS_ENDPOINT_URL iam delete-role --role-name AWSBatchServiceRole
# aws --endpoint-url $AWS_ENDPOINT_URL iam list-role-policies --role-name AWSBatchServiceRole

echo "Create compute environment"


# create compute environment
read -r -d '' JSON << EOM
{
  "computeEnvironmentName": "C4OnDemand",
  "type": "MANAGED",
  "state": "ENABLED",
  "serviceRole": "arn:aws:iam::123456789012:role/AWSBatchServiceRole",
  "computeResources": {
    "type": "EC2",
    "minvCpus": 0,
    "maxvCpus": 128,
    "desiredvCpus": 48,
    "instanceTypes": [
      "c4.large",
      "c4.xlarge",
      "c4.2xlarge",
      "c4.4xlarge",
      "c4.8xlarge"
    ],
    "subnets": [
      "${SUBNET_ID}"
    ],
    "securityGroupIds": [
      "${SECURITY_GROUP_ID}"
    ],
    "ec2KeyPair": "id_rsa",
    "instanceRole": "arn:aws:iam::123456789012:instance-profile/${INSTANCE_ROLE_NAME}",
    "tags": { "Name": "Batch Instance - C4OnDemand" }
  }
}
EOM
echo $JSON
aws --endpoint-url $AWS_ENDPOINT_URL batch create-compute-environment --cli-input-json "$JSON"

echo "create job definition"

read -r -d '' JSON << EOM
{
  "jobDefinitionName": "${JOB_NAME}-definition",
  "type": "container",
  "containerProperties": {
    "image": "print-color",
    "vcpus": 1,
    "memory": 1024,
    "jobRoleArn": "arn:aws:iam::123456789012:role/$INSTANCE_ROLE_NAME"
  }
}
EOM
aws --endpoint-url $AWS_ENDPOINT_URL \
    batch register-job-definition \
    --cli-input-json "$JSON"

echo "create a job queue ${JOB_NAME}-queue"

read -r -d '' JSON << EOM
{
  "jobQueueName": "${JOB_NAME}-queue",
  "state": "ENABLED",
  "priority": 1,
  "computeEnvironmentOrder": [
    {
      "order": 1,
      "computeEnvironment": "arn:aws:batch:us-west-2:123456789012:compute-environment/C4OnDemand"
    }
  ]
}
EOM
aws --endpoint-url $AWS_ENDPOINT_URL \
    batch create-job-queue \
    --cli-input-json "$JSON"

echo "submit a job"

read -r -d '' JSON << EOM
{
  "jobName": "$JOB_NAME",
  "jobQueue": "$JOB_NAME-queue",
  "arrayProperties": {
    "size": 7
  },
  "jobDefinition": "arn:aws:batch:us-west-2:123456789012:job-definition/${JOB_NAME}-definition:1"
}
EOM
aws --endpoint-url $AWS_ENDPOINT_URL \
    batch submit-job \
    --cli-input-json "$JSON"

# list jobs
aws --endpoint-url $AWS_ENDPOINT_URL \
    batch list-jobs \
    --job-queue "$JOB_NAME-queue" --query "jobSummaryList[*].[jobId]" --output text | read JOB_ID

# get a job
aws --endpoint-url $AWS_ENDPOINT_URL \
    batch describe-jobs \
    --jobs $JOB_ID

echo "Batch setup complete"
