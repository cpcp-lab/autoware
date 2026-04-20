#!/bin/bash

while true; do
    echo "=== Running colcon build ==="

    # Save the output of colcon build.
    BUILD_LOG=$(mktemp)
    script -q -e -f -c "colcon build --parallel-workers 6 --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=\"-w\"" /dev/stdout | tee "$BUILD_LOG"
    RESULT=${PIPESTATUS[0]}

    if [ $RESULT -eq 0 ]; then
        echo "=== colcon build Succeeded! ==="
        rm "$BUILD_LOG"
        break
    fi

    echo "=== colcon build Failed... Searching failed packages ==="

    # Extract the name of failed packages.
    FAILED_PKGS=$(grep -oP "(?<=Failed   <<< ).+?(?= \[)" "$BUILD_LOG")

    if [ -z "$FAILED_PKGS" ]; then
        echo "Failed package could not be detected. Exiting."
        echo "Log file: $BUILD_LOG"
        exit 1
    fi

    for PKG in $FAILED_PKGS; do
        echo ">>> Trying manual make for package: $PKG"

        if [ -d "build/$PKG" ]; then
                cd "build/$PKG" || exit
                make
    		if [ $? -eq 0 ]; then
                    echo "succeeded!"
		    cd "../.."
                else
                    echo "failed"
                    exit 1
    		fi
        else
            echo "Directory build/$PKG not found. Skipping."
        fi
    done

    rm "$BUILD_LOG"
done
