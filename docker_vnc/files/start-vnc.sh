#!/usr/bin/env bash
# Start a TigerVNC server with an XFCE desktop, then run the given command
# (default: an interactive bash). Runs as the aw user via the entrypoint.
#
# Environment variables:
#   VNC_DISPLAY   display number; the port is 5900 + VNC_DISPLAY (default: 1)
#   VNC_GEOMETRY  desktop size WxH (default: 1920x1200)
#   VNC_PASSWORD  VNC password (default: ubuntu)
set -e

VNC_DISPLAY=${VNC_DISPLAY:-1}
VNC_GEOMETRY=${VNC_GEOMETRY:-1920x1200}
VNC_PASSWORD=${VNC_PASSWORD:-ubuntu}

mkdir -p "$HOME/.vnc"
echo "$VNC_PASSWORD" | vncpasswd -f >"$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"

vncserver ":${VNC_DISPLAY}" -geometry "$VNC_GEOMETRY" -depth 24 -localhost no
export DISPLAY=":${VNC_DISPLAY}"

if [ $# -eq 0 ]; then
    set -- /bin/bash
fi
exec "$@"
