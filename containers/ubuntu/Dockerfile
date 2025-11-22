FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /workspace

# Copy the installation script (will be copied from parent directory during build)
COPY node_python.sh /workspace/node_python.sh

# Make the script executable
RUN chmod +x /workspace/node_python.sh

# Default command - run bash so we can test interactively if needed
CMD ["/bin/bash"]
