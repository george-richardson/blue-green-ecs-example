#!/bin/bash

# Builds and deploys a new version of our code to one of the environments.
# Usage:
#   ./deploy.sh $PATH_TO_CODE $VERSION_NUMBER $ENVIRONMENT_NAME
# e.g. 
#   ./deploy.sh ./go-app/v2/ 2 green

PATH_TO_CODE=$1
VERSION_NUMBER=$2
ENVIRONMENT_NAME=$3

set -e
. ./helpers.sh

printBlue "Loading terraform outputs."
ECRURL=$(runTF output -raw ecr_repository_url)
IMAGE_NAME="${ECRURL}:${2}"

printBlue "Building new version of app..."
docker build --tag $IMAGE_NAME $PATH_TO_CODE || handle "Failed to build docker image."

printBlue "Pushing image '$IMAGE_NAME'..."
docker push $IMAGE_NAME || handle "Failed to push docker image."

printBlue "Creating new ECS task definition..."
CURRENT_TASK_DEF=$(runAWS ecs describe-task-definition --task-definition "helloworld")
NEW_TASK_DEF=$(echo $CURRENT_TASK_DEF | docker run -i --rm imega/jq:1.6 --arg IMG $IMAGE_NAME '.taskDefinition | .containerDefinitions[0].image = $IMG | del(.taskDefinitionArn) | del(.revision) | del(.status) | del(.requiresAttributes) | del(.compatibilities) | del(.registeredAt) | del(.registeredBy)')
CREATED_TASK=$(docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION amazon/aws-cli:2.2.13 ecs register-task-definition --cli-input-json "$NEW_TASK_DEF")
CREATED_TASK_ARN=$(echo $CREATED_TASK | docker run -i --rm imega/jq:1.6 --raw-output '.taskDefinition.taskDefinitionArn')

printBlue "Updating '$ENVIRONMENT_NAME' service to use new task definition..."
runAWS ecs update-service --cluster "hello_world" --service "$ENVIRONMENT_NAME" --task-definition "$CREATED_TASK_ARN" --force-new-deployment

printGreen "Deployed new task to service!"