# MongoDB Upgrade from 3.6 to 8.0

**Warning**: this is a work in progress and is not meant to be ran against your actual controller in production today!

## TODO List

The TODO list can be found at the top of the [upgrade.sh](./upgrade.sh) script.

## Build the Images

Neither of these images are present on Docker Hub and must be built manually for now.

`amd64`:

```bash
docker build \
  --pull \
  --progress plain \
  -f Dockerfile.upgrade-amd64 \
  -t mbentley/omada-controller:mongodb-upgrade-amd64 \
  .
```

`arm64`:

```bash
docker build \
  --pull \
  --progress plain \
  -f Dockerfile.upgrade-arm64 \
  -t mbentley/omada-controller:mongodb-upgrade-arm64 \
  .
```

## Execute the Upgrade

Either use the volume you use from your persistent `data` directory or bind mount the path to your data. This should be the exact same path that you use for your `data` directory of the controller.

`amd64`:

```bash
docker run -it --rm \
  -v omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-amd64
```

`arm64`:

```bash
docker run -it --rm \
  -v omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-arm64
```
