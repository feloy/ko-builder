# ko-builder

An image to build go programs and deploy them in Kubernetes

## On Google Cloud GKE

- define the `PROJECT` variable with the name of your Google Cloud project:

  ```sh
  $ PROJECT=my-project
  ```

- Build the Docker image and push it to the registry of your project:

  ```sh
  $ docker build . -t eu.gcr.io/$PROJECT/ko-builder
  Successfully built ...
  Successfully tagged eu.gcr.io/$PROJECT/ko-builder:latest
  $ docker push eu.gcr.io/$PROJECT/ko-builder

  ```

- Edit the manifest `ko-builder.yaml` to change the value of the `REPOSITORY` environment variable with the repository you want to build from and the `image` path with your own repository.

  In this directory, the `/config/` directory must contain manifests of Kubernetes resources, including Deployment resources with an `image` field compatible with [ko](https://github.com/google/ko).

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

- Create a Kubernetes service account with credentials to create the resources specified in the `/config/` directory of your repository, for example:

  ```sh
  $ kubectl create sa ko-builder
  serviceaccount/ko-builder created

  $ kubectl create clusterrole ko-builder-role \
   --verb=list,get,create \
   --resource=deployments.apps,services,namespaces,serviceaccounts

  $ kubectl create clusterrolebinding ko-builder-rolebinding \
     --clusterrole=ko-builder-role \
     --serviceaccount=default:ko-builder
  clusterrolebinding.rbac.authorization.k8s.io/ko-builder-role created
  ```

- Start the builder:

  ```sh
  $ kubectl apply -f ko-builder.yaml
  job.batch/ko-builder created
  ```
