#!/bin/bash

# Initialize environment variables
initialize_variables() {
    export DISPLAY=:0.0
    USERNAME=anonymous
    APPID=2430930
    STEAM_COMPAT_CLIENT_INSTALL_PATH=/home/steam/Steam
    STEAM_COMPAT_DATA_PATH="$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/compatdata/2430930"
    SERVER_DIR=/home/steam/server
    SHOOTERGAME_DIR="$SERVER_DIR/ShooterGame"
    DEST_DIR="$SHOOTERGAME_DIR/Binaries/Win64/"
    BUILD_ID_FILE="$SHOOTERGAME_DIR/build_id.txt"
    TAIL_PID=-1

    #Initialize ports
    if [[ -z $PRIMARY_PORT ]]; then
        ASA_PRIMARY_PORT=$PRIMARY_PORT
        ASA_SECONDARY_PORT=$(($PRIMARY_PORT + 1))
        PRINTOUT_SECTION_PORTS="?Port=${ASA_PRIMARY_PORT}?QueryPort=${ASA_SECONDARY_PORT}"
    else
        PRINTOUT_SECTION_PORTS=""
    fi

    if [[ $BATTLEYE = "false" ]]; then
        BATTLEYE_ENABLED_LOG="NO"
    else
        BATTLEYE_ENABLED_LOG="YES"
    fi

    ASA_SERVER_ARGS="?SessionName=${SESSION_NAME}${PRINTOUT_SECTION_PORTS}?MaxPlayers=${MAX_PLAYERS}?ServerAdminPassword=${SERVER_ADMIN_PASSWORD}$( [[ -n $SERVER_PASSWORD ]] && echo "?ServerPassword=$SERVER_PASSWORD" ) -mods=${MODS_LIST}$( [[ $BATTLEYE_ENABLED_LOG = "NO" ]] && echo " -NoBattlEye" )"
}

# Determine the map path based on environment variable
determine_map_path() {
    if [ "$MAP_NAME" = "TheIsland" ]; then
        MAP_PATH="TheIsland_WP"
    elif [ "$MAP_NAME" = "ScorchedEarth" ]; then
        MAP_PATH="ScorchedEarth_WP"
    else
        echo "Invalid MAP_NAME. Defaulting to The Island."
        MAP_PATH="TheIsland_WP"
    fi
}

install_server() {
    local saved_build_id

    # Try to retrieve the saved build ID
    if [ -f "$BUILD_ID_FILE" ]; then
        saved_build_id=$(cat "$BUILD_ID_FILE")
    else
        echo "No saved build ID found. Will proceed to install the server."
        saved_build_id=""
    fi

    # Get the current build ID
    local current_build_id
    current_build_id=$(get_current_build_id)
    if [ -z "$current_build_id" ]; then
        echo "Unable to retrieve current build ID. Cannot proceed with installation."
        return 1
    fi

    # Compare the saved build ID with the current build ID
    if [ "$saved_build_id" != "$current_build_id" ]; then
        echo "Saved build ID ($saved_build_id) does not match current build ID ($current_build_id). Installing or updating the server..."
        sudo -u steam /usr/bin/steamcmd +force_install_dir /home/steam/server +login anonymous +app_update "$APPID" +@sSteamCmdForcePlatformType windows +quit

        # Save the new build ID
        save_build_id "$current_build_id"
    else
        echo "Server is up to date. Skipping installation."
    fi
}



 # Get the current build ID from SteamCMD API
get_current_build_id() {
    local build_id
    build_id=$(curl -sX GET "https://api.steamcmd.net/v1/info/$APPID" | jq -r ".data.\"$APPID\".depots.branches.public.buildid")
    
    # Check if the build ID is valid
    if [ -z "$build_id" ] || [ "$build_id" = "null" ]; then
        echo "Unable to retrieve current build ID."
        return 1
    fi
    
    echo "$build_id"
    return 0
}

