#!/bin/bash

gcloud auth activate-service-account ${SERVICE_ACCOUNT} --key-file=/etc/gcloud/key.json
echo y | gcloud auth configure-docker

go get ${REPOSITORY}
cd /go/src/${REPOSITORY}${CONFIG_PATH}
git checkout ${CHECKOUT}

KO_DOCKER_REPO=${REGISTRY} ko apply -f .

POD_UID=$(cat /pod/uid)
POD_NAME=$(cat /pod/name)

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
