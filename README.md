# Docker.ARK-ASA-Server
A docker container for ARK: Survival Ascendent's dedicated server from SteamCMD.
This container uses ProtonGE instead of WINE(unlike a few others ive seen on DockerHub) and therefore is theoretically more stable. However testing is for sure needed.

The QUERY port will, currently, always be the PRIMARY_PORT plus one.
You may set SERVER_PASSWORD to blank/nothing if you wish to have no password on the server.

**PLEASE change the admin password!**

An example docker-compose is as follows:
```version: '2.4'

services:
  ark-asa-server:
    image: stimzrx/ark-asa-server:latest
    container_name: ark-asa-server
    restart: unless-stopped
    environment:
      - MAP_NAME=TheIsland
      - SESSION_NAME=DockerServer
      - SERVER_ADMIN_PASSWORD=CHANGE#ME!asdf
      - SERVER_PASSWORD=LeaveMeBlankForNoPassword!
      - PRIMARY_PORT=7777
      - MAX_PLAYERS=20
      - BATTLEYE=false
      - MODS_LIST=930526
    ports:
      - "7777:7777/tcp"
      - "7777:7777/udp"
      - "7778:7778/tcp"
      - "7778:7778/udp"
    volumes:
      - "./data/ARK:/home/steam/server"
      - "./data/tmp:/home/steam/tmp"
    cpuset: 2-5  # EXAMPLE: pins CPUs to threads 3-6
    memswap_limit: 16G
    mem_limit: 14G  # Setting RAM/memory limit to 14GB
```

This project took high inspiration from a number of other projects including, but not limited to:
Acekorneya, SteamCMD, and cdp1337

