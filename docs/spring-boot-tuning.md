# Spring Boot Tuning

The Omada Controller (v5.x and above) is built on [Spring Boot](https://spring.io/projects/spring-boot).
Its classpath includes `/opt/tplink/EAPController/properties`, which means Spring Boot will automatically
load an `application.properties` file placed there at startup.

The `APPLICATION_PROPERTIES` environment variable allows you to inject arbitrary Spring Boot properties
into the controller without rebuilding the image or overriding the `CMD`.

> **Disclaimer**: This is an unofficial tuning mechanism. TP-Link does not document or guarantee which
> Spring Boot properties are honoured. Settings listed here are best-effort based on the Spring Boot
> defaults for an embedded Tomcat server. Test in a non-production environment first.

---

## How to Use

Set `APPLICATION_PROPERTIES` to a newline-separated list of `key=value` pairs. The entrypoint writes
them verbatim to `/opt/tplink/EAPController/properties/application.properties` before the JVM starts.

### Docker Compose

```yaml
services:
  omada-controller:
    image: mbentley/omada-controller:6.2
    environment:
      APPLICATION_PROPERTIES: |
        server.tomcat.threads.max=50
        server.tomcat.threads.min-spare=5
        spring.task.execution.pool.max-size=10
```

### Docker CLI

```bash
docker run \
  -e APPLICATION_PROPERTIES=$'server.tomcat.threads.max=50\nserver.tomcat.threads.min-spare=5' \
  mbentley/omada-controller:6.2
```

### Kubernetes / Helm (extraEnvVars)

```yaml
extraEnvVars:
  APPLICATION_PROPERTIES: |
    server.tomcat.threads.max=50
    server.tomcat.threads.min-spare=5
    spring.task.execution.pool.core-size=5
    spring.task.execution.pool.max-size=10
    spring.task.scheduling.pool.size=3
```

The startup log will confirm the file was written:

```
INFO: APPLICATION_PROPERTIES set; writing Spring Boot properties to /opt/tplink/EAPController/properties/application.properties
```

---

## Available Settings

### Tomcat HTTP Thread Pool

Controls how many threads Tomcat uses to handle incoming HTTP/HTTPS requests.
The Omada web UI and API run through this pool.

| Property | Default | Description |
|---|---|---|
| `server.tomcat.threads.max` | `200` | Maximum number of worker threads. Reduce to limit memory usage. |
| `server.tomcat.threads.min-spare` | `10` | Minimum number of threads kept alive (idle). |
| `server.tomcat.accept-count` | `100` | Queue size for incoming connections when all threads are busy. |
| `server.tomcat.connection-timeout` | `20000` | Timeout (ms) for accepting a connection. |

**Typical constrained setup:**
```properties
server.tomcat.threads.max=50
server.tomcat.threads.min-spare=5
server.tomcat.accept-count=50
```

---

### Async Task Executor

Used for background tasks dispatched via Spring's `@Async` annotation — e.g. device
status polling, event processing.

| Property | Default | Description |
|---|---|---|
| `spring.task.execution.pool.core-size` | `8` | Threads always kept alive in the pool. |
| `spring.task.execution.pool.max-size` | `Integer.MAX_VALUE` | Maximum pool size. Set this explicitly. |
| `spring.task.execution.pool.queue-capacity` | `Integer.MAX_VALUE` | Task queue depth before new threads are spawned. |
| `spring.task.execution.pool.keep-alive` | `60s` | How long idle threads above core-size are kept. |
| `spring.task.execution.thread-name-prefix` | `task-` | Thread name prefix (useful for profiling). |

**Typical constrained setup:**
```properties
spring.task.execution.pool.core-size=5
spring.task.execution.pool.max-size=20
spring.task.execution.pool.queue-capacity=100
```

---

### Scheduled Task Pool

Controls the thread pool for `@Scheduled` tasks — periodic jobs like cleanup,
health checks, and device discovery heartbeats.

| Property | Default | Description |
|---|---|---|
| `spring.task.scheduling.pool.size` | `1` | Number of scheduling threads. Rarely needs to exceed 3. |
| `spring.task.scheduling.thread-name-prefix` | `scheduling-` | Thread name prefix. |

**Typical setup:**
```properties
spring.task.scheduling.pool.size=2
```

---

### Logging

Reducing log verbosity saves CPU and I/O, especially on slow storage (e.g. NFS-backed PVCs).

| Property | Default | Description |
|---|---|---|
| `logging.level.root` | `INFO` | Root log level. Set to `WARN` to reduce noise. |
| `logging.level.org.springframework` | `INFO` | Spring Framework log level. |
| `logging.level.org.mongodb` | `INFO` | MongoDB driver log level. |
| `logging.level.com.tplink` | `INFO` | Omada application log level. |

**Reduce verbosity:**
```properties
logging.level.root=WARN
logging.level.com.tplink=INFO
```

---

## Example: Memory-Constrained Setup (Kubernetes, ≤ 2 GB pod limit)

This example targets a pod with `limits.memory: 2048Mi` running OpenJ9.
Combined with `JAVA_MAX_HEAP_SIZE=512m` and `MONGOD_EXTRA_ARGS=--wiredTigerCacheSizeGB 0.25`,
the approximate memory budget is:

| Component | Budget |
|---|---|
| Java heap (`-Xmx`) | 512 MB |
| Java metaspace + JIT code | ~150 MB |
| MongoDB WiredTiger cache | 256 MB |
| Tomcat threads × ~1 MB stack | ~50 MB |
| OS + JVM overhead | ~300 MB |
| **Total** | **~1.3 GB** |

```yaml
extraEnvVars:
  JAVA_MAX_HEAP_SIZE: "512m"
  JAVA_MIN_HEAP_SIZE: "128m"
  MONGOD_EXTRA_ARGS: "--wiredTigerCacheSizeGB 0.25"
  APPLICATION_PROPERTIES: |
    server.tomcat.threads.max=50
    server.tomcat.threads.min-spare=5
    server.tomcat.accept-count=50
    spring.task.execution.pool.core-size=5
    spring.task.execution.pool.max-size=20
    spring.task.execution.pool.queue-capacity=100
    spring.task.scheduling.pool.size=2
    logging.level.root=WARN
    logging.level.com.tplink=INFO
```

---

## Notes and Limitations

- **Version requirement**: `APPLICATION_PROPERTIES` only works with v5.x and above (Spring Boot base).
  On v4.x and below, the properties directory is not on the classpath and the file will be ignored.
- **File is regenerated on every start**: The file is written fresh from the env var each time the
  container starts, so changes to `APPLICATION_PROPERTIES` always take effect on the next restart.
- **No conflict with `omada.properties`**: Spring Boot reads `application.properties` for its own
  framework settings; Omada's application config lives in `omada.properties` (a different file).
- **Unknown properties are ignored**: Spring Boot will log a warning for unrecognised keys but will
  not fail to start.
- **Property precedence**: Environment variables set directly on the container (e.g.
  `SERVER_TOMCAT_THREADS_MAX=50`) have higher precedence than `application.properties` in the Spring
  Boot relaxed-binding hierarchy. Both approaches work; `APPLICATION_PROPERTIES` is more explicit and
  easier to manage as a block.
