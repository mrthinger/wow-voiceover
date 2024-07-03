# Dockerfile
FROM mysql:8

# Install Xvfb and other dependencies
RUN apt-get update && apt-get install -y \
    xvfb \
    libgl1-mesa-glx \
    libxrender1 \
    libxext6

# Rest of your Dockerfile commands
# ...