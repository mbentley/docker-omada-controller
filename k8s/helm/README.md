# Kubernetes Deployment Guide

In advanced setups, deploying applications in container orchestrators like Kubernetes is common, even in homelabs to enhance reliability. This guide will walk you through deploying the Omada Controller and MongoDB to Kubernetes using Helm. It will implement the external MongoDB deployment pattern for the Omada Controller.

Below, we’ll use Helm to deploy both **MongoDB** and **Omada Controller**. It is assumed that you have a working knowledge of Kubernetes and Helm in order to customize the deployment to your needs.

## Prerequisites

- A Kubernetes cluster v1.23+ with a storage class configured
- A working LoadBalancer Service or Ingress Controller configuration for exposing the Omada Controller
- Default Kubernetes config pointing to your cluster
- Helm v3.8.0+ (installed and in PATH)
- Kubectl (installed and in PATH)
- Linux or MacOS as runtime environment (Windows will work but is not tested or documented)
- Cloned this repository to your local machine

### Optional

- External Secrets Operator (if you want to fetch secrets from external vault or secrets manager)
- cert-manager (if you want to generate TLS certificates)
- External DNS (if you want to manage DNS records automatically)
- Ingress Controller (if you want to expose Omada via Ingress)
- Reloader Operator (if you want to automatically reload Omada Controller when TLS certificates change)

> [!NOTE]
> If you prefer to generate and store the required credentials in a vault, use **External Secrets** to fetch credentials and generate Kubernetes secret automatically.
> To do this ensure you have the operator installed and configured. Then deploy the ExternalSecret manifest before proceeding (this would replace the secret creation steps below).

## Deploy MongoDB

We use the Bitnami's MongoDB chart. Specific values are required in order for Omada to be able to use the database. This includes specific values for the `auth` and `initdbScripts` sections. Other recommended updates include explicitly setting persistence and resource limits configurations.

Currently the Omada Controller supports MongoDB versions 3.0 through 8.0. It is recommended to use the latest MongoDB version supported by Omada or at least a version that is still maintained by [MongoDB](https://www.mongodb.com/legal/support-policy/lifecycles). The latest version of MongoDB is 8.0 and is supported till October 31, 2029. This chart defaults to the latest version of MongoDB. In the future if a newer MongoDB version is released that is not supported by Omada you maybe required to update the image tag for the MongoDB chart in order to use a version that is supported.

> [!IMPORTANT]
> Before proceeding customize the [values file](../helm/mongodb/values.yaml) with the parameters to meet your needs. No deployment will be exactly the same. Review the [official chart documentation](https://github.com/bitnami/charts/blob/main/bitnami/mongodb/README.md) for all possible values and configurations you may require.

Let's deploy the chart:

1. Create namespace for MongoDB and Omada Controller

    ```console
    NAMESPACE="omada"

    kubectl create ns $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    ```

2. Create secret for MongoDB

    ```console
    ROOT_PASS=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c32)
    OMADA_DB_PASS=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c32)
    RS_KEY=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c32)

    kubectl create secret generic omada-db-secret \
      --from-literal=mongodb-root-password=$ROOT_PASS \
      --from-literal=mongodb-passwords=$OMADA_DB_PASS \
      --from-literal=mongodb-replica-set-key=$RS_KEY \
      -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    ```

3. Deploy MongoDB Helm chart

    ```console
    helm install omada-db oci://registry-1.docker.io/bitnamicharts/mongodb \
      --namespace $NAMESPACE --wait --timeout 10m \
      -f ./k8s/helm/mongodb/values.yaml
    ```

## Deploy Omada Controller

This repository now contains a [Helm chart for Omada Controller](../../helm/omada-controller-helm/README.md). It will be used to complete the Omada Controller deployment using Helm instead of custom crafted manifests.

Prior to deploying the Omada Controller a decision is required on how to expose it external to Kubernetes. This can be done Kubernetes Ingress or LoadBalancer service. If you choose to use Ingress, you will need to have an Ingress Controller installed and configured. If you choose to use a LoadBalancer service, you will need to have a LoadBalancer Controller installed and configured. If you're in an on-premises or homelab environment, you might need tools like MetalLB or Kube-VIP to route traffic and provide IP addresses for LoadBalancer services.

Further enhancements to accessing the Omada Controller can be made by using [cert-manager](https://cert-manager.io/) to create a SSL certificate and [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) to create an A record for the Omada Controller URL. These are optional and not required for the Omada Controller to function.

In this example we will use a LoadBalancer service type with no extra configurations.

> [!IMPORTANT]
> Before proceeding customize the [values file](../helm/omada-controller/values.yaml) with the parameters to meet your needs. Additional values files have been provided to demonstrate using the [Ingress](../helm/omada-controller/values-ingress.yaml) and [LoadBalancer](../helm/omada-controller/values-loadbalancer-ssl.yaml) with ExternalDNS and cert-manager configured. No deployment will be exactly the same.

Let's deploy the chart:

1. Create secret for MongoDB Connection String

    ```console
    kubectl create secret generic omada-db-uri-secret \
      --from-literal=mongodb-uri="mongodb://omada:${OMADA_DB_PASS}@omada-db-mongodb.${NAMESPACE}.svc.cluster.local:27017/omada?authSource=omada" \
      -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    ```

2. Deploy Omada Controller Helm chart

    ```console
    helm install omada-controller oci://registry-1.docker.io/mbentley/omada-controller-helm \
      --namespace $NAMESPACE --wait --timeout 10m \
      -f ./k8s/helm/omada-controller/values.yaml
    ```

3. Verify the deployment and all pods are running

    ```console
    kubectl get pods -n $NAMESPACE
    ```

4. Get the LoadBalancer IP address

    ```console
    kubectl get svc omada-controller -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    ```

5. Access the Omada Controller web interface

    ```console
    https://<LoadBalancer IP>:8043
    ```

> [!NOTE]
> The first time you access the Omada Controller web interface, you will need to accept the self-signed certificate.
