# Check if Ludusavi is available
function Get-LudusaviCommand {
    if (Get-Command ludusavi -ErrorAction SilentlyContinue) {
        Write-Host "Using system Ludusavi"
        return "ludusavi"
    }
    elseif (Get-Command "flatpak" -ErrorAction SilentlyContinue) {
        $flatpakCheck = & flatpak run com.github.mtkennerly.ludusavi --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Using flatpak Ludusavi"
            return { param($args) & flatpak run com.github.mtkennerly.ludusavi @args }
        }
    }

    Write-Host "Ludusavi not found, aborting script." -ForegroundColor Red

    # GUI notifications (Windows alternative using PowerShell)
    if (Get-Command msg -ErrorAction SilentlyContinue) {
        msg * "Ludusavi not found, aborting script."
    } elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
        [System.Windows.Forms.MessageBox]::Show("Ludusavi not found, aborting script.","ludusavi-cloud-sync.ps1",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    }

    pause
    exit 1
}

# Main script starts here
Add-Type -AssemblyName System.Windows.Forms

$ludusavi = Get-LudusaviCommand

# Get game argument
$ludusavi_game = $args[0]
$game_exe = $args[1]
$args = $args[2..($args.Length-1)]

# Get backup path from Ludusavi config
$ludusavi_backup_dir = & $ludusavi config show --api | ConvertFrom-Json | Select-Object -ExpandProperty backup | Select-Object -ExpandProperty path

# Creates a local backup before restoring
& $ludusavi backup --path "$ludusavi_backup_dir\.backup" --full-limit 2 --force --no-cloud-sync $ludusavi_game

# Restore cloud saves
& $ludusavi cloud download --force $ludusavi_game
& $ludusavi restore --force --gui --ask-downgrade --no-cloud-sync $ludusavi_game

# Run the game
& $game_exe @args

# Backup after playing and upload to cloud
& $ludusavi backup --force --gui --no-cloud-sync $ludusavi_game
& $ludusavi cloud upload --force $ludusavi_game