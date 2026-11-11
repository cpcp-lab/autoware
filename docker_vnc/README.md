# Autoware Docker Images Extended with VNC Environment

These scripts add an XFCE desktop served by TigerVNC on top of the official Autoware images,
so that GUI tools such as RViz can be used through a VNC client (e.g. on macOS).

Run all commands from the repository root.

## Images

| Image (`ghcr.io/cpcp-lab/autoware:`)  | Base image (`ghcr.io/autowarefoundation/autoware:`) | Notes                                 |
| ------------------------------------- | --------------------------------------------------- | ------------------------------------- |
| `universe-vnc-jazzy-2.0.0`            | `universe-jazzy-2.0.0`                              | Runtime, no CUDA                      |
| `universe-cuda-vnc-jazzy-2.0.0`       | `universe-cuda-jazzy-2.0.0`                         | Runtime, CUDA                         |
| `universe-devel-vnc-jazzy-2.0.0`      | `universe-devel-jazzy-2.0.0`                        | Devel (build tools included), no CUDA |
| `universe-devel-cuda-vnc-jazzy-2.0.0` | `universe-devel-cuda-jazzy-2.0.0`                   | Devel (build tools included), CUDA    |

The version (`2.0.0`) is set by `AUTOWARE_VERSION` in `docker_vnc/docker-bake.hcl` and in `docker_vnc/run.sh`.

## Build

`build.sh` runs `docker buildx bake` with `docker/docker-bake.hcl` and `docker_vnc/docker-bake.hcl`.
By default, the VNC layer is added on top of the pre-built images on GHCR, which takes only a few minutes.

```bash
# Runtime image with CUDA (default)
./docker_vnc/build.sh

# Runtime image without CUDA (e.g. on macOS)
./docker_vnc/build.sh --no-cuda

# Devel image without CUDA
./docker_vnc/build.sh --devel --no-cuda

# Both the CUDA and non-CUDA runtime images
./docker_vnc/build.sh --all
```

| Option           | Description                                                              |
| ---------------- | ------------------------------------------------------------------------ |
| `--no-cuda`      | Build the image without CUDA (default: with CUDA)                         |
| `--all`          | Build both the CUDA and non-CUDA images                                   |
| `--devel`        | Build the devel image instead of the runtime image                        |
| `--local-source` | Build Autoware from `src/` instead of using the images on GHCR            |
| `--platform`     | `linux/amd64` or `linux/arm64` (default: current platform)                |
| `--ros-distro`   | ROS distribution (default: `jazzy`)                                       |

To build Autoware itself from source (this takes hours), import the repositories first:

```bash
vcs import src < repositories/autoware.repos
./docker_vnc/build.sh --local-source
```

The bake targets can also be used directly:

```bash
docker buildx bake -f docker/docker-bake.hcl -f docker_vnc/docker-bake.hcl --load universe-vnc
```

## Run

```bash
# Start the runtime image (CUDA is disabled automatically on macOS)
./docker_vnc/run.sh

# Start the devel image
./docker_vnc/run.sh --devel
```

Then connect a VNC client to `localhost:5901` (password: `ubuntu`).
A terminal opened on the desktop has the ROS 2 and Autoware environment set up.

### Mounted directories

| Host                                                    | Container                     |
| ------------------------------------------------------- | ----------------------------- |
| Current directory (or `--workspace DIR`)                | `/workspace`                  |
| `autoware_data/` in the workspace (or `--data-path DIR`) | `/home/aw/autoware_data`      |
| `--map-path DIR` (read-only)                            | `/home/aw/autoware_data/maps` |

Place maps under `autoware_data/maps/` and ML models under `autoware_data/ml_models/`,
following the layout of the upstream Autoware images. For example:

```bash
ros2 launch autoware_launch planning_simulator.launch.xml \
  vehicle_model:=sample_vehicle sensor_model:=sample_sensor_kit \
  map_path:=/home/aw/autoware_data/maps/sample-map-planning
```

### DDS configuration

The CycloneDDS configuration is chosen in this order:

1. The file given with `--dds-config FILE`
2. `docker_vnc/cyclonedds.xml` in the workspace, if it exists
3. The default configuration in the image (`/home/aw/cyclonedds.xml`, loopback only)

`cyclonedds-lb-docker.xml` is meant for talking to ROS nodes on the host (e.g. MATLAB) and contains
addresses specific to Docker Desktop.
To talk to ROS nodes on the host, use this configuration together with the host network and the same domain ID:

```bash
# Modify cyclonedds-lb-docker.xml according to your network environment
./docker_vnc/run.sh --net-host --domain-id 25 --dds-config docker_vnc/cyclonedds-lb-docker.xml
```

### Running a launch file at startup

`--launch FILE` mounts the file into the container and runs it with `ros2 launch` after the desktop starts.
Arguments after `--` are passed to `ros2 launch`:

```bash
./docker_vnc/run.sh --launch my_launch.xml -- vehicle_model:=sample_vehicle
```

Without `--launch`, arguments after `--` are run as the command in the container (default: `bash`).

### Other options

| Option                | Description                                                 |
| --------------------- | ----------------------------------------------------------- |
| `--geometry WxH`      | VNC desktop resolution (default: `1920x1200`)                |
| `--display N`         | VNC display number; the port is `5900 + N` (default: `1`)   |
| `--password PASS`     | VNC password (default: `ubuntu`)                             |
| `--x11`               | Use the host X server instead of VNC (Linux only)            |
| `--no-nvidia`         | Disable NVIDIA GPU support (default on macOS)                |
| `--image IMAGE`       | Use another Docker image                                    |
| `--pull-latest-image` | Pull the image before starting                              |

Run `./docker_vnc/run.sh --help` or `./docker_vnc/build.sh --help` for the full list of options.
