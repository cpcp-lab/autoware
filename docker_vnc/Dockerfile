ARG AUTOWARE_DEVEL_IMAGE=ghcr.io/autowarefoundation/autoware:universe-devel-1.7.1
ARG AUTOWARE_DEVEL_CUDA_IMAGE=ghcr.io/autowarefoundation/autoware:universe-devel-cuda-1.7.1

# hadolint ignore=DL3006
FROM $AUTOWARE_DEVEL_IMAGE AS universe-devel-vnc

ENV DEBIAN_FRONTEND=noninteractive    

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  ubuntu-mate-desktop \
  tigervnc-standalone-server tigervnc-common tigervnc-tools \
  && apt-get install -y --no-install-recommends \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY docker_vnc/etc/ros_entrypoint_vnc.sh /ros_entrypoint_vnc.sh
RUN chmod +x /ros_entrypoint_vnc.sh

ENTRYPOINT ["/ros_entrypoint_vnc.sh"]
CMD ["/bin/bash"]

# hadolint ignore=DL3006
#FROM ghcr.io/autowarefoundation/autoware:universe-devel AS universe-devel-vnc
FROM $AUTOWARE_DEVEL_CUDA_IMAGE AS universe-devel-cuda-vnc

ENV DEBIAN_FRONTEND=noninteractive    

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  ubuntu-mate-desktop \
  tigervnc-standalone-server tigervnc-common tigervnc-tools \
  && apt-get install -y --no-install-recommends \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY docker_vnc/etc/ros_entrypoint_vnc.sh /ros_entrypoint_vnc.sh
RUN chmod +x /ros_entrypoint_vnc.sh

ENTRYPOINT ["/ros_entrypoint_vnc.sh"]
CMD ["/bin/bash"]
