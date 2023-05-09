#!/bin/bash

export INSTANCE_ROLE_ARN="arn:aws:iam::123456789012:role/my-test-role"
export JOB_NAME=test-job
export STATE_MACHINE_NAME=myTestBatchJob
export BATCH_URL=http://localhost:8083


# aws stepfunctions --endpoint-url $BATCH_URL create-state-machine --definition "{\
#   \"Comment\": \"A Hello World example of the Amazon States Language using a Pass state\",\
#   \"StartAt\": \"HelloWorld\",\
#   \"States\": {\
#     \"HelloWorld\": {\
#       \"Type\": \"Pass\",\
#       \"End\": true\
#     }\
#   }}" --name "HelloWorld" --role-arn $INSTANCE_ROLE_ARN

# delete state machine
# aws stepfunctions --endpoint-url $BATCH_URL \
#     delete-state-machine \
#     --state-machine-arn "arn:aws:states:us-west-2:123456789012:stateMachine:$STATE_MACHINE_NAME"

echo "create step function state machine"

# read -r -d '' JSON << EOM
# {
#   "StartAt": "BATCH_JOB",
#   "States": {
#     "BATCH_JOB": {
#       "Type": "Task",
#       "Resource": "arn:aws:states:::batch:submitJob",
#       "Parameters": {
#         "JobDefinition": "$JOB_NAME-definition:1",
#         "JobName": "$JOB_NAME",
#         "JobQueue": "$JOB_NAME-queue",
#         "Parameters.$": "$.batchjob.parameters",
#         "ContainerOverrides": {
#           "ResourceRequirements": [
#             {
#               "Type": "VCPU",
#               "Value": "4"
#             }
#           ]
#         }
#       },
#       "End": true
#     }
#   }
# }
# EOM

read -r -d '' JSON << EOM
{
  "StartAt": "BatchJob",
  "States": {
    "BatchJob": {
      "Type": "Task",
      "Resource": "arn:aws:states:::batch:submitJob",
      "ResultPath": "$.taskresult.jobDefinition.jobBatchInfo",
      "Parameters": {
        "JobDefinition": "$JOB_NAME-definition:1",
        "ArrayProperties": {
          "Size": "5"
        },
        "JobName": "$JOB_NAME",
        "JobQueue": "$JOB_NAME-queue",
        "ContainerOverrides": {
          "Environment": [{
            "Name": "PHRASE",
            "Value": "hello"
          }]
        }
      },
      "End": true
    }
  }
}
EOM
aws stepfunctions --endpoint-url $BATCH_URL \
    create-state-machine \
    --name "$STATE_MACHINE_NAME" \
    --role-arn $INSTANCE_ROLE_ARN \
    --definition "$JSON"

echo "describe state machine"

aws stepfunctions --endpoint-url $BATCH_URL \
    describe-state-machine \
    --state-machine-arn \
    "arn:aws:states:us-west-2:123456789012:stateMachine:$STATE_MACHINE_NAME"

echo "run in batch"
aws stepfunctions --endpoint-url $BATCH_URL \
    start-execution \
    --state-machine-arn "arn:aws:states:us-west-2:123456789012:stateMachine:$STATE_MACHINE_NAME" \
    --name "BatchJob-1-$(date +%s)" \
    --input '{"batchjob": {"parameters": {"command": ["echo", "hello world"]}}}'

echo "list executions"

SFN_EXECUTION_NAME=$(aws stepfunctions --endpoint-url $BATCH_URL \
    list-executions \
    --state-machine-arn \
    "arn:aws:states:us-west-2:123456789012:stateMachine:$STATE_MACHINE_NAME" \
    --query "executions[*].[name][0]" \
    --output text)

echo "get execution $SFN_EXECUTION_NAME"
aws stepfunctions --endpoint-url $BATCH_URL \
    describe-execution \
    --execution-arn \
    "arn:aws:states:us-west-2:123456789012:execution:$STATE_MACHINE_NAME:$SFN_EXECUTION_NAME"

echo "describe execution history for $SFN_EXECUTION_NAME"
aws stepfunctions --endpoint-url $BATCH_URL \
    get-execution-history \
    --execution-arn \
    "arn:aws:states:us-west-2:123456789012:execution:$STATE_MACHINE_NAME:$SFN_EXECUTION_NAME"

