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

## Examples

### GLXGears (`examples/glxgears`)
Renders a hardware-accelerated OpenGL ES spinning gears demo using `eglgears_wayland` from Mesa utils. Demonstrates EGL/OpenGL rendering over Wayland with a live FPS/CPU overlay via `GALLIUM_HUD`.

### Touchscreen Demo (`examples/touchscreen-demo`)
Runs the GTK4 demo suite over Wayland, demonstrating interactive touch input. The specific demo can be configured via the `DEMO` environment variable (default: `drawingarea`).

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
The display container requires:
- `privileged: true` — DRM master access
- `/dev/dri` — GPU device access
- `io.balena.features.dbus: '1'` — D-Bus access (for stopping Plymouth)

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `XDG_RUNTIME_DIR` | `/run/user/0` | Directory where the Wayland socket is created |
| `SOCKET_NAME` | `wayland-0` | Name of the Wayland socket |
| `WESTON_DEBUG` | `false` | Enable debug mode and screenshooter support |

## Debugging

**Common issues:**
- `wayland-0 socket not found` → Weston failed to start; check display logs
- `failed to load drm driver` → GPU drivers not installed or hardware not supported
- `[WARN] D-Bus socket not found` → Missing `io.balena.features.dbus: '1'` label on display service; Plymouth may still hold the DRM lock


[block-ref-url]:https://docs.balena.io/learn/develop/blocks/#getting-started-with-blocks