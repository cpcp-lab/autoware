#!/usr/bin/env bash
# Run a VNC-enabled Autoware container (built by docker_vnc/build.sh).

set -e

# Define terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Autoware version of the images (keep in sync with docker_vnc/docker-bake.hcl)
AUTOWARE_VERSION="2.0.0"

# Default values
option_no_nvidia=false
if [ "$(uname -s)" = "Darwin" ]; then
    option_no_nvidia=true # NVIDIA GPUs are not available on macOS
fi
option_x11=false
option_devel=false
option_net_host=false
option_pull_latest_image=false
option_image=""
ROS_DISTRO_TAG="jazzy"
WORKSPACE_PATH=""
MAP_PATH=""
DATA_PATH=""
DDS_CONFIG=""
DOMAIN_ID=""
LAUNCH_FILE=""
EXTRA_ARGS=()
VNC_GEOMETRY="1920x1200"
VNC_DISPLAY=1
VNC_PASSWORD="ubuntu"

# Paths inside the container
CONTAINER_DATA_DIR="/home/aw/autoware_data"
CONTAINER_DDS_CONFIG="/etc/cyclonedds/cyclonedds.xml"
CONTAINER_LAUNCH_DIR="/home/aw/launch"
CONTAINER_DEFAULT_DDS_CONFIG="/home/aw/cyclonedds.xml" # set in the upstream base image

# DDS config used when it exists in the workspace (relative to the workspace)
WORKSPACE_DDS_CONFIG="docker_vnc/cyclonedds.xml"

# Data directory mounted when it exists in the workspace (relative to the workspace)
WORKSPACE_DATA_DIR="autoware_data"

# Function to print help message
print_help() {
    echo -e "${RED}Usage:${NC} run.sh [OPTIONS] [-- ARGS...]"
    echo -e "Options:"
    echo -e "  ${GREEN}--help/-h${NC}            Display this help message"
    echo -e "  ${GREEN}--x11${NC}                Use the host X server instead of VNC (Linux only)"
    echo -e "  ${GREEN}--geometry${NC}           VNC desktop resolution WxH (default: 1920x1200)"
    echo -e "  ${GREEN}--display${NC}            VNC display number (default: 1, port: 5901)"
    echo -e "  ${GREEN}--password${NC}           VNC password (default: ubuntu)"
    echo -e "  ${GREEN}--workspace${NC}          Directory to mount into /workspace (default: current directory)"
    echo -e "  ${GREEN}--map-path${NC}           Directory to mount into ${CONTAINER_DATA_DIR}/maps (read-only)"
    echo -e "  ${GREEN}--data-path${NC}          Directory to mount into ${CONTAINER_DATA_DIR}"
    echo -e "                       (default: ${WORKSPACE_DATA_DIR} in the workspace if it exists)"
    echo -e "  ${GREEN}--net-host${NC}           Use the host network (e.g. to talk to ROS nodes on the host)"
    echo -e "  ${GREEN}--domain-id${NC}          Set ROS_DOMAIN_ID"
    echo -e "  ${GREEN}--dds-config${NC}         CycloneDDS config file to use (default: ${WORKSPACE_DDS_CONFIG}"
    echo -e "                       in the workspace if it exists, otherwise the one in the image)"
    echo -e "  ${GREEN}--launch${NC}             Launch file to run with ros2 launch after startup"
    echo -e "  ${GREEN}--no-nvidia${NC}          Disable NVIDIA GPU support (default on macOS)"
    echo -e "  ${GREEN}--devel${NC}              Use the devel image instead of the runtime image"
    echo -e "  ${GREEN}--ros-distro${NC}         ROS distribution of the image (default: jazzy)"
    echo -e "  ${GREEN}--image${NC}              Docker image to use (overrides built-in image names)"
    echo -e "  ${GREEN}--pull-latest-image${NC}  Pull the latest image before starting"
    echo -e ""
    echo -e "ARGS after ${GREEN}--${NC} are passed to ros2 launch with ${GREEN}--launch${NC} (e.g. map_path:=...),"
    echo -e "or run as the command in the container otherwise (default: bash)."
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
    while [ $# -gt 0 ]; do
        case "$1" in
        --help | -h)
            print_help
            exit 0
            ;;
        --x11)
            option_x11=true
            ;;
        --geometry)
            require_value "$1" "$2"
            VNC_GEOMETRY="$2"
            shift
            ;;
        --display)
            require_value "$1" "$2"
            VNC_DISPLAY="$2"
            shift
            ;;
        --password)
            require_value "$1" "$2"
            VNC_PASSWORD="$2"
            shift
            ;;
        --workspace)
            require_value "$1" "$2"
            WORKSPACE_PATH="$2"
            shift
            ;;
        --map-path)
            require_value "$1" "$2"
            MAP_PATH="$2"
            shift
            ;;
        --data-path)
            require_value "$1" "$2"
            DATA_PATH="$2"
            shift
            ;;
        --net-host)
            option_net_host=true
            ;;
        --domain-id)
            require_value "$1" "$2"
            DOMAIN_ID="$2"
            shift
            ;;
        --dds-config)
            require_value "$1" "$2"
            DDS_CONFIG="$2"
            shift
            ;;
        --launch)
            require_value "$1" "$2"
            LAUNCH_FILE="$2"
            shift
            ;;
        --no-nvidia)
            option_no_nvidia=true
            ;;
        --devel)
            option_devel=true
            ;;
        --ros-distro)
            require_value "$1" "$2"
            ROS_DISTRO_TAG="$2"
            shift
            ;;
        --image)
            require_value "$1" "$2"
            option_image="$2"
            shift
            ;;
        --pull-latest-image)
            option_pull_latest_image=true
            ;;
        --)
            shift
            EXTRA_ARGS=("$@")
            break
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

