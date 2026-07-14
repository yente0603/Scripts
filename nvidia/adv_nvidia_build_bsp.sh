#!/bin/bash
# This script build Advantech Nvidia solution with Jetpack 6.2 (L4T 36.4.3) as example.
JETPACK_VERSION="risc_nvidia_jetson_36.4.3"
XML="air021a1_ubuntu22.04-jp6.2_v3.0.0_kernel-5.15.148_orin-nx+orin-nano.xml"
IMAGE="AIR-021_JP6.2_V2.0.0_20260225.tar.gz"

docker_install() {
    # Uninstall old version
    sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)

    # Set up Docker's apt repository and add Docker's official GPG key
    sudo apt-get update
    sudo apt-get install ca-certificates curl -y
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update

    # Install the Docker packages
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    sudo systemctl start docker

    # Verify that the installation is successful by running the hello-world image
    # sudo docker run hello-world
}

command -v docker &> /dev/null || docker_install

# 1. Common build environment
# 1-1. Docker container
# Currently we adopt Docker as the build environment. Use the advrisc/u20.04-nvlbv2 container to match the JetPack 6.2 toolchain.
# If you rely on legacy flows, the advrisc/u18.04-imx8lbv1 image remains available but is not required for JetPack 6.2.
docker pull advrisc/u20.04-nvlbv2

# 1-2. Run container
# Launch a container and mount your BSP workspace:
sudo docker run -it --name jetson_linux_risc \
  -v /home/bsp/myLinux:/home/adv/BSP:rw \
  --privileged advrisc/u20.04-nvlbv2:latest /bin/bash
# Inside the container adjust ownership if needed:
sudo chown adv:adv -R BSP

sudo apt-get install qemu-user-static
# 1-3. Host dependency
# Install helper tools on the host when you encounter Exec format error or similar issues
sudo apt-get update 
sudo apt-get install -y flex bison qemu-user-static

# 1-4. Workspace initialisation
# Getting Linux Source Code
export GIT_SSL_NO_VERIFY=1
cd ~/BSP
mkdir -p jetson_linux_risc
cd jetson_linux_risc
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# 2. Getting Linux source code
repo init -u https://AIM-Linux@dev.azure.com/AIM-Linux/${JETPACK_VERSION}/_git/manifest -m ${XML}
repo sync

echo "--------------------------------------------------------"
echo ">>> Source code download completed!"
echo ">>> Configuration: ${XML}"
echo ">>> You can now make your modifications to the BSP files."
echo ">>> Once finished, press [Enter] in this terminal to continue..."
echo "--------------------------------------------------------"
read -r -p "Press [Enter] to continue..."

# 3. Build Image
echo -n "Will start to flash BSP in 3 seconds... "
sleep 3
sudo ./scripts/build_release.sh

echo "--------------------------------------------------------"
echo ">>> BSP build completed!"
echo ">>> You can now make your modifications to the BSP files."
echo ""
echo ">>> The flash command varies depending on your Advantech board."
echo ">>> Please refer to:"
echo ">>>   1. The User Manual on the Advantech official website."
echo ">>>   2. AIM-Linux documentation for your specific hardware platform."
echo "--------------------------------------------------------"