#!/bin/bash
set -e

MACHINE_NAME="${1:-}"

if [ "${MACHINE_NAME:0:9}" = "raspberry" ]; then
    echo "[setup_rpi_repo] Raspberry Pi detected (${MACHINE_NAME}) — adding RPi OS repo"
    apt-get update -qq && apt-get install -y --no-install-recommends curl gpg ca-certificates gpgv

    # Debian 13 uses sqv (Sequoia PGP) for apt signature verification, which rejects
    # SHA1-based key certifications since 2026-02-01. The RPi OS repo key uses SHA1.
    # Configure apt to use gpgv (GnuPG) instead, which still accepts SHA1.
    echo 'Apt::Key::gpgvcommand "/usr/bin/gpgv";' \
        > /etc/apt/apt.conf.d/99use-gpgv-for-sha1-repos

    curl -fsSL https://archive.raspberrypi.org/debian/raspberrypi.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/raspberrypi-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/raspberrypi-archive-keyring.gpg] \
        http://archive.raspberrypi.org/debian/ trixie main" \
        > /etc/apt/sources.list.d/raspi.list
    cp /usr/src/build/raspi-pinning /etc/apt/preferences.d/raspi-pinning
    apt-get clean && rm -rf /var/lib/apt/lists/*
else
    echo "[setup_rpi_repo] Non-RPi device (${MACHINE_NAME}) — skipping RPi OS repo"
fi
