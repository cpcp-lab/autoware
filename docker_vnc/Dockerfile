#ARG AUTOWARE_DEVEL_IMAGE=ghcr.io/autowarefoundation/autoware:universe-devel-1.7.1
#ARG AUTOWARE_DEVEL_IMAGE=ghcr.io/cpcp-lab/autoware:universe-devel
ARG AUTOWARE_DEVEL_IMAGE=ghcr.io/cpcp-lab/autoware-tools:scenario-simulator
#ARG AUTOWARE_DEVEL_CUDA_IMAGE=ghcr.io/autowarefoundation/autoware:universe-devel-cuda-1.7.1
#ARG AUTOWARE_DEVEL_CUDA_IMAGE=ghcr.io/cpcp-lab/autoware:universe-devel-cuda
ARG AUTOWARE_DEVEL_CUDA_IMAGE=ghcr.io/cpcp-lab/autoware-tools:scenario-simulator-cuda

# hadolint ignore=DL3006
FROM $AUTOWARE_DEVEL_IMAGE AS universe-devel-vnc

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  xfce4 \
  xfce4-terminal \
  thunar \
  gnome-themes-extra \
  dbus-x11 \
  tigervnc-standalone-server tigervnc-common tigervnc-tools \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY map/shinjuku_map /shinjuku_map

COPY docker_vnc/cyclonedds.xml /cyclonedds.xml
COPY docker_vnc/etc/ros_entrypoint_vnc.sh /ros_entrypoint_vnc.sh
COPY docker_vnc/etc/simulation.sh /simulation.sh
RUN chmod +x /ros_entrypoint_vnc.sh && chmod +x /simulation.sh

ENTRYPOINT ["/ros_entrypoint_vnc.sh"]
CMD ["/bin/bash"]

# hadolint ignore=DL3006
FROM $AUTOWARE_DEVEL_CUDA_IMAGE AS universe-devel-cuda-vnc

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  xfce4 \
  xfce4-terminal \
  thunar \
  gnome-themes-extra \
  dbus-x11 \
  tigervnc-standalone-server tigervnc-common tigervnc-tools \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY map/shinjuku_map /shinjuku_map

COPY docker_vnc/cyclonedds.xml /cyclonedds.xml
COPY docker_vnc/etc/ros_entrypoint_vnc.sh /ros_entrypoint_vnc.sh
COPY docker_vnc/etc/simulation.sh /simulation.sh
RUN chmod +x /ros_entrypoint_vnc.sh && chmod +x /simulation.sh

COPY AWSIM-Demo-OpenSCENARIO /AWSIM

ENTRYPOINT ["/ros_entrypoint_vnc.sh"]
CMD ["/bin/bash"]
