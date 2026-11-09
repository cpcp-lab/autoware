#!/usr/bin/env bash
# cspell:ignore
# shellcheck disable=SC1090,SC1091

# Default values
opt_awsim=false
shinjuku_map_dir="/shinjuku_map"
SCENARIO=""

# Function to print help message
print_help() {
    printf "${RED}Usage:${NC} run.sh [OPTIONS]\n"
    printf "Options:\n"
    printf "  ${GREEN}--help/-h${NC}            Display this help message\n"
    printf "  ${GREEN}--awsim${NC}              Simulate with AWSIM\n"
    printf "  ${GREEN}--s1${NC}                 Simulate a Shinjuku scenario (consists of 3 runs)\n"
    printf "  ${GREEN}--s100${NC}               Simulate 100 scenarios\n"
}

# Parse arguments
parse_arguments() {
    while [ "$1" != "" ]; do
        case "$1" in
        --help | -h)
            print_help
            exit 0
            ;;
        --awsim)
            opt_awsim=true
            ;;
        --s1)
            if [ ! -d "$shinjuku_map_dir" ]; then
                echo "Shinjuku map does not exist!"
                exit 1
            fi
            SCENARIO="${shinjuku_map_dir}/scenario1.yaml"
            ;;
        --s100)
            if [ ! -d "$shinjuku_map_dir" ]; then
                echo "Shinjuku map does not exist!"
                exit 1
            fi
            SCENARIO="${shinjuku_map_dir}/scenario100.yaml"
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

run_simulator_simple() {
    printf "\e[32mRunning simple simulator...\e[0m\n"

    # Prompt if no scenario is provided
    if [ -z "$SCENARIO" ]; then
        printf "\e[33mNo scenario provided, using default sample scenario...\e[0m\n"
    fi

    # Set default values if not provided
    #LAUNCH_AUTOWARE=${LAUNCH_AUTOWARE:-false}
    #LAUNCH_RVIZ=${LAUNCH_RVIZ:-false}
    ARCHITECTURE_TYPE=${ARCHITECTURE_TYPE:-awf/universe/20240605}
    SENSOR_MODEL=${SENSOR_MODEL:-sample_sensor_kit}
    VEHICLE_MODEL=${VEHICLE_MODEL:-sample_vehicle}
    INITIALIZE_DURATION=${INITIALIZE_DURATION:-90}
    GLOBAL_FRAME_RATE=${GLOBAL_FRAME_RATE:-30}
    OUTPUT_DIRECTORY=${OUTPUT_DIRECTORY:-/autoware_data}
    SCENARIO=${SCENARIO:-$(ros2 pkg prefix --share scenario_test_runner)/scenario/sample.yaml}
    #GLOBAL_TIMEOUT=${GLOBAL_TIMEOUT:-120}
    RECORD=${RECORD:-false}
    #USE_SIM_TIME=${USE_SIM_TIME:-false}

    # Print all variables
    echo "ARCHITECTURE_TYPE: $ARCHITECTURE_TYPE"
    echo "SENSOR_MODEL: $SENSOR_MODEL"
    echo "VEHICLE_MODEL: $VEHICLE_MODEL"
    echo "INITIALIZE_DURATION: $INITIALIZE_DURATION"
    echo "GLOBAL_FRAME_RATE: $GLOBAL_FRAME_RATE"
    echo "OUTPUT_DIRECTORY: $OUTPUT_DIRECTORY"
    echo "SCENARIO: $SCENARIO"
    echo "RECORD: $RECORD"

    # Launch scenario test runner
    ros2 launch scenario_test_runner_mod test_runner.launch.py \
        architecture_type:="$ARCHITECTURE_TYPE" \
        sensor_model:="$SENSOR_MODEL" \
        vehicle_model:="$VEHICLE_MODEL" \
        initialize_duration:="$INITIALIZE_DURATION" \
        global_frame_rate:="$GLOBAL_FRAME_RATE" \
        output_directory:="$OUTPUT_DIRECTORY" \
        scenario:="$SCENARIO" \
        record:="$RECORD"
}

