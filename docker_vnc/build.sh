#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(readlink -f "$(dirname "$0")")
ORG_SCRIPT_DIR=$SCRIPT_DIR/../docker
WORKSPACE_ROOT="$ORG_SCRIPT_DIR/.."

# Default values
option_no_cuda=false
option_platform=""

# Function to print help message
print_help() {
    echo "Usage: build.sh [OPTIONS]"
    echo "Options:"
    echo "  --help/-h       Display this help message"
    echo "  --no-cuda       Disable CUDA support (default: enabled)"
    echo "  --platform      Specify the platform (default: current platform)"
    echo ""
    echo "Note: The --platform option should be one of 'linux/amd64' or 'linux/arm64'."
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
        --platform)
            option_platform="$2"
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

# Set CUDA options
set_cuda_options() {
    if [ "$option_no_cuda" = "true" ]; then
        image_name_suffix=""
    else
        image_name_suffix="-cuda"
    fi
}

# Set platform
set_platform() {
    if [ -n "$option_platform" ]; then
        platform="$option_platform"
    else
        platform="linux/amd64"
        if [ "$(uname -m)" = "aarch64" ]; then
            platform="linux/arm64"
        fi
    fi
}

# Set arch lib dir
set_arch_lib_dir() {
    if [ "$platform" = "linux/arm64" ]; then
        lib_dir="aarch64"
    elif [ "$platform" = "linux/amd64" ]; then
        lib_dir="x86_64"
    else
        echo "Unsupported platform: $platform"
        exit 1
    fi
}

# Load env
load_env() {
    source "$WORKSPACE_ROOT/amd64.env"
    if [ "$platform" = "linux/arm64" ]; then
        source "$WORKSPACE_ROOT/arm64.env"
    fi
}

# Build images
build_images() {
    # https://github.com/docker/buildx/issues/484
    export BUILDKIT_STEP_LOG_MAX_SIZE=10000000

    target="universe-devel${image_name_suffix}-vnc"

    echo "Building images for platform: $platform"
    echo "ROS distro: $rosdistro"
    echo "Base image: $base_image"
    echo "Lib dir: $lib_dir"
    echo "Target: $target"

    set -x
    docker buildx bake --load --progress=plain \
        -f "$ORG_SCRIPT_DIR/docker-bake.hcl" \
        -f "$ORG_SCRIPT_DIR/docker-bake-cuda.hcl" \
        -f "$SCRIPT_DIR/docker-bake.hcl" \
        --set "*.context=$WORKSPACE_ROOT" \
        --set "*.ssh=default" \
        --set "*.platform=$platform" \
        --set "*.args.ROS_DISTRO=$rosdistro" \
        --set "*.args.AUTOWARE_BASE_IMAGE=$autoware_base_image" \
        --set "*.args.AUTOWARE_BASE_CUDA_IMAGE=$autoware_base_cuda_image" \
        --set "*.args.LIB_DIR=$lib_dir" \
        --set "universe-devel-vnc.tags=ghcr.io/autowarefoundation/autoware:universe-devel-vnc" \
        --set "universe-devel-cuda-vnc.tags=ghcr.io/autowarefoundation/autoware:universe-devel-cuda-vnc" \
        "$target"
    set +x
}

# Remove dangling images
remove_dangling_images() {
    docker image prune -f
}

# Main script execution
parse_arguments "$@"
set_cuda_options
set_platform
set_arch_lib_dir
load_env
build_images
remove_dangling_images
