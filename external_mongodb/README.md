# Notes for External MongoDB

* [Common Steps](#common-steps)
* [MongoDB + Omada Controller (fresh install)](#mongodb--omada-controller-fresh-install)
* [Migration from All in One](#migration-from-all-in-one)
  * [Example using a bridge network](#example-using-a-bridge-network)
    * [Fresh Install Example using Compose](#fresh-install-example-using-compose)
  * [Example using `--network host`](#example-using---network-host)
    * [Migration Examples using Compose](#migration-examples-using-compose)
* [Kubernetes Deployment Guide](#kubernetes-deployment-guide)

## Common Steps

You can optionally build a Docker image without MongoDB using the `NO_MONGODB=true` build arg but it's not necessary to run MongoDB as an external container as it will simply not start if you pass the `MONGO_EXTERNAL` environment variable at runtime.

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

    > [!NOTE]
    > If you're using host or macvlan networking, you obviously do not need to create a bridge but you should take care to make MongoDB listen on localhost so it's not wide open to your network.

## MongoDB + Omada Controller (fresh install)

This expects that you are in this project's root where the `Dockerfile` is.  Update the path for the MongoDB `/docker-entrypoint-initdb.d` bind mount if you want/need to but these commands should all work from there.

1. Start MongoDB

    * As of late 2025, TP-Links supports MongoDB 3-8 for the controller. Update the MongoDB image version tag as you wish.
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

### Fresh Install Example using Compose

There is an example compose file for a fresh install using an external MongoDB at [docker-compose_fresh-install-host.yml](./docker-compose_fresh-install-host.yml) and [docker-compose_fresh-install-bridge.yml](./docker-compose_fresh-install-bridge.yml) for host and bridge networking, respectively.

## Migration from All in One

While I have these steps for a migration, it _may_ be easier for you to take a backup from the Omada Controller and then do a restore of the config to a new controller install with an external MongoDB but this should be a quick process.

In this example, we will:

* Stop the existing all in one controller running v5
* Start an external MongoDB v3, attached to the existing persistent data
* Start a new v5 controller, instructing it how to connect to the external MongoDB

Upgrading MongoDB from v3 to v4 is currently out of scope of these steps. To minimize the moving pieces, you should **NOT** attempt to upgrade from v5 to v6 during this process. Once you move to an external v5, you can upgrade your controller to v6 as staying on v5 will give you a much easier rollback in case of issues moving to an external MongoDB.

Here is an example of how one would have ran a standard all in one container (mongodb + controller). **YOU DO NOT NEED TO RUN THIS** - this is just the example to show how we would change the run options to move to the separate containers.

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
  mbentley/omada-controller:5.15
```

### Example using a bridge network

1. [Take a backup!](../#controller-backups)

1. Stop & remove your existing container

    ```bash
    docker stop -t 60 omada-controller &&\
      docker rm omada-controller
    ```

1. Start mongodb, attached to the same data from the all in one image, making the required updates to match your configuration:

    * Update the volume path to match your own volume or your bind mounted location
    * Update the UID/GID to match what you run your controller as - this example uses the defaults
    * Take note of the overridden CMD - we need to set the path to where the existing persistent data lives

    > [!NOTE]
    > This uses `mongo:3` because you otherwise have to perform an upgrade which is currently outside of the scope of this guide.

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

1. Start the new controller

    * You will need to add the `MONGO_EXTERNAL=true` and `EAP_MONGOD_URI` environment variables.
    * Your `EAP_MONGOD_URI` value should refer to MongoDB container by `mongodb` as the controller should be able to communicate to the MongoDB over the bridge network.

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
      -e EAP_MONGOD_URI="mongodb://mongodb:27017/omada" \
      mbentley/omada-controller:5.15 &&\
    docker logs -f omada-controller
    ```

You should now have a working controller - check the logs and watch for proper startup and a message stating that your controller has started.

### Example using `--network host`

If you're using `--network host` and you want to use the existing data without having to start from scratch, you can just have MongoDB listen on `localhost`. By default, the MongoDB server created by the controller does not have credentials so at least listening on localhost is better than having it accessible on your network without auth. If you are concerned about this, take a backup, set up a fresh install as documented above and restore your data.

These instructions start from the point where you have an existing controller and it's stopped. In this example, it's using the v6 beta which is already using MongoDB 8.0.

1. [Take a backup!](../#controller-backups)

1. Stop & remove your existing container

    ```bash
    docker stop -t 60 omada-controller &&\
      docker rm omada-controller
    ```

1. Start MongoDB

    * Update the volume path to match your own volume or your bind mounted location
    * Update the UID/GID to match what you run your controller as - this example uses the defaults
    * Take note of the overridden CMD - we need to set the path to where the existing persistent data lives and set the bind IP so we don't listen without authentication across your network

    ```bash
    docker run -d \
      --name mongodb \
      --network host \
      -u 508:508 \
      --mount type=volume,source=omada-data,destination=/data/db \
      mongo:8 --dbpath /data/db/db --bind_ip 127.0.0.1
    ```

1. Start the controller

    * You will need to add the `MONGO_EXTERNAL=true` and `EAP_MONGOD_URI` environment variables.
    * Your `EAP_MONGOD_URI` value should refer to MongoDB container by `localhost`.

    ```bash
    docker run -d \
      --name omada-controller \
      --ulimit nofile=4096:8192 \
      --network host \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      --mount type=volume,source=omada-logs,destination=/opt/tplink/EAPController/logs \
      -e MONGO_EXTERNAL="true" \
      -e EAP_MONGOD_URI="mongodb://127.0.0.1:27017/omada" \
      mbentley/omada-controller:5.15 &&\
    docker logs -f omada-controller
    ```

You should now have a working controller - check the logs and watch for proper startup and a message stating that your controller has started.

### Migration Examples using Compose

There are example compose files for migrations to an external MongoDB at [docker-compose_migration-host.yml](./docker-compose_migration-host.yml) and [docker-compose_migration-bridge.yml](./docker-compose_migration-bridge.yml) for host and bridge networking, respectively.

## Kubernetes Deployment Guide

For mores details on how to deploy Omada Controller with an external MongoDB database see [Kubernetes Deployment Guide](../k8s/helm/README.md).
