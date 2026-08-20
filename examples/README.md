# Examples

This folder contains example applications demonstrating how to use the display block.


| Example | Description |
|---------|-------------|
| [glxgears](./glxgears) | OpenGL/EGL hardware-accelerated demo using `eglgears_wayland` |
| [touchscreen-demo](./touchscreen-demo) | GTK4 demo suite over Wayland, demonstrating interactive touch input |
| [least-privileged](./least-privileged) | Same glxgears demo, but with `/dev/dri` and `/dev/input` bind-mounted directly instead of `privileged: true` — no added capabilities, no host networking, no udev |
| [dynamic-hotplug](./dynamic-hotplug) | Same glxgears demo, opting into `UDEV=true` for runtime input device detection with a scoped `cap_add` instead of full `privileged: true` |
| [least-privileged-nonroot-compositor](./least-privileged-nonroot-compositor) | Runs Weston as an unprivileged user by moving device access into a minimal root `seatd` broker sidecar; no privileged, no capabilities, no host networking |



