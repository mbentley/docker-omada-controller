# Notes for External MongoDB (Experimental)

Note: This is 100% experiemental. If you move to an external MongoDB, you're on your own in terms of getting help. These notes below are just my notes from when I was proving this out, not a production ready setup. They include standing up a new MongoDB + Controller and test steps for a migration from the all in one to separate containers. Again, you're on your own.

* [Common Steps](#common-steps)
* [MongoDB + Omada Controller (fresh install)](#mongodb--omada-controller-fresh-install)
* [Migration from All in One](#migration-from-all-in-one)

## Common Steps

These steps are needed for either scenario you want to test.

1. (Optional) Build the Docker Image

    As of 10/23/2023, a multi-arch test image is available on Docker Hub as `mbentley/omada-controller:5.12-external-mongo-test` for `amd64` and `arm64` but you can build it yourself:

    ```bash
    docker build \
      --pull \
      --build-arg INSTALL_VER="5.12" \
      --progress plain \
      -f Dockerfile.v5.x \
      -t mbentley/omada-controller:5.12-external-mongo-test .
    ```

1. Create a Docker `bridge` Network

    Creating and using a custom bridge network allows for container to container comunication:

    ```bash
    docker network create -d bridge omada
    ```

## MongoDB + Omada Controller (fresh install)

This expects that you are in this project's root where the `Dockerfile` is.  Update the path for the MongoDB `/docker-entrypoint-initdb.d` bind mount if you want/need to but these commands should all work from there.

1. Start MongoDB

    As far as I can tell, using MongoDB 7 works fine for the controller. I have yet to test it extensively though, just gone through basic setup. The [installation documentation](https://www.tp-link.com/us/support/faq/3272/) says that you should run MongoDB 3 or 4 though.

    The `omada` user in MongoDB will have the following credentials: user: `omada` & pwd: `0m4d4`.  This is defined in the `omada.js` file that it used to initialize the databases and you can modify if as you wish.

    ```bash
    docker run -d \
      --name mongodb \
      --network omada \
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
      -p 8088:8088 \
      -p 8043:8043 \
      -p 8843:8843 \
      -p 27001:27001/udp \
      -p 29810:29810/udp \
      -p 29811-29816:29811-29816 \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      --mount type=volume,source=omada-logs,destination=/opt/tplink/EAPController/logs \
      -e MONGO_EXTERNAL="true" \
      -e EAP_MONGOD_URI="mongodb://omada:0m4d4@mongodb.omada:27017/omada" \
      mbentley/omada-controller:5.12-external-mongo-test &&\
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

1. Run standard all in one container (mongodb + controller)

    ```bash
    docker run -d \
      --name omada-controller \
      --ulimit nofile=4096:8192 \
      --network omada \
      -p 8088:8088 \
      -p 8043:8043 \
      -p 8843:8843 \
      -p 27001:27001/udp \
      -p 29810:29810/udp \
      -p 29811-29816:29811-29816 \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      --mount type=volume,source=omada-logs,destination=/opt/tplink/EAPController/logs \
      mbentley/omada-controller:5.12-external-mongo-test &&\
    docker logs -f omada-controller
    ```

1. Stop & remove it

    ```bash
    docker stop -t 60 omada-controller &&\
      docker rm omada-controller
    ```

1. chown db files to prepare for the mongodb image

    ```bash
    docker run -it --rm \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      alpine chown -R 999:999 /opt/tplink/EAPController/data/db
    ```

1. Start mongodb, attached to the same data from the all in one image (updating the dbpath)

    Note: this uses `mongo:3` because you otherwise have to perform an upgrade which is currently outside of the scope of this test.

    ```bash
    docker run -d \
      --name mongodb \
      --network omada \
      -p 27017:27017 \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      mongo:3 --dbpath /opt/tplink/EAPController/data/db
    ```

1. Start the controller

    ```bash
    docker run -d \
      --name omada-controller \
      --ulimit nofile=4096:8192 \
      --network omada \
      -p 8088:8088 \
      -p 8043:8043 \
      -p 8843:8843 \
      -p 27001:27001/udp \
      -p 29810:29810/udp \
      -p 29811-29816:29811-29816 \
      --mount type=volume,source=omada-data,destination=/opt/tplink/EAPController/data \
      --mount type=volume,source=omada-logs,destination=/opt/tplink/EAPController/logs \
      -e MONGO_EXTERNAL="true" \
      -e EAP_MONGOD_URI="mongodb://mongodb.omada:27017/omada" \
      mbentley/omada-controller:5.12-external-mongo-test &&\
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
