# MongoDB Upgrade from 3.6 to 8.0

## About the Upgrade Process

This will upgrade MongoDB 3.6 to 8.0. Due to how MongoDB works, in order to upgrade, it must be done in steps which is why there is a special container image.

* The upgrade will take a backup of your persistent data before doing anything which can be used to restore your database in case of issues
* In any case of an error during the upgrade, the upgrade process will automatically roll back the upgrade.
  * If the upgrade does fail, roll back to a specific image tag with the previous version and consider doing the upgrade by taking a controller native backup, setting up a brand new controller, and restoring your backup.
  * If you need help, open a [Discussion in the Help category](https://github.com/mbentley/docker-omada-controller/discussions/categories/help) and the community will give you a hand, when they are able.

### Upgrade Steps

1. Stop your controller container
1. [Execute the Upgrade](#execute-the-upgrade) by running the upgrade container with the correct volume path to your persistent data
1. Start the v6 version of the controller container which has MongoDB 8.x

## Execute the Upgrade

**Note**: Most people should just use the images from Docker Hub and use the multi-arch tag which will automatically use the correct image for your architecture. If you build the images on your own, update the tag accordingly.

For the volume mount, either use the volume you use from your persistent `data` directory or bind mount the path to your data. This should be the exact same path that you use for your `data` directory of the controller.

`multi-arch`:

## Docker named volume

```bash
docker run -it --rm \
  -v omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-3.6-to-8
```

## Bind mount to the host

```bash
docker run -it --rm \
  -v /path/to/your/omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-3.6-to-8
```

<details>
<summary>Run commands for architecture specific image tags</summary>

`amd64`:

```bash
docker run -it --rm \
  -v omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-3.6-to-8-amd64
```

`arm64`:

```bash
docker run -it --rm \
  -v omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-3.6-to-8-arm64
```
</details>

## Build the Images (not required)

<details>
<summary>Build commands if you wish to build the images yourself</summary>

`amd64`:

```bash
docker build \
  --pull \
  --progress plain \
  -f Dockerfile.upgrade-amd64 \
  -t mbentley/omada-controller:mongodb-upgrade-3.6-to-8-amd64 \
  .
```

`arm64`:

```bash
docker build \
  --pull \
  --progress plain \
  -f Dockerfile.upgrade-arm64 \
  -t mbentley/omada-controller:mongodb-upgrade-3.6-to-8-arm64 \
  .
```
</details>

## HELP! My Controller Stopped Working!

If you're looking at this specific section, it's safe to assume that you found that your controller stopped working after trying to upgrade to v6. I realize that you may either be just trying to get things back up and running or you might want to proceed with the upgrade so see one of the below sections depending on what you want to do:

### Go Back to the Last v5

Update your container's definition which would be the `docker run...`, docker compose file, or whatever container management tool you use and specify a specific tag. See the [image tag list](../#image-tags) and find the correct image version tag for your version. In most cases, you can use `5`, or the `major.minor` (i.e. - `5.15`) tag of the version you were running previously.

### Perform the Upgrade

See the [details about the upgrade process at the top of this README](#about-the-upgrade-process)