run_simulator_awsim() {
    printf "\e[32mRunning AWSIM simulator...\e[0m\n"

    # Prompt if no scenario is provided
    if [ -z "$SCENARIO" ]; then
        printf "\e[33mNo scenario provided, using default sample scenario...\e[0m\n"
    fi

    # Set default values if not provided
    #LAUNCH_AUTOWARE=${LAUNCH_AUTOWARE:-false}
    #LAUNCH_RVIZ=${LAUNCH_RVIZ:-false}
    ARCHITECTURE_TYPE=${ARCHITECTURE_TYPE:-awf/universe/20250130}
    SENSOR_MODEL=${SENSOR_MODEL:-awsim_sensor_kit}
    VEHICLE_MODEL=${VEHICLE_MODEL:-sample_vehicle}
    INITIALIZE_DURATION=${INITIALIZE_DURATION:-260}
    GLOBAL_FRAME_RATE=${GLOBAL_FRAME_RATE:-15}
    OUTPUT_DIRECTORY=${OUTPUT_DIRECTORY:-/autoware_data}
    SCENARIO=${SCENARIO:-$(ros2 pkg prefix --share scenario_test_runner)/scenario/sample.yaml}
    #GLOBAL_TIMEOUT=${GLOBAL_TIMEOUT:-120}
    RECORD=${RECORD:-false}
    #USE_SIM_TIME=${USE_SIM_TIME:-false}
    LAUNCH_SIMPLE_SENSOR_SIMULATOR=${LAUNCH_SIMPLE_SENSOR_SIMULATOR:-false}
    AUTOWARE_LAUNCH_FILE=${AUTOWARE_LAUNCH_FILE:-e2e_simulator.launch.xml}
    PORT=${PORT:-8080}

    # Print all variables
    echo "ARCHITECTURE_TYPE: $ARCHITECTURE_TYPE"
    echo "SENSOR_MODEL: $SENSOR_MODEL"
    echo "VEHICLE_MODEL: $VEHICLE_MODEL"
    echo "INITIALIZE_DURATION: $INITIALIZE_DURATION"
    echo "GLOBAL_FRAME_RATE: $GLOBAL_FRAME_RATE"
    echo "OUTPUT_DIRECTORY: $OUTPUT_DIRECTORY"
    echo "SCENARIO: $SCENARIO"
    echo "RECORD: $RECORD"
    echo "LAUNCH_SIMPLE_SENSOR_SIMULATOR: ${LAUNCH_SIMPLE_SENSOR_SIMULATOR}"
    echo "AUTOWARE_LAUNCH_FILE: ${AUTOWARE_LAUNCH_FILE}"
    echo "PORT: ${PORT}"

    # Launch scenario test runner
    ros2 launch scenario_test_runner_mod test_runner.launch.py \
        architecture_type:="$ARCHITECTURE_TYPE" \
        sensor_model:="$SENSOR_MODEL" \
        vehicle_model:="$VEHICLE_MODEL" \
        initialize_duration:="$INITIALIZE_DURATION" \
        global_frame_rate:="$GLOBAL_FRAME_RATE" \
        output_directory:="$OUTPUT_DIRECTORY" \
        scenario:="$SCENARIO" \
        record:="$RECORD" \
        launch_simple_sensor_simulator:="$LAUNCH_SIMPLE_SENSOR_SIMULATOR" \
        autoware_launch_file:="$AUTOWARE_LAUNCH_FILE" \
        port:="$PORT"
}

# AWSIM
AWSIM_CMD="/AWSIM/AWSIM-Demo-OpenSCENARIO.x86_64"
AWSIM_WAIT=10

cleanup() {
    [ -n "${AWSIM_PID:-}" ] && kill "${AWSIM_PID}" 2>/dev/null || true
}
trap cleanup EXIT

# Main script execution
main() {
    parse_arguments "$@"
    if ! $opt_awsim; then
        run_simulator_simple
    else
        bash -c "${AWSIM_CMD}" &
        AWSIM_PID=$!

        sleep "${AWSIM_WAIT}"

        run_simulator_awsim
    fi
}

# Execute the main script
main "$@"
