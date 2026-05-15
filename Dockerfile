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

# Setup Weston
RUN mkdir -p /etc/weston/templates
COPY weston-templates/ /etc/weston/templates/
COPY weston-env-defaults.sh /etc/weston/weston-env-defaults.sh


COPY entry.sh /usr/bin/entry.sh
RUN chmod +x /usr/bin/entry.sh

CMD ["/usr/bin/entry.sh"]