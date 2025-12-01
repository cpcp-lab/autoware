# Autoware Docker Images Extended with VNC Environment

## Tested Environment

- OS: macOS 13.7.6
- Docker: version 27.4.0
- [`autowarefoundation/autoware`](https://github.com/autowarefoundation/autoware): `cd1bb25`

## Usage

0. Assumed to be located within the Autoware meta repository ([`autowarefoundation/autoware`](https://github.com/autowarefoundation/autoware)).
   ```shell
   $ pwd
   .../autoware
   $ ls
   ... README.md ... docker/ docker_vnc/ ... setup.cfg src/ ...
   ```
1. Docker image building should be done with script `build.sh`.
   ```shell
   $ ./docker_vnc/build.sh --help
   Usage: build_vnc.sh [OPTIONS]
   Options:
     --help          Display this help message
     -h              Display this help message
     --cuda          Enable CUDA support
     --platform      Specify the platform (default: current platform)
     --devel-only    Build devel image only
   
   Note: The --platform option should be one of 'linux/amd64' or 'linux/arm64'
   ```
2. Build of a development image:
   ```shell
   $ ./docker_vnc/build_vnc.sh --devel-only
   ...
   ```
3. Container invocation example:
   ```shell
   $ docker run -it --rm -p 5901:5901 -e LOCAL_UID=501 -e LOCAL_GID=20 -e LOCAL_USER=a_user -e LOCAL_GROUP=a_group -v ./map:/autoware_map:ro -v ./data:/autoware_data:rw -v .:/workspace:rw ghcr.io/autowarefoundation/autoware:universe-devel-vnc /bin/bash
   ...
   a_user@[CID]:/autoware$ vncserver :1 -geometry 1920x1200 -depth 24 -localhost no
   ...
   
   New Xtigervnc server '[CID]:1 (a_user)' on port 5901 for display :1.
   Use xtigervncviewer -SecurityTypes VncAuth,TLSVnc -passwd /home/a_user/.vnc/passwd [CID]:1 to connect to the VNC server.
   
   (Background execution)
   a_user@[CID]:/autoware$
   ```
4. Now, you can access port 5901 of `localhost` e.g. with Screen Sharing app and access the desktop environment.
    1. Open `Go -> Connect To Server...` in Finder.
    2. Input `vnc://localhost:5901` and press Connect.
    3. Input the password `ubuntu`.
5. Termination of the vnc server.
   ```shell
   a_user@[CID]:/autoware$ vncserver -kill :1
   (Killing the background job)
   ```
