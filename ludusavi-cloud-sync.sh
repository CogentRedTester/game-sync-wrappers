#!/bin/bash

# Show GUI and commandline error messages
err() {
    echo "$1" >&2

    if command -v kdialog >/dev/null 2>&1; then
        kdialog --title "ludasavi-cloud-sync.sh" --error "$1"
    elif command -v zenity >/dev/null 2>&1; then
        zenity --error --text="$1"
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send -w "Error" "$1"
    fi
}

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
    err "Ludusavi not found, aborting script."
    exit 1
fi

ludusavi_game="$1"
ludusavi_backup_dir=$(ludusavi config show --api | jq -r '.backup.path')

# Create a local backup of the game before restoring files from the cloud to provide a recovery option in case of save conflicts
ludusavi backup --path "${ludusavi_backup_dir}/.backup" --full-limit 2 --force --no-cloud-sync "$ludusavi_game"

# Overwrite local saves with cloud saves
if timeout 10s $ludusavi cloud download --local "$local_sync_dir" --cloud "$cloud_sync_dir" --force "$ludusavi_game"; then
    cloud_sync=0
else
    err "Failed to download save from the cloud, will not attempt upload after game closes."
    cloud_sync=1
fi

# Restore the latest save file
ludusavi restore --force --gui --ask-downgrade --no-cloud-sync "$ludusavi_game"

# Run the game
shift
"$@"

# Back up the game and overwrite the cloud saves with the local saves
ludusavi backup --force --gui --no-cloud-sync "$ludusavi_game"

if [ "$cloud_sync" -eq 0 ]; then
    ludusavi cloud upload --force "$ludusavi_game"
fi
