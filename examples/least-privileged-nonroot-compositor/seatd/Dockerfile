FROM debian:13.2-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    dbus \
    seatd \
    && rm -rf /var/lib/apt/lists/*

# 'seat' group with a fixed GID so the /run/seatd.sock group aligns numerically
# with the 'seat' group the compositor user belongs to in the display container.
RUN groupadd -g 915 seat

COPY entry.sh /usr/bin/entry.sh
RUN chmod +x /usr/bin/entry.sh

CMD ["/usr/bin/entry.sh"]
