#!/bin/bash

gcloud auth activate-service-account ${SERVICE_ACCOUNT} --key-file=/etc/gcloud/key.json
echo y | gcloud auth configure-docker

go get ${REPOSITORY}
cd /go/src/${REPOSITORY}/config/
KO_DOCKER_REPO=${REGISTRY} ko apply -f .
