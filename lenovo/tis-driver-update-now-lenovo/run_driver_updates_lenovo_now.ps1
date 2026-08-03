# run_driver_updates_lenovo_now.ps1
# Mise en service - drivers + BIOS via LSUClient - compte SYSTEM

$LogDir = "C:\Logs\wapt-drivers"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$LogFile = Join-Path $LogDir ("lenovo_update_now_" + (Get-Date -Format "yyyy-MM-dd_HH-mm") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Output $line
    Add-Content -Path $LogFile -Value $line
}

$RegPath      = "HKLM:\SOFTWARE\WAPT\DriverUpdate"
$Manufacturer = (Get-WmiObject Win32_ComputerSystem).Manufacturer
if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }

function Write-Registry {
    param([string]$Status, [string]$Detail, [int]$ExitCode)
    Set-ItemProperty -Path $RegPath -Name "LastRun"      -Value (Get-Date -Format "yyyy-MM-dd HH:mm")
    Set-ItemProperty -Path $RegPath -Name "Manufacturer" -Value $Manufacturer
    Set-ItemProperty -Path $RegPath -Name "LastExitCode" -Value $ExitCode
    Set-ItemProperty -Path $RegPath -Name "LastStatus"   -Value $Status
    Set-ItemProperty -Path $RegPath -Name "LastDetail"   -Value $Detail
    Set-ItemProperty -Path $RegPath -Name "LastLogFile"  -Value $LogFile
}

$mutex = New-Object System.Threading.Mutex($false, "Global\LenovoDriverUpdate")
if (-not $mutex.WaitOne(0)) {
    Write-Log "AVERTISSEMENT : Une mise a jour Lenovo est deja en cours. Abandon."
    exit 0
}

try {
    Write-Log "--- Demarrage LSUClient (mise en service - drivers + BIOS) ---"
    Write-Log "Fabricant : $Manufacturer"

    Import-Module LSUClient

    Write-Log "Recherche des mises a jour disponibles..."
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended }

    if ($updates.Count -eq 0) {
        Write-Log "Aucune mise a jour disponible."
        Write-Registry -Status "OK - Aucune MAJ necessaire" -Detail "LSUClient n a rien trouve." -ExitCode 0
        exit 0
    }

    Write-Log "Mises a jour trouvees : $($updates.Count)"
    foreach ($u in $updates) {
        Write-Log "  - $($u.Title) [$($u.Type)] v$($u.Version)"
    }

    Write-Log "Telechargement des mises a jour..."
    $updates | Save-LSUpdate -Verbose 2>&1 | ForEach-Object { Write-Log $_ }

    Write-Log "Installation des mises a jour..."
    $updates | Install-LSUpdate -Verbose 2>&1 | ForEach-Object { Write-Log $_ }

    $biosReg = "HKLM:\Software\LSUClient\BIOSUpdate"
    if (Test-Path $biosReg) {
        $action = (Get-ItemProperty $biosReg).ActionNeeded
        Write-Log "BIOS installe - action requise : $action"
        Write-Registry -Status "OK - MAJ installees - $action requis" -Detail "LSUClient a installe des MAJ BIOS/drivers." -ExitCode 3010
    } else {
        Write-Registry -Status "OK - MAJ installees" -Detail "LSUClient a installe des MAJ." -ExitCode 1
    }

    Write-Log "--- Script termine ---"

} catch {
    Write-Log "ERREUR : $($_.Exception.Message)"
    Write-Registry -Status "ERREUR" -Detail $_.Exception.Message -ExitCode -1
} finally {
    $mutex.ReleaseMutex()
}
