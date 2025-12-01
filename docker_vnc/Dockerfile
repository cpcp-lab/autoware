ARG AUTOWARE_BASE_IMAGE
ARG AUTOWARE_BASE_CUDA_IMAGE

# hadolint ignore=DL3006
FROM ghcr.io/autowarefoundation/autoware:universe AS universe-vnc

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
FROM ghcr.io/autowarefoundation/autoware:universe-devel AS universe-devel-vnc

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
