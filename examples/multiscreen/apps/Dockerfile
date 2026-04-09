FROM debian:13.2-slim

ENV DEBIAN_FRONTEND=noninteractive

# Weston ships lightweight demo clients that work as pure Wayland apps 
#
# Available via APP1 / APP2 env vars:
#   weston-simple-egl  — hardware-accelerated EGL spinning shape (default APP1)
#   weston-simple-shm  — animated colored rectangle, CPU-rendered  (default APP2)
#   weston-flower      — animated rotating flower, CPU-rendered
#   weston-terminal    — interactive terminal (GTK/CSD, has title bar)
#
# Note: weston-simple-* are raw xdg-shell clients with no client-side
# decorations. They are moveable in desktop-shell by holding Super and dragging.
RUN apt-get update && apt-get install -y --no-install-recommends \
    weston \
    libgl1-mesa-dri \
    && rm -rf /var/lib/apt/lists/*

COPY entry.sh /entry.sh
RUN chmod +x /entry.sh

CMD ["/entry.sh"]
