#!/bin/bash

# Changes the primary load balancer listener to point to the given environment.
# Usage:
#   ./switch.sh $ENVIRONMENT_NAME
# e.g. 
#   ./switch.sh green

ENVIRONMENT_NAME=$1

set -e
. ./helpers.sh

printBlue "Loading Terraform outputs..."

PRIMARY_LISTENER_ARN=$(runTF output -raw primary_listener_arn)
SECONDARY_LISTENER_ARN=$(runTF output -raw secondary_listener_arn)

BLUE_TARGET_GROUP_ARN=$(runTF output -raw blue_target_group_arn)
GREEN_TARGET_GROUP_ARN=$(runTF output -raw green_target_group_arn)

if [[ "$ENVIRONMENT_NAME" == "green" ]]; then
    PRIMARY_TARGET_GROUP_ARN="$GREEN_TARGET_GROUP_ARN"
    SECONDARY_TARGET_GROUP_ARN="$BLUE_TARGET_GROUP_ARN"
elif [[ "$ENVIRONMENT_NAME" == "blue" ]]; then
    PRIMARY_TARGET_GROUP_ARN="$BLUE_TARGET_GROUP_ARN"
    SECONDARY_TARGET_GROUP_ARN="$GREEN_TARGET_GROUP_ARN"
else 
    handle "Unknown argument $ENVIRONMENT_NAME"
fi

printBlue "Switching primary listener to '$ENVIRONMENT_NAME' target group..."

runAWS elbv2 modify-listener --listener-arn $PRIMARY_LISTENER_ARN --default-actions "Type=forward,TargetGroupArn=$PRIMARY_TARGET_GROUP_ARN" > /dev/null || handle "Failed to change primary listener!"
runAWS elbv2 modify-listener --listener-arn $SECONDARY_LISTENER_ARN --default-actions "Type=forward,TargetGroupArn=$SECONDARY_TARGET_GROUP_ARN" > /dev/null || handle "Failed to change secondary listener!"

printGreen "Switch initiated."
