#!/bin/bash

gcloud auth activate-service-account ${SERVICE_ACCOUNT} --key-file=/etc/gcloud/key.json
echo y | gcloud auth configure-docker

go get ${REPOSITORY}
cd /go/src/${REPOSITORY}${CONFIG_PATH}

POD_UID=$(cat /pod/uid)
POD_NAME=$(cat /pod/name)

KO_DOCKER_REPO=${REGISTRY} ko apply -f .

# Add ownerReferences to all resources
kubectl patch -p "
metadata:
  ownerReferences:
  - apiVersion: core
    controller: true
    blockOwnerDeletion: true
    kind: Pod
    name: ${POD_NAME}
    uid: ${POD_UID}
" -f .
