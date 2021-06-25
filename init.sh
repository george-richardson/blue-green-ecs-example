#!/bin/bash

# Deploys our prerequisite AWS resources and builds and pushes an initial version of our app.
# Usage: 
#  ./init.sh

set -e
. ./helpers.sh

printBlue "Deploying infra with Terraform..."
runTF init || handle "Failed to initialize Terraform!"
runTF apply -auto-approve || handle "Failed to apply Terraform!"
ECRURL=$(runTF output -raw ecr_repository_url)
LBURL=$(runTF output -raw load_balancer_url)

printBlue "Building initial version of go app..."
IMAGE_NAME="${ECRURL}:1"
docker build --tag $IMAGE_NAME go-app/v1/ || handle "Failed to build go app!"

printBlue "Pushing go app to ECR repository..."
runAWS ecr get-login-password | docker login --username AWS --password-stdin $ECRURL || handle "Failed to login to ECR repository!"
docker push $IMAGE_NAME || handle "Failed to push docker image!"

printGreen "Done! Go to http://$LBURL (prod) or http://$LBURL:81 (dev) and wait for the ECS service to start."