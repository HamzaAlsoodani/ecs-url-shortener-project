#!/bin/sh
# Runs inside LocalStack once it is ready: creates the queue the api and worker use
awslocal sqs create-queue --queue-name click-events
