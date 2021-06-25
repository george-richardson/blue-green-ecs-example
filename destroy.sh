#!/bin/bash

# Cleans up our AWS resources.
# Usage: 
#  ./destroy.sh

set -e
. ./helpers.sh

printBlue "Destroying infra with Terraform..."
runTF destroy -auto-approve || handle "Failed to destroy Terraform resources."

printGreen "Resources destroyed. Au revoir."