# Check for updates and update the server if necessary
update_server() {
    CURRENT_BUILD_ID=$(get_current_build_id)
    
    if [ -z "$CURRENT_BUILD_ID" ]; then
        echo "Unable to retrieve current build ID. Skipping update check."
        return
    fi

    if [ ! -f "$BUILD_ID_FILE" ]; then
        echo "No previous build ID found. Assuming first run and skipping update check."
        save_build_id "$CURRENT_BUILD_ID"
        return
    fi

    PREVIOUS_BUILD_ID=$(cat "$BUILD_ID_FILE")
    if [ "$CURRENT_BUILD_ID" != "$PREVIOUS_BUILD_ID" ]; then
        echo "Update available (Previous: $PREVIOUS_BUILD_ID, Current: $CURRENT_BUILD_ID). Installing update..."
        sudo -u steam /usr/bin/steamcmd +force_install_dir /home/steam/server +login anonymous +app_update "$APPID" +@sSteamCmdForcePlatformType windows +quit
        save_build_id "$CURRENT_BUILD_ID"
    else
        echo "Continuing with server start."
    fi
}

# Save the build ID to a file and change ownership to the games user
save_build_id() {
    local build_id=$1
    echo "$build_id" > "$BUILD_ID_FILE"
    chown steam:steam "$BUILD_ID_FILE"
    echo "Saved build ID: $build_id"
}

# Find the last "Log file open" entry and return the line number
find_new_log_entries() {
    LOG_FILE="$SHOOTERGAME_DIR/Saved/Logs/ShooterGame.log"
    LAST_ENTRY_LINE=$(grep -n "Log file open" "$LOG_FILE" | tail -1 | cut -d: -f1)
    echo $((LAST_ENTRY_LINE + 1)) # Return the line number after the last "Log file open"
}

# Start the server and tail the log file
start_server() {
    
    # Check if the log file exists and rename it to archive
    local old_log_file="$SHOOTERGAME_DIR/Saved/Logs/ShooterGame.log"
    if [ -f "$old_log_file" ]; then
        local timestamp=$(date +%F-%T)
        mv "$old_log_file" "${old_log_file}_$timestamp"
    fi

    echo "Server Starting..."
    echo "Start Args: $ASA_SERVER_ARGS"
    echo "BattlEye Enabled? $BATTLEYE_ENABLED_LOG"
    
    sudo -u steam STEAM_COMPAT_CLIENT_INSTALL_PATH=/home/steam/Steam STEAM_COMPAT_DATA_PATH="$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/compatdata/2430930" $STEAM_COMPAT_CLIENT_INSTALL_PATH/compatibilitytools.d/GE-Proton8-21/proton run "$SHOOTERGAME_DIR/Binaries/Win64/ArkAscendedServer.exe" $MAP_PATH?listen$ASA_SERVER_ARGS -servergamelog -servergamelogincludetribelogs -ServerRCONOutputTribeLogs -NotifyAdminCommandsInChat -useallavailablecores -usecache -nosteamclient -game -server -log 2>/dev/null &
    # Server PID
    SERVER_PID=$!

    # Start the logger via function call
    start_logger

    # Wait for the server to exit
    wait $SERVER_PID

    # Kill the tail process when the server stops
    if [ $TAIL_PID -ne -1 ]
    then
        kill $TAIL_PID
    fi
}

start_logger() {
    # Wait for the log file to be created with a timeout
    LOG_FILE="$SHOOTERGAME_DIR/Saved/Logs/ShooterGame.log"
    TIMEOUT=180
    while [[ ! -f "$LOG_FILE" && $TIMEOUT -gt 0 ]]; do
        sleep 1
        ((TIMEOUT--))
    done
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Log file not found after waiting. Please check server status."
        return
    fi
    
    # Find the line to start tailing from
    START_LINE=$(find_new_log_entries)

    # Tail the ShooterGame log file starting from the new session entries
    tail -n +"$START_LINE" -F "$SHOOTERGAME_DIR/Saved/Logs/ShooterGame.log" &
    TAIL_PID=$!
}

# Main function
main() {
    initialize_variables
    install_server
    update_server
    determine_map_path
    start_server
    sleep infinity
}

main