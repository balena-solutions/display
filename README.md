# display

A reusable [balena block][block-ref-url] that provides a hardware-accelerated Weston Wayland compositor, enabling any containerised app to render graphics on embedded Linux devices.


## Supported Devices
- Raspberry Pi 4
- Raspberry Pi 5
- Generic x86_64 (GPT)

Pre-built images are published to the balena registry for each supported architecture:

| Image | Architecture | Devices |
|---|---|---|
| `bh.cr/balena_solutions/display-aarch64` | ARM 64-bit (`aarch64`) | Raspberry Pi 4, Raspberry Pi 5 |
| `bh.cr/balena_solutions/display-amd64` | x86-64 (`amd64`) | Generic x86_64 (GPT) |


## How to Use This Block

### Option 1 — Direct image in `docker-compose.yml`

Reference the architecture-specific image directly. Best when your fleet targets a single known architecture (e.g. `aarch64` for Raspberry Pi 4/5):

**`docker-compose.yml`**
```yaml
version: '2.1'

services:
  display:
    image: bh.cr/balena_solutions/display-aarch64
    privileged: true
    restart: always
    network_mode: host
    volumes:
      - display-socket:/run
    environment:
      - UDEV=true
    labels:
      io.balena.features.dbus: '1'

  your-app:
    build: ./your-app
    restart: always
    depends_on:
      - display
    volumes:
      - display-socket:/run
    devices:
      - /dev/dri:/dev/dri
    environment:
      - WAYLAND_DISPLAY=wayland-0
      - XDG_RUNTIME_DIR=/run/user/0

volumes:
  display-socket:
```

### Option 2 — `Dockerfile.template` (multi-arch)

Use a `Dockerfile.template` so balena substitutes the correct architecture at build time. Best for when you deploy your app to fleets of different architectures (e.g `aarch64` and `amd64`):

**`./display/Dockerfile.template`**
```dockerfile
FROM bh.cr/balena_solutions/display-%%BALENA_ARCH%%
```

**`docker-compose.yml`**
```yaml
version: '2.1'

services:
  display:
    build: ./display
    privileged: true
    restart: always
    network_mode: host
    volumes:
      - display-socket:/run
    environment:
      - UDEV=true
    labels:
      io.balena.features.dbus: '1'

  your-app:
    build: ./your-app
    restart: always
    depends_on:
      - display
    volumes:
      - display-socket:/run
    devices:
      - /dev/dri:/dev/dri
    environment:
      - WAYLAND_DISPLAY=wayland-0
      - XDG_RUNTIME_DIR=/run/user/0

volumes:
  display-socket:
```

In your app's entry script, wait for the socket before launching:
```bash
SOCKET="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
while [ ! -e "$SOCKET" ]; do sleep 1; done
exec your-app
```
## Configuration

