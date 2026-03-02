FROM debian:13.2-slim

ENV DEBIAN_FRONTEND=noninteractive

# install weston which includes touchscreen demos
RUN apt-get update && apt-get install -y --no-install-recommends \
    gtk-4-examples \
    && rm -rf /var/lib/apt/lists/*

COPY entry.sh /usr/bin/entry.sh
RUN chmod +x /usr/bin/entry.sh

CMD ["/usr/bin/entry.sh"]
