# TODO: Multi-display support (deferred)

The display block currently configures a **single output** — the geometry env vars
(`DISPLAY_ROTATION`, `DISPLAY_RESOLUTION`, `DISPLAY_SCALE`) are applied to the **first connected
display detected**. This note records the exploration already done so we don't re-investigate from
scratch when we pick multi-head up.

## What we found

### Output/connector names are concrete and platform-specific

Weston's `[output]` section keys on the DRM connector name (`HDMI-A-1`, `HDMI-A-2`, `DP-1`, `eDP-1`,
`DSI-1`, `VGA-1`, …). These names:

- come from DRM/KMS and vary by GPU, driver and platform (a Pi's `DSI-1` vs an x86 box's `DP-1`);
- have **no platform-agnostic "display-1 / display-2" abstraction** at the compositor-config layer —
  Weston, wlroots/Sway, etc. all key on the concrete connector string.

The block detects connected connectors by reading `/sys/class/drm/card*-*/status` (see
`detect_connected_outputs()` in `entry.sh`), excluding virtual connectors like `Writeback-*`.

### Why not role-based targeting

We considered exposing role-based vars (`PRIMARY_*` / `SECONDARY_*`) that auto-resolve to detected
connectors. **Rejected as too non-deterministic**: the mapping of a "primary" role to a physical
port is not stable/predictable enough to be a reliable interface. When multi-head is implemented, the
user should target a **specific, concrete connector name** instead (e.g. `DISPLAY_ROTATION_HDMI_A_1`
or similar). To make that usable, the block should report detected connector names (it already logs
them on startup).

### The hard part: kiosk shell + single-client sidecar architecture

This is the main unknown to research before committing to a design:

- Weston's `kiosk-shell` is effectively **one fullscreen app per output**.
- A client block like `browser` is a **single Chromium instance = a single Wayland surface**, which
  the compositor places on one output.

So "drive two displays" is **not** just adding a second `[output]` section. It likely needs one or
more of: multiple client instances (e.g. two browser containers), explicit surface→output placement,
or a different shell. The interaction between the block pattern (one client container, one socket)
and multi-output kiosk needs to be designed deliberately.

## Prior art

A proof-of-concept exists at
`balena-solutions/display@rahul/dual-screen:examples/multiscreen`. It:

- auto-detects connected connectors from `/sys/class/drm/card*-*/status`, treats the first as primary
  (positioned at `0,0`) and the second to its right;
- exposes `PRIMARY_DISPLAY` / `SECONDARY_DISPLAY` (output names, auto-detected if unset),
  `PRIMARY_MODE` / `SECONDARY_MODE`, per-connector `ROTATION_<OUTPUT_NAME>`, and `MULTISCREEN_ENABLED`;
- notes that 90°/270° rotation requires setting the post-rotation `*_MODE` explicitly, because Weston
  positions using the post-rotation width.

## Available escape hatch today

Advanced users who need a multi-output layout now can supply a full custom `weston.ini` via
`WESTON_INI_PATH` (see "Advanced Configuration" in the README), which bypasses the block's dynamic
config generation entirely.

## Decision

Implement multi-display only if there is enough demand, rather than asking users to bring their own
`weston.ini`. Until then the block stays single-display by design.