You can configure Weston sections and keys using the following environment variables: 
| Variable                        | Options                               | Default       | Description                                                                                                            |
|---------------------------------|---------------------------------------|---------------|------------------------------------------------------------------------------------------------------------------------|
| `XDG_RUNTIME_DIR`               | valid directory path                  | `/run/user/0` | Directory where the Wayland socket is created.                                                                         |
| `SOCKET_NAME`                   | [String] (e.g., `wayland-0`, `wayland-1`) | `wayland-0`   | Name of the Wayland socket                                                                                             |
| `WESTON_DEBUG`                  | true, false                           | `false`       | Enable debug mode                                                                                                      |
| `WESTON_INI_PATH` |   Absolute path to a custom `weston.ini` file | - | When this variable is set and the file is present, Weston will be launched directly using the provided file. Consequently any other `DISPLAY_*` environment variables defined for the container will be ignored. |
| `DISPLAY_UX_MODE`           | `desktop`, `kiosk`       | `kiosk`         | Sets the user interface mode. Use `kiosk` for a single full-screen application(ideal for embedded use cases), or `desktop` for a multi-window environment. |
| `DISPLAY_IDLE_TIMEOUT`       | [Integer] (seconds)                   |             `0` | Time in seconds before the display enters an inactive mode and blanks the screen. 0 disables the idle timeout.  *Note: Only applicable when `DISPLAY_UX_MODE=desktop`.*  |
| `DISPLAY_REQUIRE_INPUT`   | `true`, `false`                           |     `false`     | Dictates whether an active input device is required to launch. false permits display-only deployments.             |
| `DISPLAY_ALLOW_LOCKING`        | `true`, `false`                           |     `false`     | Enables or disables screen locking functionality.                                             |
| `DISPLAY_PANEL_POSITION` | `top`, `bottom`, `left`, `right`, `none`        | `none `         | Sets the location of the desktop panel. none disables the panel entirely, ensuring an unobstructed viewport.           |
| `UDEV`                       | `true`, `false`                           |     `false`     | Enables udev inside the container to dynamically detect devices (e.g. touchscreens, mice, keyboards) plugged in after startup. Requires the container to run with `privileged: true` or the capabilities listed under [Least-Privilege Deployment](#least-privilege-deployment). Devices already connected at boot can instead be bind-mounted directly and don't need this. |

## Advanced Configuration

If the configurations provided does not suit your use case such as complex output management—such as requiring complex output management, multiple independent displays, or custom launchers—you must provide a custom `weston.ini` via a Dockerfile override.  

The following snippets demonstrate how to override the configuration by inheriting from the base image and copying a custom `weston.ini`. You must also configure `WESTON_INI_PATH` to the absolute path of your `weston.ini` file for it to take effect.

**`./display/Dockerfile.template`**
```dockerfile
FROM bh.cr/balena_solutions/display-%%BALENA_ARCH%%

# Inject your custom Weston configuration
COPY weston.ini /etc/weston/weston.ini
```

## Examples

### GLXGears (`examples/glxgears`)
Renders a hardware-accelerated OpenGL ES spinning gears demo using `eglgears_wayland` from Mesa utils. Demonstrates EGL/OpenGL rendering over Wayland with a live FPS/CPU overlay via `GALLIUM_HUD`.

### Touchscreen Demo (`examples/touchscreen-demo`)
Runs the GTK4 demo suite over Wayland, demonstrating interactive touch input. The specific demo can be configured via the `DEMO` environment variable (default: `drawingarea`).

### Least Privilege (`examples/least-privileged`)
The glxgears demo deployed without `privileged: true`, host networking, or udev — `/dev/dri` and `/dev/input` are bind-mounted directly instead. See [Least-Privilege Deployment](#least-privilege-deployment) below.

### Dynamic Hotplug (`examples/dynamic-hotplug`)
The glxgears demo with `UDEV=true` enabled, for deployments that need to detect input devices plugged in after the container starts, using a scoped `cap_add` instead of full `privileged: true`.

## Architecture

This project uses a **block pattern**: a single `display` container runs the Weston compositor and exposes a Wayland socket via a shared Docker volume. Any number of client containers can connect to it.

### **Display Block** (Wayland Compositor)
- Runs the Weston compositor, managing graphics hardware directly via DRM
- Creates a Wayland socket at `/run/user/0/wayland-0` for client connections
- Handles GPU rendering through the DRM backend
- Releases the Plymouth DRM lock on startup to ensure exclusive GPU access

### **Your App** (Wayland Client)
- Any Wayland-compatible application (GTK4, Qt, LVGL, OpenGL, etc.)
- Connects to the display block via the shared Wayland socket
- Renders UI through the Wayland protocol (hardware-accelerated)
- Polls for the socket before attempting connection

### Communication
Both containers share a Docker volume (`display-socket`) mounted at `/run`, making the Weston socket accessible to client containers.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                      Docker Compose                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐      ┌────────────────────────┐   │
│  │   display (block)    │      │   your-app (client)    │   │
│  ├──────────────────────┤      ├────────────────────────┤   │
│  │ Weston Compositor    │      │ Wayland Client         │   │
│  │ DRM Backend (GPU)    │◄─────┤ (GTK4 / Qt / LVGL /    │   │
│  │                      │      │  OpenGL / anything)    │   │
│  │ /usr/bin/entry.sh    │      │                        │   │
│  └──────────┬───────────┘      └───────────┬────────────┘   │
│             │                              │                │
│             └──────────────────────────────┘                │
│                    Shared volume: /run                      │
│              (Wayland socket: wayland-0)                    │
└─────────────────────────────────────────────────────────────┘
```

## Hardware Acceleration

GPU acceleration is enabled through:

1. **DRM Backend** — Weston connects directly to the GPU via `/dev/dri`
2. **Mesa Graphics Libraries** — Provides OpenGL/Vulkan drivers

### Docker Privileges
The display container, as shown in the examples above, requires:
- `privileged: true` — DRM master access and dynamic device detection via udev
- `/dev/dri` — GPU device access
- `io.balena.features.dbus: '1'` — D-Bus access (for stopping Plymouth)

This is the simplest setup, but grants far more than Weston actually needs. See [Least-Privilege Deployment](#least-privilege-deployment) below for a scoped-down alternative.

## Least-Privilege Deployment

`privileged: true` grants every Linux capability and access to every host device — Weston only needs GPU (and optionally input) device access, and, if you want dynamic hotplug detection, a small set of capabilities for udev. Acquiring DRM master doesn't itself require any capability: the kernel grants it implicitly to the first process that opens the primary DRM node once Plymouth releases it (which is what the `io.balena.features.dbus` D-Bus call does).

There are two scoped-down patterns, depending on whether you need to detect devices plugged in *after* the container starts:

**Static devices (no udev, no added capabilities)** — use this when your GPU and input devices (touchscreen, mouse, keyboard) are already connected at boot. Bind-mount them directly, the same way `/dev/dri` is already bind-mounted into client containers:

```yaml
services:
  display:
    build: ./display
    restart: always
    volumes:
      - display-socket:/run
    devices:
      - /dev/dri:/dev/dri
      - /dev/input:/dev/input
    labels:
      io.balena.features.dbus: '1'
```

No `privileged`, `cap_add`, or `network_mode: host` needed. Full example: [`examples/least-privileged`](examples/least-privileged).

**Dynamic hotplug (opt into udev)** — use this when you need to detect devices plugged in after the container starts (e.g. a hot-swappable USB touchscreen, mouse, or keyboard). Set `UDEV=true` and grant only the capabilities udev needs, instead of full `privileged: true`:

```yaml
services:
  display:
    build: ./display
    cap_drop:
      - ALL
    cap_add:
      - SYS_ADMIN     # mount devtmpfs + create the udevd network namespace
      - MKNOD         # udev creates device nodes as new devices are detected
      - DAC_OVERRIDE  # udev sets ownership/permissions on newly created device nodes
    restart: always
    volumes:
      - display-socket:/run
    environment:
      - UDEV=true
    labels:
      io.balena.features.dbus: '1'
```

Full example: [`examples/dynamic-hotplug`](examples/dynamic-hotplug).

In both cases `network_mode: host` is unnecessary — the Plymouth D-Bus call uses the host socket bind-mounted in by the `io.balena.features.dbus` label, not host networking.

## Debugging

**Common issues:**
- `wayland-0 socket not found` → Weston failed to start; check display logs
- `failed to load drm driver` → GPU drivers not installed or hardware not supported
- `[WARN] D-Bus socket not found` → Missing `io.balena.features.dbus: '1'` label on display service; Plymouth may still hold the DRM lock


[block-ref-url]:https://docs.balena.io/learn/develop/blocks/#getting-started-with-blocks
[weston-ini-ref-url]:https://manpages.debian.org/trixie/weston/weston.ini.5.en.html