# Test environment for OVH provisioning scripts
# Simplified Ubuntu 24.04 for testing (Docker-in-Docker excluded)

FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install basic utilities needed for provisioning
RUN apt-get update && \
    apt-get install -y \
    curl \
    wget \
    sudo \
    ca-certificates \
    gnupg \
    lsb-release \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create or configure ubuntu user for testing (simulates ubuntu user in OVH)
RUN if ! id ubuntu >/dev/null 2>&1; then useradd -m -s /bin/bash ubuntu; fi && \
    echo "ubuntu:ubuntu" | chpasswd && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set working directory
WORKDIR /root

# Keep container running for testing
CMD ["/bin/bash", "-c", "tail -f /dev/null"]
