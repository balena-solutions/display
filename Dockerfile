FROM debian:13.2-slim

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    dbus \
    gettext-base \
    libgl1-mesa-dri=25.* \
    libinput10 \
    udev \
    weston=14.* \
    && rm -rf /var/lib/apt/lists/*

# Create an unprivileged compositor user for the non-root deployment path
# (see examples/least-privileged-nonroot-compositor). The default runtime user
# is still root (no USER directive); entry.sh only drops to this user when
# COMPOSITOR_USER is set. GID 915 for 'seat' must match the seatd sidecar so
# the /run/seatd.sock group aligns numerically across containers.
RUN groupadd -g 915 seat && \
    useradd -u 1000 -m -s /usr/sbin/nologin -G seat weston

# Setup Weston
RUN mkdir -p /etc/weston/templates
COPY weston-templates/ /etc/weston/templates/
COPY weston-env-defaults.sh /etc/weston/weston-env-defaults.sh


COPY entry.sh /usr/bin/entry.sh
RUN chmod +x /usr/bin/entry.sh

CMD ["/usr/bin/entry.sh"]