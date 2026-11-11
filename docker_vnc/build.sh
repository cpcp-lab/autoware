#!/usr/bin/env bash
# Build VNC-enabled Autoware images with docker buildx bake.
# See docker_vnc/docker-bake.hcl for the targets.

set -e

# Define terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WORKSPACE_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# Default values
option_no_cuda=false
option_all=false
option_devel=false
option_local_source=false
option_platform=""
option_ros_distro=""

# Function to print help message
print_help() {
    echo -e "${RED}Usage:${NC} build.sh [OPTIONS]"
    echo -e "Options:"
    echo -e "  ${GREEN}--help/-h${NC}         Display this help message"
    echo -e "  ${GREEN}--no-cuda${NC}         Build the image without CUDA (default: with CUDA)"
    echo -e "  ${GREEN}--all${NC}             Build both the CUDA and non-CUDA images"
    echo -e "  ${GREEN}--devel${NC}           Build the devel image instead of the runtime image"
    echo -e "  ${GREEN}--local-source${NC}    Build Autoware from src/ instead of using the images on GHCR"
    echo -e "  ${GREEN}--platform${NC}        Target platform: linux/amd64 or linux/arm64 (default: current platform)"
    echo -e "  ${GREEN}--ros-distro${NC}      ROS distribution (default: jazzy)"
    echo -e ""
    echo -e "The version of the images is set by AUTOWARE_VERSION in docker_vnc/docker-bake.hcl."
}

# Exit with an error if an option is missing its value
require_value() {
    if [ -z "$2" ] || [ "${2#--}" != "$2" ]; then
        echo -e "${RED}Option $1 requires a value.${NC}"
        print_help
        exit 1
    fi
}

# Parse arguments
parse_arguments() {
    while [ "$1" != "" ]; do
        case "$1" in
        --help | -h)
            print_help
            exit 0
            ;;
        --no-cuda)
            option_no_cuda=true
            ;;
        --all)
            option_all=true
            ;;
        --devel)
            option_devel=true
            ;;
        --local-source)
            option_local_source=true
            ;;
        --platform)
            require_value "$1" "$2"
            option_platform="$2"
            shift
            ;;
        --ros-distro)
            require_value "$1" "$2"
            option_ros_distro="$2"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
        esac
        shift
    done
}

# Select the bake target
set_target() {
    if [ "$option_devel" = "true" ]; then
        variant="devel"
        prefix="universe-devel"
    else
        variant="runtime"
        prefix="universe"
    fi

    if [ "$option_all" = "true" ]; then
        target="vnc-${variant}"
    elif [ "$option_no_cuda" = "true" ]; then
        target="${prefix}-vnc"
    else
        target="${prefix}-cuda-vnc"
    fi
}

# Check the platform option
check_platform() {
    case "$option_platform" in
    "" | linux/amd64 | linux/arm64) ;;
    *)
        echo "Unsupported platform: $option_platform"
        exit 1
        ;;
    esac
}

# Check that the sources exist when building from src/
check_sources() {
    if [ "$option_local_source" = "true" ] &&
        [ -z "$(find "$WORKSPACE_ROOT/src" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
        echo -e "${RED}No source repositories in src/.${NC} Run first: vcs import src < repositories/autoware.repos"
        exit 1
    fi
}

# Build images
build_images() {
    # https://github.com/docker/buildx/issues/484
    export BUILDKIT_STEP_LOG_MAX_SIZE=10000000

    if [ "$option_local_source" = "true" ]; then
        export VNC_BASE_SOURCE=local
    else
        export VNC_BASE_SOURCE=registry
    fi
    if [ -n "$option_ros_distro" ]; then
        export ROS_DISTRO="$option_ros_distro"
    fi

    platform_args=()
    if [ -n "$option_platform" ]; then
        platform_args=(--set "*.platform=$option_platform")
    fi

    echo "Target: $target"
    echo "Base image source: $VNC_BASE_SOURCE"
    echo "Platform: ${option_platform:-current}"

    # The upstream bake targets use the current directory as the build context
    cd "$WORKSPACE_ROOT"

    set -x
    docker buildx bake --load --progress=plain \
        -f docker/docker-bake.hcl \
        -f docker_vnc/docker-bake.hcl \
        "${platform_args[@]}" \
        "$target"
    set +x
}

# Main script execution
parse_arguments "$@"
set_target
check_platform
check_sources
build_images
