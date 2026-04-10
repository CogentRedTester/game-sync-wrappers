#!/bin/bash

# Check if ludusavi is available
if command -v ludusavi >/dev/null 2>&1; then
    echo 'Using system Ludusavi'

# If the flatpak version is available, use that.
elif flatpak run com.github.mtkennerly.ludusavi -V >/dev/null 2>&1; then
    echo 'Using flatpak Ludusavi'
    ludusavi() {
        flatpak run com.github.mtkennerly.ludusavi "$@"
    }

else
    echo "Ludusavi not found, aborting script."

    # Show GUI error messages
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --title "ludasavi-cloud-sync.sh" --error "Ludusavi not found, aborting script."
    elif command -v zenity >/dev/null 2>&1; then
        zenity --error --text="Ludusavi not found, aborting script."
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send -w "Error" "Ludusavi not found, aborting script."
    fi

    exit 1
fi

ludusavi_game="$1"
ludusavi_backup_dir=$(ludusavi config show --api | jq -r '.backup.path')

shift

# Create a local backup of the game before restoring files from the cloud to provide a recovery option in case of save conflicts
ludusavi backup --path "${ludusavi_backup_dir}/.backup" --full-limit 2 --force --no-cloud-sync "$ludusavi_game"

# Overwrite local saves with cloud saves and restore the latest save file
ludusavi cloud download --force "$ludusavi_game"
ludusavi restore --force --gui --ask-downgrade --no-cloud-sync "$ludusavi_game"

# Run the game
"$@"

# Back up the game and overwrite the cloud saves with the local saves
ludusavi backup --force --gui --no-cloud-sync "$ludusavi_game"
ludusavi cloud upload --force "$ludusavi_game"
