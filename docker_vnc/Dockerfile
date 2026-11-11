# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom,UndefinedVar
# Adds an XFCE desktop served by TigerVNC on top of an Autoware image.
# Build with docker_vnc/docker-bake.hcl, which sets BASE_IMAGE.
ARG BASE_IMAGE

FROM ${BASE_IMAGE} AS vnc
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG ROS_DISTRO

USER root
RUN --mount=type=cache,id=apt-cache-${ROS_DISTRO},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${ROS_DISTRO},target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-terminal \
    thunar \
    gnome-themes-extra \
    dbus-x11 \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-tools

# Desktop settings for the aw user. The entrypoint's usermod also updates
# the ownership of these files when it remaps the UID.
COPY --chown=${USERNAME}:${USERNAME} --chmod=755 docker_vnc/files/vnc/xstartup /home/${USERNAME}/.vnc/xstartup
COPY --chown=${USERNAME}:${USERNAME} docker_vnc/files/vnc/xsettings.xml \
    /home/${USERNAME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
COPY --chown=${USERNAME}:${USERNAME} --chmod=755 docker_vnc/files/vnc/Terminal.desktop /home/${USERNAME}/Desktop/Terminal.desktop

# Terminals opened on the desktop get the ROS and Autoware environment.
# (The upstream entrypoint sources /opt/autoware only in runtime images.)
RUN printf '\n%s\n%s\n' \
    'source "/opt/ros/${ROS_DISTRO}/setup.bash"' \
    '[ -f /opt/autoware/setup.bash ] && source /opt/autoware/setup.bash' \
    >> /home/${USERNAME}/.bashrc

COPY --chmod=755 docker_vnc/files/start-vnc.sh /usr/local/bin/start-vnc.sh

# Keep the upstream entrypoint: it runs as root, remaps the aw user to
# HOST_UID/HOST_GID, tunes the network for DDS, and drops to aw.
USER root
EXPOSE 5901
CMD ["/usr/local/bin/start-vnc.sh"]
