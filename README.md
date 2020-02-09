# ko-builder

An image to build go programs and deploy them in Kubernetes

## On Google Cloud GKE

### Prepare the cluster

- define the `PROJECT` variable with the name of your Google Cloud project:

  ```sh
  $ PROJECT=my-project
  ```

- Create a Google Cloud service account with access to the registry of the project and get a JSON key for this service account, for example:

  ```sh
  $ gcloud iam service-accounts create ko-builder-sa \
     --description "SA for KO builder" \
     --display-name "SA for KO builder"
  Created service account [ko-builder-sa].

  $ gcloud iam service-accounts enable \
     ko-builder-sa@$PROJECT.iam.gserviceaccount.com
  Enabled service account [ko-builder-sa@$PROJECT.iam.gserviceaccount.com].

  $ gcloud iam service-accounts keys create key.json \
     --iam-account \
     ko-builder-sa@$PROJECT.iam.gserviceaccount.com
  created key [...] of type [json] as [key.json] for [ko-builder-sa@ko-demo.iam.gserviceaccount.com]

  $ gcloud projects add-iam-policy-binding $PROJECT \
    --member \
    "serviceAccount:ko-builder-sa@$PROJECT.iam.gserviceaccount.com" --role "roles/storage.admin"
  Updated IAM policy for project [$PROJECT].
  ```

- Create a Kubernetes secret named `gcloud` with the key.json contents:

  ```sh
  $ kubectl create secret generic gcloud \
     --from-file=key.json
  secret/gcloud created
  ```

- Create a configmap named `config` with the following variables:

  - `REGISTRY`: The registry on which to push built images
  - `SERVICE_ACCOUNT`: a Google Cloud service account with access to registry

  For example:

  ```sh
  $ kubectl create configmap config \
     --from-literal=SERVICE_ACCOUNT=ko-builder-sa@$PROJECT.iam.gserviceaccount.com \
     --from-literal=REGISTRY=eu.gcr.io/$PROJECT
  configmap/config created
  ```

- Create a Kubernetes service account with credentials to create the resources specified in your repository, for example:

  ```sh
  $ kubectl create sa ko-builder
  serviceaccount/ko-builder created

  $ kubectl create clusterrole ko-builder-role \
   --verb=list,get,create,patch \
   --resource=deployments.apps,services,namespaces,serviceaccounts

  $ kubectl create clusterrolebinding ko-builder-rolebinding \
     --clusterrole=ko-builder-role \
     --serviceaccount=default:ko-builder
  clusterrolebinding.rbac.authorization.k8s.io/ko-builder-role created
  ```

### For each program you want to build and deploy

- Edit the manifest `ko-builder.yaml` to change:

  - the value of the `REPOSITORY` environment variable with the repository from which you want to get sources to build,
  - the value of `CHECKOUT` with the branch / commit to checkout (`master` if you are not sure),
  - the value of `CONFIG_PATH` with the path into the repository containing manifests of Kubernetes resources, including Deployment resources with an `image` field compatible with [ko](https://github.com/google/ko).

- Start the builder:

  ```sh
  $ kubectl apply -f ko-builder.yaml
  job.batch/ko-builder created
  ```

- Wait for the job completion:

  ```sh
  $ kubectl get jobs ko-builder -w
  job.batch/ko-builder created
  NAME         COMPLETIONS   DURATION   AGE
  ko-builder   0/1           0s         3s
  ko-builder   1/1           16s        16s
  ```

- Verify that the resources were created:

  > you can use [kubectl tree plugin](https://github.com/ahmetb/kubectl-tree) and see that the resources created are "owned" by the pod created by the `ko-builder` job.

  ```sh
  $ kubectl tree jobs ko-builder
  NAMESPACE  NAME                                          READY  REASON        AGE
  default    Job/ko-builder                                -                    44s
  default    └─Pod/ko-builder-x4cgs                        False  PodCompleted  44s
  default      ├─Deployment/echo-controller                -                    18s
  default      │ └─ReplicaSet/echo-controller-5f4bb6868f   -                    18s
  default      │   └─Pod/echo-controller-5f4bb6868f-fj5zk  True                 18s
  default      └─Service/echo-service                      -                    18s
  ```

- Thanks to these owner references, the created objects will be deleted when you delete the parent job `ko-builder`:

  ```sh
  $ kubectl delete jobs ko-builder
  job.batch "ko-builder" deleted
  # After several seconds
  $ kubectl get deployment echo-controller
  Error from server (NotFound): deployments.extensions "echo-controller" not found
  $ kubectl get svc echo-service
  Error from server (NotFound): services "echo-service" not found
  ```

### Generating your own ko-builder image

Build the Docker image and push it to your own registry:

```sh
$ docker build . -t eu.gcr.io/$PROJECT/ko-builder
Successfully built ...
Successfully tagged eu.gcr.io/$PROJECT/ko-builder:latest
$ docker push eu.gcr.io/$PROJECT/ko-builder
```

### Defining an owner

By default, the Pod deploying the resources will be the owner of the deployed resources.

You can define the following environment variables for the Job to indicate the owner (useful if you want to make execute this task by an operator):

- `OWNER_APIVERSION`: the apiVersion of the owner,
- `OWNER_CONTROLLER`: `true` if the owner is a controller, `false` otherwise,
- `OWNER_KIND`: the kind of the owner (`kind`),
- `OWNER_NAME`: the name of the owner (`metadata.name`),
- `OWNER_UID`: the uid of the owner (`metadata.uid`).
