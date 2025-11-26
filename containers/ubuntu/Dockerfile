FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Copy the installation scripts from repo root
COPY /Repos/devops/scripts  /workspace/scripts

# Make all shell scripts executable
RUN find /workspace/scripts -name "*.sh" -type f -exec chmod +x {} +

# Default command - run bash so we can test interactively if needed
CMD ["/bin/bash"]