# Absolute path of an existing file or directory (docker -v needs absolute paths)
abs_path() {
    if [ -d "$1" ]; then
        (cd "$1" && pwd)
    elif [ -f "$1" ]; then
        echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
    else
        echo -e "${RED}Not found:${NC} $1" >&2
        exit 1
    fi
}

# Time zone of the host
host_timezone() {
    local tz
    tz=$(cat /etc/timezone 2>/dev/null || readlink /etc/localtime 2>/dev/null | sed -n 's|.*zoneinfo/||p')
    echo "${tz:-UTC}"
}

# Resolve paths and the image name
set_variables() {
    if [ "$WORKSPACE_PATH" = "" ]; then
        WORKSPACE_PATH=$(pwd)
    fi
    WORKSPACE_PATH=$(abs_path "$WORKSPACE_PATH")
    if [ -n "$MAP_PATH" ]; then MAP_PATH=$(abs_path "$MAP_PATH"); fi
    if [ -n "$DATA_PATH" ]; then
        DATA_PATH=$(abs_path "$DATA_PATH")
    elif [ -d "${WORKSPACE_PATH}/${WORKSPACE_DATA_DIR}" ]; then
        DATA_PATH="${WORKSPACE_PATH}/${WORKSPACE_DATA_DIR}"
    fi
    if [ -n "$LAUNCH_FILE" ]; then LAUNCH_FILE=$(abs_path "$LAUNCH_FILE"); fi

    # DDS config: --dds-config > the one in the workspace > the image default
    DDS_URI=""
    if [ -n "$DDS_CONFIG" ]; then
        DDS_CONFIG=$(abs_path "$DDS_CONFIG")
        DDS_URI="file://${CONTAINER_DDS_CONFIG}"
    elif [ -f "${WORKSPACE_PATH}/${WORKSPACE_DDS_CONFIG}" ]; then
        DDS_URI="file:///workspace/${WORKSPACE_DDS_CONFIG}"
    fi

    VNC_PORT=$((5900 + VNC_DISPLAY))

    local suffix="${ROS_DISTRO_TAG}-${AUTOWARE_VERSION}"
    local prefix="universe"
    if [ "$option_devel" = "true" ]; then
        prefix="universe-devel"
    fi
    if [ "$option_no_nvidia" = "true" ]; then
        IMAGE="ghcr.io/cpcp-lab/autoware:${prefix}-vnc-${suffix}"
    else
        IMAGE="ghcr.io/cpcp-lab/autoware:${prefix}-cuda-vnc-${suffix}"
    fi
    if [ -n "$option_image" ]; then
        IMAGE="$option_image"
    fi
}

