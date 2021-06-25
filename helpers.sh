#!/bin/bash

BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[0;31m'
NC='\033[0m'

function printBlue() {
    echo -e "${BLUE}${1}${NC}"
}

function printGreen() {
    echo -e "${GREEN}${1}${NC}"
}

function handle() {
    echo -e "${RED}${1}${NC}"
    exit 1
}

function runTF() {
    docker run --rm -v "$(pwd)/terraform/:/code/" --workdir /code/ -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION hashicorp/terraform:1.0.1 $@
}

function runAWS() {
    docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION amazon/aws-cli:2.2.13 $@
}