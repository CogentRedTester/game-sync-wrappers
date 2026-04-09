@echo off
REM Check if Ludusavi is available
where ludusavi >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Ludusavi is not installed or not in PATH.
    powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Ludusavi not found, aborting script.','ludusavi-cloud-sync.ps1',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)"
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

REM # Create a local backup of the game before restoring files from the cloud to provide a recovery option in case of save conflicts
ludusavi backup --path "%ludusavi_backup_dir%/.backup" --full-limit 2 --force --no-cloud-sync "%ludusavi_game%"

REM Overwrite local saves with cloud saves and restore the latest save file
ludusavi cloud download --force "%ludusavi_game%"
ludusavi restore --force --gui --ask-downgrade --no-cloud-sync  "%ludusavi_game%"

REM Run the game
"%game_exe%" %game_args%

REM Back up the game and overwrite the cloud saves with the local saves
ludusavi backup --force --gui --no-cloud-sync  "%ludusavi_game%"
ludusavi cloud upload --force "%ludusavi_game%"
