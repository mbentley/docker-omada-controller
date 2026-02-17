# Omada Controller Helm Chart

Helm chart for deploying the TP-Link Omada SDN Controller on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure (for persistent storage)

## Chart Versions

The Helm chart releases do not correspond to the controller version so below is a guide to help you find the appropriate Chart version for the version of the controller you wish to run:

| Controller Version | Chart Version | Change Notes |
| ------------------ | ------------- | :------------ |
| `6.1.0.19`         | `1.1.5`       | Add `webConfigOverride` option to force re-read of port configuration |
| `6.1.0.19`         | `1.1.4`       | Improve secret handling and external MongoDB support |
| `6.1.0.19`         | `1.1.3`       | Adds the ability to configure an initcontainer |
| `6.1.0.19`         | `1.1.2`       | Fix #721; duplicate port in values.yaml |
| `6.1.0.19`         | `1.1.1`       | Auto set `MONGO_EXTERNAL=true` when MongoDBUrl is set |
| `6.1.0.19`         | `1.1.0`       | Updated to version 6.1.0.19 |
| `6.0.0.25`         | `1.0.2`       | Added env var for UPGRADE_HTTPS_PORT |
| `6.0.0.25`         | `1.0.1`       | Updated to version 6.0.0.25 |
| `6.0.0.24`         | `1.0.0`       | Initial version |

## Installation

### Install the chart from OCI registry

```bash
helm install omada-controller oci://registry-1.docker.io/mbentley/omada-controller-helm
```

### Install with custom values

```bash
helm install omada-controller oci://registry-1.docker.io/mbentley/omada-controller-helm -f custom-values.yaml
```

### Install a specific version

```bash
helm install omada-controller oci://registry-1.docker.io/mbentley/omada-controller-helm --version 1.0.0
```

## Uninstallation

```bash
helm uninstall omada-controller
```

## Configuration

The following table lists the configurable parameters of the Omada Controller chart and their default values.

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Omada Controller image repository | `mbentley/omada-controller` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `image.tag` | Image tag (defaults to chart appVersion if empty) | `""` |
| `imagePullSecrets` | Image pull secrets for private registries | `[]` |

### Service Account

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create a service account | `true` |
| `serviceAccount.automount` | Automount service account token | `true` |
| `serviceAccount.annotations` | Annotations for service account | `{}` |
| `serviceAccount.name` | Service account name (generated if empty) | `""` |

### Omada Controller Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.ports.manageHttp` | Management portal HTTP port | `8088` |
| `config.ports.manageHttps` | Management portal HTTPS port | `8043` |
| `config.ports.portalHttp` | Captive portal HTTP port | `8088` |
| `config.ports.portalHttps` | Captive portal HTTPS port | `8843` |
| `config.ports.upgradeHttps` | Dedicated HTTPS port for upgrades | `8043` |
| `config.ports.appDiscovery` | UDP port for Omada App discovery | `27001` |
| `config.ports.adoptV1` | Device adoption port (v1) | `29812` |
| `config.ports.upgradeV1` | Device upgrade port (v1) | `29813` |
| `config.ports.managerV1` | Device management port (v1) | `29811` |
| `config.ports.managerV2` | Device management port (v2) | `29814` |
| `config.ports.discovery` | UDP device discovery port | `29810` |
| `config.ports.udpManagement` | UDP device management port | `19810` |
| `config.ports.transferV2` | Device transfer port (v2) | `29815` |
| `config.ports.rtty` | RTTY connection port | `29816` |
| `config.ports.deviceMonitor` | Device monitoring port (Omada 6+) | `29817` |
| `config.webConfigOverride` | Force re-read of port configuration from properties on startup | `false` |
| `config.rootless` | Run controller in rootless mode | `true` |
| `config.showMongoDBLogs` | Display MongoDB logs (auto-disabled with external MongoDB) | `false` |
| `config.showServerLogs` | Display server logs in container output | `true` |
| `config.sslCertName` | SSL certificate filename | `tls.crt` |
| `config.sslKeyName` | SSL key filename | `tls.key` |
| `config.tlsSecretName` | Kubernetes TLS secret name to auto-mount | `""` |
| `config.tls1Enabled` | Re-enable TLS 1.0 & 1.1 | `false` |
| `config.timezone` | Controller timezone | `Etc/UTC` |
| `config.externalMongoDBUrl` | External MongoDB URL (mutually exclusive with secret) | `""` |
| `config.externalMongoDBUrlSecret.name` | Secret name containing MongoDB URI (mutually exclusive with URL) | `""` |
| `config.externalMongoDBUrlSecret.key` | Secret key containing MongoDB URI | `""` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `LoadBalancer` |
| `service.labels` | Additional service labels | `{}` |
| `service.annotations` | Additional service annotations | `{}` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress controller | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.managementHosts` | Hosts for management portal | `[]` |
| `ingress.portalHosts` | Hosts for captive portal | `[]` |
| `ingress.tls` | TLS configuration | `[]` |

### Persistence Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.data.enabled` | Enable data persistence | `true` |
| `persistence.data.storageClassName` | Storage class for data volume | `""` |
| `persistence.data.accessModes` | Access modes for data volume | `[ReadWriteOnce]` |
| `persistence.data.size` | Size of data volume | `1Gi` |
| `persistence.logs.enabled` | Enable logs persistence | `true` |
| `persistence.logs.storageClassName` | Storage class for logs volume | `""` |
| `persistence.logs.accessModes` | Access modes for logs volume | `[ReadWriteOnce]` |
| `persistence.logs.size` | Size of logs volume | `1Gi` |
| `persistence.extraVolumes` | Additional volumes to mount | `[]` |
| `persistence.extraVolumeMounts` | Additional volume mounts | `[]` |

