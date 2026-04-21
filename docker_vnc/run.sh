#!/usr/bin/env bash
# shellcheck disable=SC2086

set -e

# Define terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
option_no_nvidia=false
option_x11=false
option_pull_latest_image=false
option_image=""
MAP_PATH=""
DATA_PATH=""
WORKSPACE_PATH=""
VNC_GEOMETRY="1920x1200"
VNC_DISPLAY=1

# Function to print help message
print_help() {
    echo -e "\n------------------------------------------------------------"
    echo -e "${RED}Usage:${NC} run.sh [OPTIONS]"
    echo -e "Options:"
    echo -e "  ${GREEN}--help/-h${NC}            Display this help message"
    echo -e "  ${GREEN}--x11${NC}                Use X11 mode (default: VNC mode)"
    echo -e "  ${GREEN}--geometry${NC}           VNC desktop resolution WxH (default: 1920x1200)
  ${GREEN}--display${NC}            VNC display number (default: 1, port: 5901)"
    echo -e "  ${GREEN}--workspace${NC}          Directory to mount into /workspace (default: current directory)"
    echo -e "  ${GREEN}--map-path${NC}           Mount map files into /autoware_map"
    echo -e "  ${GREEN}--data-path${NC}          Mount data files into /autoware_data"
    echo -e "  ${GREEN}--no-nvidia${NC}          Disable NVIDIA GPU support"
    echo -e "  ${GREEN}--image${NC}              Docker image to use (overrides built-in image names)"
    echo -e "  ${GREEN}--pull-latest-image${NC}  Pull the latest image before starting"
    echo -e "------------------------------------------------------------"
}

# Parse arguments
parse_arguments() {
    while [ "$1" != "" ]; do
        case "$1" in
        --help | -h)
            print_help
            exit 0
            ;;
        --x11)
            option_x11=true
            ;;
        --geometry)
            VNC_GEOMETRY="$2"
            shift
            ;;
        --display)
            VNC_DISPLAY="$2"
            shift
            ;;
        --no-nvidia)
            option_no_nvidia=true
            ;;
        --image)
            option_image="$2"
            shift
            ;;
        --pull-latest-image)
            option_pull_latest_image=true
            ;;
        --workspace)
            WORKSPACE_PATH="$2"
            shift
            ;;
        --map-path)
            MAP_PATH="$2"
            shift
            ;;
        --data-path)
            DATA_PATH="$2"
            shift
            ;;
        --*)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
        esac
        shift
    done
}

# Set common volume variables
set_variables() {
    USER_ID="-e LOCAL_UID=$(id -u) -e LOCAL_GID=$(id -g) -e LOCAL_USER=$(id -un) -e LOCAL_GROUP=$(id -gn)"

    if [ "$MAP_PATH" != "" ]; then
        MAP="-v ${MAP_PATH}:/autoware_map:ro"
    fi

    if [ "$DATA_PATH" != "" ]; then
        DATA="-v ${DATA_PATH}:/autoware_data:rw"
    fi

    if [ "$WORKSPACE_PATH" = "" ]; then
        WORKSPACE_PATH=$(pwd)
    fi
    WORKSPACE="-v ${WORKSPACE_PATH}:/workspace"
    VNC_PORT=$((5900 + VNC_DISPLAY))
}

# Set GPU flag and image name
set_gpu_flag() {
    if [ "$option_no_nvidia" = "true" ]; then
        GPU_FLAG=""
        IMAGE="ghcr.io/autowarefoundation/autoware:universe-devel-vnc"
    else
        GPU_FLAG="--gpus all"
        IMAGE="ghcr.io/autowarefoundation/autoware:universe-devel-cuda-vnc"
    fi
    if [ -n "$option_image" ]; then
        IMAGE="$option_image"
    fi
}

# Print launch info
print_info() {
    echo -e "${GREEN}-----------------------------------------------------------------${NC}"
    if [ "$option_x11" = "true" ]; then
        echo -e "${BLUE}Launching Autoware X11 environment${NC}"
    else
        echo -e "${BLUE}Launching Autoware VNC environment${NC}"
        echo -e "${GREEN}Connect VNC client to:${NC} localhost:${VNC_PORT}  (password: ubuntu)"
    fi
    echo -e "${GREEN}IMAGE:${NC} ${IMAGE}"
    echo -e "${GREEN}WORKSPACE PATH(mounted):${NC} ${WORKSPACE_PATH}:/workspace"
    if [ "$MAP_PATH" != "" ]; then
        echo -e "${GREEN}MAP PATH(mounted):${NC} ${MAP_PATH}:/autoware_map"
    fi
    if [ "$DATA_PATH" != "" ]; then
        echo -e "${GREEN}DATA PATH(mounted):${NC} ${DATA_PATH}:/autoware_data"
    fi
    echo -e "${GREEN}-----------------------------------------------------------------${NC}"
}

# Main script execution
main() {
    parse_arguments "$@"
    set_variables
    set_gpu_flag

    if [ "$option_pull_latest_image" = "true" ]; then
        docker pull "${IMAGE}"
    fi

    print_info

    set -x
    if [ "$option_x11" = "true" ]; then
        xhost + >/dev/null
        docker run -it --rm --net=host ${GPU_FLAG} ${USER_ID} \
            -e DISPLAY="$DISPLAY" -v /tmp/.X11-unix/:/tmp/.X11-unix \
            -e XAUTHORITY="${XAUTHORITY}" -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
            -e NVIDIA_DRIVER_CAPABILITIES=all -e TZ="$(cat /etc/timezone 2>/dev/null || echo "UTC")" \
            ${WORKSPACE} ${MAP} ${DATA} "${IMAGE}" \
            /bin/bash
    else
        docker run -it --rm -p "${VNC_PORT}:${VNC_PORT}" ${GPU_FLAG} ${USER_ID} \
            -e NVIDIA_DRIVER_CAPABILITIES=all -e TZ="$(cat /etc/timezone 2>/dev/null || echo "UTC")" \
            ${WORKSPACE} ${MAP} ${DATA} "${IMAGE}" \
            /bin/bash -c "vncserver :${VNC_DISPLAY} -geometry ${VNC_GEOMETRY} -depth 24 -localhost no; exec /bin/bash"
    fi
}

# Execute the main script
main "$@"
