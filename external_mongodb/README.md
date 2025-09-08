# Notes for External MongoDB

* [Common Steps](#common-steps)
* [MongoDB + Omada Controller (fresh install)](#mongodb--omada-controller-fresh-install)
* [Migration from All in One](#migration-from-all-in-one)
  * [Example using a bridge network](#example-using-a-bridge-network)
  * [Example using `--network host`](#example-using---network-host)

## Common Steps

You can build a Docker image without MongoDB using the `NO_MONGODB=true` build arg but it's not necessary to run MongoDB as an external container as it will simply not start if you pass the `MONGO_EXTERNAL` environment variable at runtime.

<details>
<summary>Click to expand the docker build examples</summary>

1. (Optional) Build the Docker Image

    As of 3/19/2024, a multi-arch test image is available on Docker Hub as `mbentley/omada-controller:5.13-external-mongo-test` for `amd64`, `arm64`, and `armv7l` but you can build them yourself:

    ```bash
    # amd64
    docker build \
      --pull \
      --build-arg NO_MONGODB=true \
      --build-arg ARCH="amd64" \
      --platform linux/amd64 \
      --progress plain \
      -f Dockerfile \
      -t mbentley/omada-controller:5.13-external-mongo-test-amd64 \
      -t mbentley/omada-controller:5.13-external-mongo-test .

    # arm64
    docker build \
      --pull \
      --build-arg NO_MONGODB=true \
      --build-arg ARCH="arm64" \
      --platform linux/arm64 \
      --progress plain \
      -f Dockerfile \
      -t mbentley/omada-controller:5.13-external-mongo-test-arm64 \
      -t mbentley/omada-controller:5.13-external-mongo-test .

    # armv7l
    docker build \
      --pull \
      --build-arg NO_MONGODB=true \
      --build-arg ARCH="armv7l" \
      --platform linux/arm/v7 \
      --progress plain \
      -f Dockerfile \
      -t mbentley/omada-controller:5.13-external-mongo-test-armv7l \
      -t mbentley/omada-controller:5.13-external-mongo-test .
    ```

</details>

1. Create a Docker `bridge` Network

    Creating and using a custom bridge network allows for container to container comunication which is one method to isolate the communication, assuming you're using bridged mode and not host or macvlan:

    ```bash
    docker network create -d bridge omada
    ```

## MongoDB + Omada Controller (fresh install)

This expects that you are in this project's root where the `Dockerfile` is.  Update the path for the MongoDB `/docker-entrypoint-initdb.d` bind mount if you want/need to but these commands should all work from there.

1. Start MongoDB

    * As of late 2025, TP-Links supports MongoDB 3-8 for the controller. Update the MongoDB image version tag as you wish. I have yet to test it extensively though, just gone through basic setup.
    * If you are not using bridge mode, you can omit the network to just have MongoDB exposed as you need. Password authentication is still in use to secure MongoDB in that case.
    * The `omada` user in MongoDB will have the following credentials: user: `omada` & pwd: `0m4d4`.  This is defined in the `omada.js` file that it used to initialize the databases and you can modify if as you wish.

    ```bash
    docker run -d \
      --name mongodb \
      --network omada \
      --stop-timeout 60 \
      -p 27017:27017 \
      -e MONGO_INITDB_ROOT_USERNAME="admin" \
      -e MONGO_INITDB_ROOT_PASSWORD="password" \
      -e MONGO_INITDB_DATABASE="omada" \
      --mount type=volume,source=omada-mongo-config,destination=/data/configdb \
      --mount type=volume,source=omada-mongo-data,destination=/data/db \
      --mount type=bind,source="${PWD}/external_mongodb",destination=/docker-entrypoint-initdb.d \
      mongo:4
    ```

1. Start the Omada Controller

    This is a basic run command, taking most of the default env vars. Assuming you use the bridge network, the containers will use the custom `omada` Docker bridge network for container to container communication.

    ```bash
    docker run -d \
      --name omada-controller \
      --ulimit nofile=4096:8192 \
      --network omada \
      --stop-timeout 60 \
      -p 8088:8088 \
      -p 8043:8043 \
      -p 8843:8843 \
      -p 19810:19810/udp \
      -p 27001:27001/udp \
      -p 29810:29810/udp \
      -p 29811-29817:29811-29817 \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      --mount type=volume,source=omada-logs,destination=/opt/tplink/EAPController/logs \
      -e MONGO_EXTERNAL="true" \
      -e EAP_MONGOD_URI="mongodb://omada:0m4d4@mongodb.omada:27017/omada" \
      mbentley/omada-controller:5.15 &&\
    docker logs -f omada-controller
    ```

1. Cleanup After Testing

    If you want to clean everything up, this command will kill the containers, remove the volumes, and remove the bridge network:

    ```bash
    docker rm -f mongodb omada-controller ;\
      docker volume rm omada-mongo-config omada-mongo-data omada-data omada-logs ;\
      docker network rm omada
    ```

## Migration from All in One

While I have this WIP for migrating from all in one, it would be much simplier to take a backup from the Omada Controller and then do a restore of the config to a new controller install with a modern MongoDB version as the migration from version to version is very tedious.

### Example using a bridge network

1. Run standard all in one container (mongodb + controller)

    ```bash
    docker run -d \
      --name omada-controller \
      --ulimit nofile=4096:8192 \
      --network omada \
      --stop-timeout 60 \
      -p 8088:8088 \
      -p 8043:8043 \
      -p 8843:8843 \
      -p 19810:19810/udp \
      -p 27001:27001/udp \
      -p 29810:29810/udp \
      -p 29811-29817:29811-29817 \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      --mount type=volume,source=omada-logs,destination=/opt/tplink/EAPController/logs \
      mbentley/omada-controller:5.15 &&\
    docker logs -f omada-controller
    ```

1. Stop & remove it

    ```bash
    docker stop -t 60 omada-controller &&\
      docker rm omada-controller
    ```

1. Start mongodb, attached to the same data from the all in one image (updating the dbpath)

    Note: this uses `mongo:3` because you otherwise have to perform an upgrade which is currently outside of the scope of this test.

    ```bash
    docker run -d \
      --name mongodb \
      --network omada \
      --stop-timeout 60 \
      -u 508:508 \
      -p 27017:27017 \
      --mount type=volume,source=omada-data,destination=/data/db \
      mongo:3 --dbpath /data/db/db
    ```

1. Start the controller

    ```bash
    docker run -d \
      --name omada-controller \
      --ulimit nofile=4096:8192 \
      --network omada \
      --stop-timeout 60 \
      -p 8088:8088 \
      -p 8043:8043 \
      -p 8843:8843 \
      -p 19810:19810/udp \
      -p 27001:27001/udp \
      -p 29810:29810/udp \
      -p 29811-29817:29811-29817 \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      --mount type=volume,source=omada-logs,destination=/opt/tplink/EAPController/logs \
      -e MONGO_EXTERNAL="true" \
      -e EAP_MONGOD_URI="mongodb://mongodb.omada:27017/omada" \
      mbentley/omada-controller:5.15 &&\
    docker logs -f omada-controller
    ```

1. Cleanup After Testing

    If you want to clean everything up, this command will kill the containers, remove the volumes, and remove the bridge network:

    ```bash
    docker rm -f mongodb omada-controller ;\
      docker volume prune -f ;\
      docker volume rm omada-data omada-logs ;\
      docker network rm omada
    ```

### Example using `--network host`

If you're using `--network host` and you want to use the existing data without having to start from scratch, you can just have MongoDB listen on `localhost`. By default, the MongoDB server created by the controller does not have credentials so at least listening on localhost is better than having it accessible on your network without auth. If you are concerned about this, take a backup, set up a fresh install as documented above and restore your data.

These instructions start from the point where you have an existing controller and it's stopped. In this example, it's using the v6 beta which is already using MongoDB 8.0.

1. Start MongoDB

    ```bash
    docker run -d \
      --name mongodb \
      --network host \
      -u 508:508 \
      --mount type=volume,source=omada-data,destination=/data/db \
      mongo:8 --dbpath /data/db/db --bind_ip 127.0.0.1
    ```

1. Start the controller

Note the connection string referring to `localhost`.

    ```bash
    docker run -d \
      --name omada-controller \
      --ulimit nofile=4096:8192 \
      --network host \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      --mount type=volume,source=omada-logs,destination=/opt/tplink/EAPController/logs \
      -e MONGO_EXTERNAL="true" \
      -e EAP_MONGOD_URI="mongodb://127.0.0.1:27017/omada" \
      mbentley/omada-controller:beta-6.0 &&\
    docker logs -f omada-controller
    ```

## Kubernetes Deployment Guide

In advanced setups, deploying applications in container orchestrators like Kubernetes is common,
even in homelabs to enhance reliability.

Below, we’ll use both Helm and Kustomize to deploy **MongoDB** and **Omada Controller**.

### Deploy MongoDB


We use a custom Helm chart that wraps Bitnami's MongoDB chart.

The customization includes templates for managing secrets securely, avoiding the bad practice of
hardcoding credentials in `values.yaml`.

Instead, it supports tools like **External Secrets** to fetch credentials from secure vaults and
generate Kubernetes secrets automatically.

The custom Helm chart has credentials hardcoded as an example, but provides commented examples
about how to get secrets safely from mentioned vaults.

Let's deploy our chart:

1. Update dependencies

```console
helm dependency update kubernetes/mongodb
```

2. Deploy MongoDB in the cluster currently pointed by your Kubeconfig

> [!IMPORTANT]
> Customize chart's parameters to meet your needs

```console
helm upgrade --install mongodb kubernetes/mongodb \
  -f kubernetes/mongodb/values-customized.yaml \
  -n omada-controller --create-namespace
```

### Deploy Omada Controller

We'll use Kustomize since there's no official Helm chart provided by Omada Controller's maintainers
or a trusted external provider like Bitnami.

Ensure your cluster has Ingress-Nginx as the ingress controller and Cert-Manager for certificate management.

If you're in an on-premises environment, you might need tools like MetalLB or Kube-VIP to provision
load balancers for services of type LoadBalancer.

To deploy Omada Controller, just execute the following command

```console
kubectl apply -k kubernetes/production
```

> [!IMPORTANT]
> Always adjust parameters to align with your infrastructure and requirements.
