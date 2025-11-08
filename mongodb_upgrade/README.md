# MongoDB Upgrade from 3.6 to 8.0

**Warning**: MongoDB versions 5 and above require specific CPU features/capabilities: AVX for amd64 CPUs and armv8.2-a for arm64 CPUs. The upgrade script will check for compatibility. For more information about your options to still be able to upgrade to v6, see the [known issues](../KNOWN_ISSUES.md#your-system-does-not-support-avx-or-armv82-a). Also for Proxmox users, you may need to explictly expose the AVX instruction set. Check out the [known issues](../KNOWN_ISSUES.md#your-system-does-not-support-avx-or-armv82-a) for instructions.

## About the Upgrade Process

This will upgrade MongoDB 3.6 to 8.0. Due to how MongoDB works, in order to upgrade, it must be done in steps which is why there is a special container image.

* The upgrade will take a backup of your persistent data before doing anything which can be used to restore your database in case of issues
* In any case of an error during the upgrade, the upgrade process will automatically roll back the upgrade.
  * If the upgrade does fail, roll back to a specific image tag with the previous version and consider doing the upgrade by taking a controller native backup, setting up a brand new controller, and restoring your backup.
  * If you need help, open a [Discussion in the Help category](https://github.com/mbentley/docker-omada-controller/discussions/categories/help) and the community will give you a hand, when they are able.

### Upgrade Steps

1. Stop your controller container
1. [Create a backup of your controler data](../README.md#controller-backups)
1. [Execute the Upgrade](#execute-the-upgrade) by running the upgrade container with the correct volume path to your persistent data
1. Start the v6 version of the controller container which has MongoDB 8.x

## Execute the Upgrade

**Note**: Most people should just use the images from Docker Hub and use the multi-arch tag which will automatically use the correct image for your architecture. If you build the images on your own, update the tag accordingly.

If the upgrade fails, you can re-run the upgrade, adding the environment variable `DEBUG=true` so that you get additional information from the upgrade script to provide in a help discussion.

For the volume mount, either use the volume you use from your persistent `data` directory or bind mount the path to your data. This should be the exact same path that you use for your `data` directory of the controller.

`multi-arch`:

### Docker named volume

If you run `docker compose` and you are not sure of what the name of the volume is for your persistent data, you can check by using `docker compose volumes` as compose typically will add a project name prefix to the name. If your compose file is not the default, use the syntax `docker compose -f <file-name>.yml volumes`. Replace `omada-data` with the name of your persistent data volume in the command below.

```bash
docker run -it --rm \
  -e DEBUG=false \
  -v omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-3.6-to-8
```

### Bind mount to the host

```bash
docker run -it --rm \
  -e DEBUG=false \
  -v /path/to/your/omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-3.6-to-8
```

<details>
<summary>Run commands for architecture specific image tags</summary>

`amd64`:

```bash
docker run -it --rm \
  -e DEBUG=false \
  -v omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-3.6-to-8-amd64
```

`arm64`:

```bash
docker run -it --rm \
  -e DEBUG=false \
  -v omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:mongodb-upgrade-3.6-to-8-arm64
```
</details>

Now that the migration is complete, you can update your tag to reflect the `6.0` image tag. Also make sure that you have updated your deployment to also expose port `tcp/29817` as that was added in v6.

### Kubernetes

1. Set the namespace variable to allow for copy and paste (optional):

    ```
    export OMADA_NS="omada-controller"
    ```

1. Scale down the controller:

    ```
    kubectl -n "${OMADA_NS}" scale deployment omada-controller --replicas=0
    ```

1. Temporarily allow privileged pods; update the namespace required (if required):

    ```
    # Store original values
    ORIGINAL_ENFORCE=$(kubectl get namespace "${OMADA_NS}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
    ORIGINAL_AUDIT=$(kubectl get namespace "${OMADA_NS}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null || echo "")
    ORIGINAL_WARN=$(kubectl get namespace "${OMADA_NS}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null || echo "")

    # Set the omada-controller namespace to privileged (temporarily)
    kubectl label namespace "${OMADA_NS}" pod-security.kubernetes.io/enforce=privileged --overwrite
    kubectl label namespace "${OMADA_NS}" pod-security.kubernetes.io/audit=privileged --overwrite
    kubectl label namespace "${OMADA_NS}" pod-security.kubernetes.io/warn=privileged --overwrite
    ```

1. Verify the deployment is stopped:

    ```
    kubectl -n "${OMADA_NS}" get pods -l app=omada-controller
    ```

1. Apply the migration job:

    ```
    kubectl -n "${OMADA_NS}" apply -f https://raw.githubusercontent.com/mbentley/docker-omada-controller/refs/heads/master/mongodb_upgrade/k8s_upgrade/upgrade_job.yaml
    ```

1. Monitor the migration progress:

    ```
    # Watch the job status
    kubectl -n "${OMADA_NS}" get job omada-mongodb-migration -w

    # Follow the migration logs
    kubectl -n "${OMADA_NS}" logs -f job/omada-mongodb-migration
    ```

1. Verify migration completion:

    ```
    # Check if job completed successfully
    kubectl -n "${OMADA_NS}" get job omada-mongodb-migration

    # Review final logs
    kubectl -n "${OMADA_NS}" logs job/omada-mongodb-migration
    ```

1. Remove the namespace security labels (if required):

    ```
    # Restore or remove labels based on original values
    [ -n "${ORIGINAL_ENFORCE}" ] && kubectl label namespace "${OMADA_NS}" pod-security.kubernetes.io/enforce="${ORIGINAL_ENFORCE}" --overwrite || kubectl label namespace "${OMADA_NS}" pod-security.kubernetes.io/enforce- 2>/dev/null || true
    [ -n "${ORIGINAL_AUDIT}" ] && kubectl label namespace "${OMADA_NS}" pod-security.kubernetes.io/audit="${ORIGINAL_AUDIT}" --overwrite || kubectl label namespace "${OMADA_NS}" pod-security.kubernetes.io/audit- 2>/dev/null || true
    [ -n "${ORIGINAL_WARN}" ] && kubectl label namespace "${OMADA_NS}" pod-security.kubernetes.io/warn="${ORIGINAL_WARN}" --overwrite || kubectl label namespace "${OMADA_NS}" pod-security.kubernetes.io/warn- 2>/dev/null || true
    ```


1. Update and apply your k8s deployment manifest with the new v6 image and then manually scale the deployment back up (if required):

    ```
    kubectl -n "${OMADA_NS}" scale deployment omada-controller --replicas=1
    ```

1. Job clean up (optional):

    ```
    # job will automatically be removed after 24 hours but you can clean it up manually
    kubectl -n "${OMADA_NS}" delete job omada-mongodb-migration
    ```

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
