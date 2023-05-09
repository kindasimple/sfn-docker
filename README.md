# sfn-docker

Run AWS step-functions locally with aws-stepfunctions-local in docker and AWS batch with moto

## quickstart

```sh
# bring up docker containers.
# set up compute environment in moto container
# run step function in aws-stepfunctions-local container
make run

# view moto web UI
make open

# run step function
make reset