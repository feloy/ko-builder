#!/bin/bash

gcloud auth activate-service-account ${SERVICE_ACCOUNT} --key-file=/etc/gcloud/key.json
echo y | gcloud auth configure-docker

go get ${REPOSITORY}
cd /go/src/${REPOSITORY}${CONFIG_PATH}
git checkout ${CHECKOUT}

KO_DOCKER_REPO=${REGISTRY} ko apply -f .

POD_NAME=$(cat /pod/name)
POD_UID=$(cat /pod/uid)

OWNER_APIVERSION=${OWNER_APIVERSION:-core}
OWNER_CONTROLLER=${OWNER_CONTROLLER:-false}
OWNER_KIND=${OWNER_KIND:-Pod}
OWNER_NAME=${OWNER_NAME:-${POD_NAME}}
OWNER_UID=${OWNER_UID:-${POD_UID}}

# Add ownerReferences to all resources
kubectl patch -p "
metadata:
  ownerReferences:
  - apiVersion: ${OWNER_APIVERSION}
    controller: ${OWNER_CONTROLLER}
    blockOwnerDeletion: true
    kind: ${OWNER_KIND}
    name: ${OWNER_NAME}
    uid: ${OWNER_UID}
" -f .
