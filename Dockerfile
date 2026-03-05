FROM debian:13.2-slim

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    # xargs apt-get install -y --no-install-recommends < /etc/DEPENDENCIES && \
    apt-get install -y --no-install-recommends \
    weston=14.*  \
    libgl1-mesa-dri=25.* \
    dbus \
    libinput10 \
    udev \
    && rm -rf /var/lib/apt/lists/*

# Setup Weston
RUN mkdir -p /etc/xdg/weston
COPY weston.ini /etc/xdg/weston/weston.ini
COPY entry.sh /usr/bin/entry.sh
RUN chmod +x /usr/bin/entry.sh

CMD ["/usr/bin/entry.sh"]