// VNC-enabled Autoware images.
//
// This file extends docker/docker-bake.hcl and must be loaded together with it,
// from the repository root:
//
//   docker buildx bake -f docker/docker-bake.hcl -f docker_vnc/docker-bake.hcl --load vnc-devel
//
// Groups: vnc-devel (devel images), vnc-runtime (runtime images), vnc (all).
//
// By default the VNC layer is added on top of the pre-built images on GHCR.
// Set VNC_BASE_SOURCE=local to build the base images from src/ instead
// (run `vcs import src < repositories/autoware.repos` first):
//
//   VNC_BASE_SOURCE=local docker buildx bake -f docker/docker-bake.hcl -f docker_vnc/docker-bake.hcl --load universe-devel-cuda-vnc

// Where the base image comes from: "registry" (pull from VNC_BASE_REGISTRY)
// or "local" (build the upstream target from src/).
variable "VNC_BASE_SOURCE" {
  default = "registry"
  validation {
    condition     = contains(["registry", "local"], VNC_BASE_SOURCE)
    error_message = "VNC_BASE_SOURCE must be \"registry\" or \"local\"."
  }
}

variable "VNC_BASE_REGISTRY" {
  default = "ghcr.io/autowarefoundation/autoware"
}

// Registry name used for the tags of the VNC images.
variable "VNC_REGISTRY" {
  default = "ghcr.io/cpcp-lab/autoware"
}

// Autoware version of this repository. Used for both the tags of the base
// images pulled from GHCR and the tags of the VNC images.
// Keep in sync with AUTOWARE_VERSION in docker_vnc/run.sh.
variable "AUTOWARE_VERSION" {
  default = "2.0.0"
}

// Named context for the base image of a VNC target.
function "vnc_base" {
  params = [name]
  result = VNC_BASE_SOURCE == "local" ? "target:${name}" : "docker-image://${VNC_BASE_REGISTRY}:${name}-${ROS_DISTRO}-${AUTOWARE_VERSION}"
}

function "vnc_tags" {
  params = [name]
  result = ["${VNC_REGISTRY}:${name}-${ROS_DISTRO}-${AUTOWARE_VERSION}"]
}

group "vnc" {
  targets = ["vnc-devel", "vnc-runtime"]
}

// Development images: compilers and build dependencies included
group "vnc-devel" {
  targets = ["universe-devel-vnc", "universe-devel-cuda-vnc"]
}

// Runtime images: only what is needed to run Autoware
group "vnc-runtime" {
  targets = ["universe-vnc", "universe-cuda-vnc"]
}

target "universe-devel-vnc" {
  dockerfile = "docker_vnc/Dockerfile"
  target     = "vnc"
  tags       = vnc_tags("universe-devel-vnc")
  contexts = {
    autoware-vnc-base = vnc_base("universe-devel")
  }
  args = {
    BASE_IMAGE = "autoware-vnc-base"
    ROS_DISTRO = ROS_DISTRO
  }
}

target "universe-devel-cuda-vnc" {
  inherits = ["universe-devel-vnc"]
  tags     = vnc_tags("universe-devel-cuda-vnc")
  contexts = {
    autoware-vnc-base = vnc_base("universe-devel-cuda")
  }
}

target "universe-vnc" {
  inherits = ["universe-devel-vnc"]
  tags     = vnc_tags("universe-vnc")
  contexts = {
    autoware-vnc-base = vnc_base("universe")
  }
}

target "universe-cuda-vnc" {
  inherits = ["universe-devel-vnc"]
  tags     = vnc_tags("universe-cuda-vnc")
  contexts = {
    autoware-vnc-base = vnc_base("universe-cuda")
  }
}
