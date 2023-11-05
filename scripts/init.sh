#!/bin/bash

# Define ENV vars
STEAM_COMPAT_CLIENT_INSTALL_PATH=/home/steam/Steam

ASA_ROOT_DIR="/home/steam/server/"
INSTALL_TMP_DIR=/home/steam/tmp

PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton8-21/GE-Proton8-21.tar.gz"
PROTON_TGZ="GE-Proton8-21.tar.gz"
PROTON_NAME="GE-Proton8-21"

# Create directories if they do not exist and set permissions
for DIR in "$ASA_ROOT_DIR" "$INSTALL_TMP_DIR" "$STEAM_COMPAT_CLIENT_INSTALL_PATH" "$INSTALL_TMP_DIR" "/home/steam" "$"; do
    if [ ! -d "$DIR" ]; then
        mkdir -p "$DIR"
    fi
    chown -R steam:steam "$DIR"
    chmod -R 755 "$DIR"
done

# Make tmp dir to install proton and other files to temp_dir
[ -d "$INSTALL_TMP_DIR" ] || mkdir -p "$INSTALL_TMP_DIR"

# Download ProtonGE
if [ ! -e "$INSTALL_TMP_DIR/$PROTON_TGZ" ]; then
    wget "$PROTON_URL" -O "$INSTALL_TMP_DIR/$PROTON_TGZ"
fi

# Extract protonGE into steam users Steam path
[ -d "$STEAM_COMPAT_CLIENT_INSTALL_PATH/compatibilitytools.d" ] || sudo -u steam mkdir -p "$STEAM_COMPAT_CLIENT_INSTALL_PATH/compatibilitytools.d"
sudo -u steam tar -x -C "$STEAM_COMPAT_CLIENT_INSTALL_PATH/compatibilitytools.d/" -f "$INSTALL_TMP_DIR/$PROTON_TGZ"

#Install default prefix into game compatdata path
[ -d "$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/compatdata/2430930" ] || sudo -u steam mkdir -p "$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/compatdata/2430930"
sudo -u steam cp "$STEAM_COMPAT_CLIENT_INSTALL_PATH/compatibilitytools.d/$PROTON_NAME/files/share/default_pfx" "$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/compatdata/2430930" -r

# Adjust permissions for build_id.txt if it exists
BUILD_ID_FILE="$ASA_DIR/build_id.txt"
if [ -f "$BUILD_ID_FILE" ]; then
    chown steam:steam "$BUILD_ID_FILE"
fi

# Continue with the main application
exec /home/steam/scripts/launch_ASA.sh