### Resource Management

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | CPU/Memory resource requests/limits | `{}` |
| `nodeSelector` | Node selector for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Affinity rules for pod assignment | `{}` |

### Health Checks

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe` | Liveness probe configuration | `{}` |
| `readinessProbe` | Readiness probe configuration | See values.yaml |
| `startupProbe` | Startup probe configuration | See values.yaml |

### Additional Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podAnnotations` | Pod annotations | `{}` |
| `podLabels` | Pod labels | `{}` |
| `initContainers` | Init containers to add to the pod | `[]` |
| `extraEnvVars` | Additional environment variables | `{}` |
| `extraManifests` | Additional Kubernetes manifests | `[]` |

## Example Configurations

### Basic Installation with LoadBalancer

```yaml
service:
  type: LoadBalancer
  annotations:
    metallb.io/loadBalancerIPs: 192.168.1.20

persistence:
  data:
    size: 5Gi
  logs:
    size: 2Gi
```

### Installation with Ingress and TLS

```yaml
service:
  type: ClusterIP

ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  managementHosts:
    - host: omada.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: omada-tls-secret
      hosts:
        - omada.example.com
```

### Installation with External MongoDB

```yaml
config:
  externalMongoDBUrl: "mongodb://user:password@mongodb.example.com:27017/omada"

persistence:
  data:
    enabled: true # Data storage still required for backups and firmware with external MongoDB
    size: 2Gi
  logs:
    enabled: true
    size: 2Gi
```

### Installation with External MongoDB Using Secret

For better security, store the MongoDB URI in a Kubernetes secret:

```bash
# Create a secret with the MongoDB URI
kubectl create secret generic mongodb-uri \
  --from-literal=uri='mongodb://user:password@mongodb.example.com:27017/omada'
```

```yaml
config:
  externalMongoDBUrlSecret:
    name: mongodb-uri
    key: uri

persistence:
  data:
    enabled: true # Data storage still required for backups and firmware with external MongoDB
    size: 2Gi    
  logs:
    enabled: true
    size: 2Gi
```

> [!IMPORTANT]
> `externalMongoDBUrlSecret` and `externalMongoDBUrl` are mutually exclusive. Setting both will result in a validation error during deployment.

### Installation with Custom TLS Certificates

Using a Kubernetes TLS secret (e.g., from cert-manager):

```yaml
config:
  tlsSecretName: omada-tls-secret
```

Or with custom certificate/key filenames:

```yaml
config:
  tlsSecretName: omada-custom-tls
  sslCertName: custom.crt
  sslKeyName: custom.key
```

> [!NOTE]
> The secret must be of type `kubernetes.io/tls` or contain keys matching `sslCertName` and `sslKeyName`.

### Resource-Constrained Installation

```yaml
resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

persistence:
  data:
    size: 2Gi
  logs:
    size: 500Mi
```

## Port Requirements

The Omada Controller requires several ports to be accessible for proper operation:

- **8043/TCP** - HTTPS management portal (primary interface)
- **8088/TCP** - HTTP management portal
- **8843/TCP** - HTTPS captive portal
- **27001/UDP** - Omada app discovery
- **29810/UDP** - Device discovery
- **29811-29817/TCP** - Device management, adoption, and monitoring

When using a LoadBalancer service, ensure your load balancer supports both TCP and UDP protocols.

## Upgrading

### To a newer chart version

```bash
helm upgrade omada-controller oci://registry-1.docker.io/mbentley/omada-controller-helm --version 1.1.5
```

### Upgrading the Application Version

When upgrading to a new version of the Omada Controller application, update the `image.tag` value:

```bash
helm upgrade omada-controller oci://registry-1.docker.io/mbentley/omada-controller-helm \
  --set image.tag=6.0.0.25 \
  --reuse-values
```

## Troubleshooting

### Controller Takes Long Time to Start

The Omada Controller can take several minutes to start, especially on first run. The `startupProbe` is configured with a 5-minute timeout (30 failures × 10 seconds) to accommodate this.

### Device Discovery Not Working

Ensure UDP ports 27001, 29810, and 19810 are accessible from your network. If using a LoadBalancer, verify it supports UDP protocols.

### TLS/Certificate Issues

If using an Ingress controller, ensure your Ingress controller is configured to communicate with the backend using HTTPS. Example for nginx-ingress:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
```

### MongoDB Connection Issues

Check the logs for MongoDB connection errors. If using external MongoDB, verify the connection URL and credentials.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Support

See the [Getting Help & Reporting Issues](https://github.com/mbentley/docker-omada-controller?tab=readme-ov-file#getting-help--reporting-issues) section of the main README for details on how to get support.
