# Use an image that has Wine installed to run Windows applications
FROM ubuntu:23.10

# Args
ARG PUID=1001
ARG PGID=1001
ARG DEBIAN_FRONTEND=noninteractive

# Environment variables
ENV PUID ${PUID}
ENV PGID ${PGID}
ENV SCRIPTS_DIR=/home/steam/scripts

# Switch user to root
USER root

# Make new 'steam' user
RUN useradd -m -U steam

# Prequiset requirements for installing everything
RUN dpkg --add-architecture i386 && apt update && apt install -y software-properties-common apt-transport-https dirmngr ca-certificates curl wget sudo

# Update APT
RUN apt update

# Add SteamCMD Prompt Answers
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo steam steam/question select "I AGREE" | debconf-set-selections \
 && echo steam steam/license note '' | debconf-set-selections

# Install lib32gcc, steamcmd, and jq
RUN apt install -y lib32gcc-s1 steamcmd jq

#Reset back to normal bash shell
SHELL ["/bin/bash", "-c"]

# Link steamcmd binary
RUN ln -s /usr/games/steamcmd /usr/bin/steamcmd

# Set the working directory
WORKDIR /home/steam/server/

# Copy scripts folder into the container
COPY scripts/ /home/steam/scripts

# Remove Windows-style carriage returns from the scripts
RUN sed -i 's/\r//' /home/steam/scripts/*.sh

# Make scripts executable
RUN chmod +x /home/steam/scripts/*.sh

# Set the entry point
ENTRYPOINT ["/home/steam/scripts/init.sh"]