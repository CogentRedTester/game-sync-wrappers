@echo off

REM Show GUI and commandline error messages
:err
    setlocal enabledelayedexpansion
        set "msg=%~1"

        >&2 echo !msg!

        powershell -NoProfile -Command ^
            "Add-Type -AssemblyName System.Windows.Forms; ^
            [System.Windows.Forms.MessageBox]::Show('!msg!','ludusavi-cloud-sync.ps1','OK','Error')"

    endlocal
exit /b 0


REM Check if Ludusavi is available
where ludusavi >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    call:err "Ludusavi not found, aborting script."
    exit /b 1
) else (
    echo Using system Ludusavi
)

set "ludusavi_game=%~1"

REM Build game arguments (all remaining arguments after %2)
REM Taken from https://stackoverflow.com/a/761658
set "game_exe=%~2"
set game_args=%3
:loop
    shift
    if [%3]==[] goto afterloop
    set game_args=%game_args% %3
    goto loop
:afterloop

REM Uses PowerShell to get Ludusavi backup path
for /f "usebackq delims=" %%B in (`powershell -NoProfile -Command ^
    "(ludusavi config show --api | ConvertFrom-Json).backup.path"`) do set "ludusavi_backup_dir=%%B"
for /f "usebackq delims=" %%B in (`powershell -NoProfile -Command ^
    "(ludusavi config show --api | ConvertFrom-Json).backup.path"`) do set "ludusavi_cloud_dir=%%B"


set "local_sync_dir=%ludusavi_backup_dir%/.cloud-sync"
set "cloud_sync_dir=%ludusavi_cloud_dir%.cloud-sync"

REM # Create a local backup of the game before restoring files from the cloud to provide a recovery option in case of save conflicts
ludusavi backup --path "%local_sync_dir%.backup" --full-limit 2 --force --no-cloud-sync "%ludusavi_game%"

REM Overwrite local saves with cloud saves
ludusavi cloud download --local "%local_sync_dir%" --cloud "%cloud_sync_dir%" --force "%ludusavi_game%"
if ERRORLEVEL EQU 0 (
    set cloud_sync=0
) else (
    set cloud_sync=1
    call:err "Failed to download save from the cloud, will not attempt upload after game closes."
)

REM Restore the latest save file
ludusavi restore --path "%local_sync_dir%" --force --gui --ask-downgrade --no-cloud-sync  "%ludusavi_game%"

REM Run the game
"%game_exe%" %game_args%

REM Back up the game and overwrite the cloud saves with the local saves
ludusavi backup --path "%local_sync_dir%" --force --gui --no-cloud-sync  "%ludusavi_game%"

if %cloud_sync% EQU 0 (
    ludusavi cloud upload --local "%local_sync_dir%" --cloud "%cloud_sync_dir%" --force "%ludusavi_game%"
)
