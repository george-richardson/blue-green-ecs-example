# blue-green-ecs-example

This repository contains an example blue-green architecture and deployment process using AWS ECS fargate.

## Requirements

 * Docker
 * bash
 * curl
 * Some valid AWS credentials with permissions to create EC2/ECS/ECR/IAM resources.

Before running you'll need to export your AWS credentials as environment variables so they can be used by the Terraform and AWS CLI docker containers.

```
export AWS_ACCESS_KEY_ID="AKIAFAKEACCESSKEY"
export AWS_SECRET_ACCESS_KEY="s0m3SeCr37AcCe5SKeY"
export AWS_DEFAULT_REGION="eu-west-2" # Or wherever you want to deploy resources.
```

## Instructions

After extensive market research our incredible PMs have discovered a gap in the market for an app that greets people. Apparently many people prefer their salutations to come from a computer. Our dilligent developers have over the course of mere minutes created a web application that should solve all of our potential customer's needs. 

First perform an initial deployment of the Terraform code (which can be found in `./terraform/`). This will deploy our ECR repository, ECS cluster/tasks/services and build and push an initial version of our app.

```
./init.sh
```

The final line of output should present you with the URLs for our two environments. Prod is on HTTP port 80 while dev is on port 81. Initially the "green" environment is our prod environment.

Our initial deployment deployed the code found in `./go-app/v1`. This app simply presents a "Hello World" message for all to see with a pretty green background. Because we are looking for serious B2B customers we also expose an API at the `/api` endpoint which presents our message in plain text. Both html page and API endpoint can change the message by appending a `?name=` query parameter to the URL.

After putting out our MVP we've had feedback from users that they'd rather everything be in French and also that our API should return a valid JSON response because apparently "JSON is cool". Luckily our omnipotent developers had seen this coming and have already prepared a v2 which can be found in `./go-app/v2`. Let's deploy version 2 to our blue (currently dev) environment. 

```
./deploy.sh "./go-app/v2/" 2 blue
```

The deploy script builds our code at `./go-app/v2/` packaged into a new docker image with tag "2" which is pushed to ECR and then creates a new ECS task definition and applies it to the "blue" ECS service. Depending on how fast Fargate ECS is feeling you should see this new task deployed within a few minutes to our dev (port 81) environment. (NOTE: There may be a brief period where requests are being load balanced between the new and old version on the service before connection draining kicks in.)

Using our incredibly good QA process (which consists of glancing at the new version and seeing it's now got a fun new colour) we are now confident that this new version is ready for the big time. Let's make the switch and check everything goes well using our extremely handy environment promotion/test script.

```
./test.sh blue
```

This script is going to switch our load balancer listener for prod (port 80) over to the "blue" environment and our dev (port 81) listener over to the green environment. It is then going to start making requests to our prod environment every 0.1 seconds during the changeover window and error out if there are any unsuccesful status codes. During our test we should see the output change over to the much more beautiful French language.

After deploying our new version it quickly became apparent that customers were lying to us and they hated the changes. Rather than deal with their fickle ways we decide to close up shop and try developing a new product based on farewells. Lets cleanup all the resources we deployed.

```
./destroy.sh
```