# Build the docker run options
set_docker_args() {
    # --privileged lets the upstream entrypoint tune the network for DDS
    DOCKER_ARGS=(-it --rm --privileged
        -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)"
        -e TZ="$(host_timezone)"
        -v "${WORKSPACE_PATH}:/workspace" -w /workspace)

    if [ "$option_no_nvidia" != "true" ]; then
        DOCKER_ARGS+=(--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all -e NVIDIA_VISIBLE_DEVICES=all)
    fi

    if [ "$option_x11" = "true" ]; then
        DOCKER_ARGS+=(--net=host
            -e DISPLAY="$DISPLAY" -e QT_X11_NO_MITSHM=1
            -v /tmp/.X11-unix:/tmp/.X11-unix:rw)
    else
        if [ "$option_net_host" = "true" ]; then
            DOCKER_ARGS+=(--net=host)
        else
            DOCKER_ARGS+=(-p "${VNC_PORT}:${VNC_PORT}")
        fi
        DOCKER_ARGS+=(-e VNC_DISPLAY="$VNC_DISPLAY" -e VNC_GEOMETRY="$VNC_GEOMETRY" -e VNC_PASSWORD="$VNC_PASSWORD")
    fi

    if [ -n "$DATA_PATH" ]; then
        DOCKER_ARGS+=(-v "${DATA_PATH}:${CONTAINER_DATA_DIR}")
    fi
    if [ -n "$MAP_PATH" ]; then
        DOCKER_ARGS+=(-v "${MAP_PATH}:${CONTAINER_DATA_DIR}/maps:ro")
    fi
    if [ -n "$DDS_CONFIG" ]; then
        DOCKER_ARGS+=(-v "${DDS_CONFIG}:${CONTAINER_DDS_CONFIG}:ro")
    fi
    if [ -n "$DDS_URI" ]; then
        DOCKER_ARGS+=(-e CYCLONEDDS_URI="$DDS_URI")
    fi
    if [ -n "$DOMAIN_ID" ]; then
        DOCKER_ARGS+=(-e ROS_DOMAIN_ID="$DOMAIN_ID")
    fi
    if [ -n "$LAUNCH_FILE" ]; then
        DOCKER_ARGS+=(-v "${LAUNCH_FILE}:${CONTAINER_LAUNCH_DIR}/$(basename "$LAUNCH_FILE"):ro")
    fi
}

# Build the command run in the container
set_command() {
    if [ -n "$LAUNCH_FILE" ]; then
        local launch_cmd
        launch_cmd="ros2 launch ${CONTAINER_LAUNCH_DIR}/$(basename "$LAUNCH_FILE")"
        if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
            launch_cmd="$launch_cmd $(printf '%q ' "${EXTRA_ARGS[@]}")"
        fi
        # Keep a shell after the launch exits
        COMMAND=(/bin/bash -c "source /opt/autoware/setup.bash && ${launch_cmd}; exec /bin/bash")
    elif [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
        COMMAND=("${EXTRA_ARGS[@]}")
    else
        COMMAND=(/bin/bash)
    fi

    if [ "$option_x11" != "true" ]; then
        COMMAND=(/usr/local/bin/start-vnc.sh "${COMMAND[@]}")
    fi
}

# Print launch info
print_info() {
    echo -e "${GREEN}-----------------------------------------------------------------${NC}"
    if [ "$option_x11" = "true" ]; then
        echo -e "${BLUE}Launching Autoware X11 environment${NC}"
    else
        echo -e "${BLUE}Launching Autoware VNC environment${NC}"
        echo -e "${GREEN}Connect VNC client to:${NC} localhost:${VNC_PORT}  (password: ${VNC_PASSWORD})"
    fi
    echo -e "${GREEN}IMAGE:${NC} ${IMAGE}"
    echo -e "${GREEN}WORKSPACE PATH(mounted):${NC} ${WORKSPACE_PATH}:/workspace"
    if [ -n "$DATA_PATH" ]; then
        echo -e "${GREEN}DATA PATH(mounted):${NC} ${DATA_PATH}:${CONTAINER_DATA_DIR}"
    fi
    if [ -n "$MAP_PATH" ]; then
        echo -e "${GREEN}MAP PATH(mounted):${NC} ${MAP_PATH}:${CONTAINER_DATA_DIR}/maps"
    fi
    if [ -n "$DDS_CONFIG" ]; then
        echo -e "${GREEN}DDS CONFIG:${NC} ${DDS_CONFIG}"
    elif [ -n "$DDS_URI" ]; then
        echo -e "${GREEN}DDS CONFIG:${NC} ${WORKSPACE_PATH}/${WORKSPACE_DDS_CONFIG}"
    else
        echo -e "${GREEN}DDS CONFIG:${NC} ${CONTAINER_DEFAULT_DDS_CONFIG} (image default)"
    fi
    if [ -n "$DOMAIN_ID" ]; then
        echo -e "${GREEN}ROS_DOMAIN_ID:${NC} ${DOMAIN_ID}"
    fi
    if [ -n "$LAUNCH_FILE" ]; then
        echo -e "${GREEN}LAUNCH FILE:${NC} ${LAUNCH_FILE}"
    fi
    echo -e "${GREEN}-----------------------------------------------------------------${NC}"
}

# Main script execution
main() {
    parse_arguments "$@"
    set_variables
    set_docker_args
    set_command

    if [ "$option_pull_latest_image" = "true" ]; then
        docker pull "${IMAGE}"
    fi

    print_info

    if [ "$option_x11" = "true" ]; then
        xhost +local:docker >/dev/null
    fi

    set -x
    docker run "${DOCKER_ARGS[@]}" "${IMAGE}" "${COMMAND[@]}"
}

# Execute the main script
main "$@"
