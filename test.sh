#!/bin/bash

# Performs an environment switch and tests for http errors during changeover window.
# Usage:
#  ./test.sh $ENVIRONMENT_NAME
# e.g.
#  ./test.sh green

ENVIRONMENT_NAME=$1

. ./helpers.sh

./switch.sh $ENVIRONMENT_NAME || handle "Failed to perform switch. Aborting test."

printBlue "Starting test..."
echo ""
LBURL=$(runTF output -raw load_balancer_url)
for((i=0;i<=150;++i)) do
    echo -ne "\033[0K\r$i/150: "
    if ! curl "http://${LBURL}/api" ; then
        echo
        handle "Failed!"
    fi
    sleep 0.1
done 
echo
printGreen "Passed!"