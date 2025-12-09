FROM public.ecr.aws/docker/library/ubuntu:22.04

# Install basic dependencies
RUN apt-get update && \
    apt-get install -y \
    buildah \
    curl \
    git \
    unzip \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Configure buildah for rootless mode
RUN mkdir -p /etc/containers && \
    echo '[storage]' > /etc/containers/storage.conf && \
    echo 'driver = "vfs"' >> /etc/containers/storage.conf

# Set working directory
WORKDIR /codebuild

# Default command
CMD ["/bin/bash"]
