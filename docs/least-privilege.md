# Display block: privilege approaches

The display block runs a Weston Wayland compositor. By default it runs with `privileged: true` and as `root`. This documents the ways to reduce that, and what has been tested.

Tested on: generic-amd64 (Intel HD Graphics 620 / KBL), balenaOS 6.9.2, Weston 14.0.2.

## Summary

| # | Approach | Privileged | Added caps | Compositor user | Status |
|---|----------|------------|-----------|-----------------|--------|
| 1 | Privileged (baseline) | yes | all | root | Works |
| 2 | Least-privileged, static devices | no | none | root | Tested — works |
| 3 | Dynamic hotplug | no | SYS_ADMIN, MKNOD, DAC_OVERRIDE | root | Not yet tested |
| 4 | Non-root compositor (seatd broker) | no | none | non-root | Not yet tested |

All non-privileged approaches also drop `network_mode: host` (not needed — D-Bus for stopping Plymouth comes from the bind-mounted host socket via `io.balena.features.dbus`, not TCP).

## 1. Privileged (baseline)

Original setup. `privileged: true`, runs Weston as root.

```yaml
display:
  privileged: true
  network_mode: host
  volumes: [ display-socket:/run ]
  environment: [ UDEV=true ]
  labels: { io.balena.features.dbus: '1' }
```

- Grants all capabilities, all host devices, unconfined seccomp/AppArmor.
- Simplest, but far more than the compositor needs.
- Examples: `glxgears`, `touchscreen-demo`.

## 2. Least-privileged, static devices

No `privileged`, no added capabilities. Bind-mount the specific devices instead.

```yaml
display:
  devices:
    - /dev/dri:/dev/dri
    - /dev/input:/dev/input
  volumes: [ display-socket:/run ]
  labels: { io.balena.features.dbus: '1' }
```

- Weston still runs as root (libseat's builtin backend opens devices itself and requires root).
- Use when GPU/input devices are present at container start and don't need udev rules.
- Example: `examples/least-privileged`.

Status: **Tested, works.** `docker inspect` confirmed `Privileged: false`, `CapAdd: []`. Weston reached `using /dev/dri/card0` and the Intel GL renderer; glxgears rendered.

## 3. Dynamic hotplug

For devices plugged in *after* the container starts (USB touchscreen, mouse, keyboard). Enables udev inside the container, which needs a scoped capability set instead of full privileged.

```yaml
display:
  cap_drop: [ ALL ]
  cap_add:
    - SYS_ADMIN     # mount devtmpfs + udevd network namespace
    - MKNOD         # udev creates device nodes
    - DAC_OVERRIDE  # udev sets node ownership/permissions
  environment: [ UDEV=true ]
  volumes: [ display-socket:/run ]
  labels: { io.balena.features.dbus: '1' }
```

- Weston runs as root.
- Example: `examples/dynamic-hotplug`.

Status: **Not yet tested.** Capability set is derived from reading the udev/devtmpfs logic in `entry.sh`, not confirmed on hardware.

## 4. Non-root compositor (seatd broker)

Runs Weston as an unprivileged user. libseat's builtin backend needs root, so device-opening is moved into a separate root `seatd` broker sidecar that passes device fds to Weston over `/run/seatd.sock`.

```yaml
seatd:                     # root, but isolated and non-privileged
  devices: [ /dev/dri:/dev/dri, /dev/input:/dev/input ]
  volumes: [ display-socket:/run ]
  labels: { io.balena.features.dbus: '1' }

display:                   # Weston as unprivileged user
  devices: [ /dev/dri:/dev/dri ]   # render node for GL
  volumes: [ display-socket:/run ]
  environment:
    - COMPOSITOR_USER=weston
    - LIBSEAT_BACKEND=seatd
    - XDG_RUNTIME_DIR=/run/user/1000
```

- The seatd sidecar stops Plymouth and opens `/dev/dri` + `/dev/input`.
- Weston opens the GPU render node directly, so the `weston` user is added to the host render GID at runtime.
- Only the seatd sidecar runs a root process; the compositor is unprivileged.
- Example: `examples/least-privileged-nonroot-compositor`.

Status: **Not yet tested.** Main unknown: DRM-master fd passing from the seatd container to the Weston container across containers.

## Findings

- **DRM master needs no capability.** The kernel grants master implicitly to the first process to open the primary node (`/dev/dri/card0`) once Plymouth releases it. `CAP_SYS_ADMIN` was tried and bisected out — not needed.
- **The real blocker was the seat, not privilege.** Weston 14 uses libseat's embedded seatd, which defaults to a VT-bound seat. A container has no VT (`/dev/tty0`), so the seat never activates and seatd denies DRM access ("no drm device found"). Fix: run seatd non-VT-bound (`SEATD_VTBOUND=0`, set by default in `entry.sh`).
- **balena grants device-cgroup access for directory device mounts.** `devices: /dev/dri:/dev/dri` shows `CgroupPermissions: rwm` in `docker inspect`, so nodes inside are openable. `device_cgroup_rules` is not supported by balena and is not needed.
- **Render vs primary node.** A Wayland *client* only needs the render node (`renderD128`), which is openable without privilege. The *compositor* needs the primary node (`card0`) + DRM master — that is the part the builtin backend needed root for.
- **udev is only for hotplug.** Devices present at start don't need it. It's gated behind `UDEV` (default off) in `entry.sh`.

## Hardware video decode

Hardware-accelerated video decode (GStreamer, FFmpeg, browser) is a **client** concern, not the display block. The compositor does not decode — the client decodes into a GPU buffer and hands it over as a dmabuf via Wayland; the compositor only composites it. The display block's device list is unchanged regardless of video decode.

Decode device access, all on the **client**:

- **VAAPI** (Intel/AMD, Chromium VAAPI): uses the render node `/dev/dri/renderD128` — already covered by the client's existing `/dev/dri` mount.
- **V4L2 m2m codecs** (Raspberry Pi and most ARM SoCs; GStreamer `v4l2*dec`, FFmpeg V4L2 m2m): use `/dev/video*` nodes, which are **not** mounted by default. Add them to the client service:

```yaml
yourapp:
  devices:
    - /dev/dri:/dev/dri
    - /dev/video10:/dev/video10   # RPi codec nodes are platform-specific
    - /dev/video11:/dev/video11
    - /dev/video12:/dev/video12
```

If the client is run non-root it needs the host group for the node it opens (`render` for `renderD128`, `video` for `/dev/video*`).
