FROM debian:13.2-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    mesa-utils \
    libgl1-mesa-dri \
    libwayland-client0 \
    && rm -rf /var/lib/apt/lists/*

COPY entry.sh /usr/bin/entry.sh
RUN chmod +x /usr/bin/entry.sh

CMD ["/usr/bin/entry.sh"]
