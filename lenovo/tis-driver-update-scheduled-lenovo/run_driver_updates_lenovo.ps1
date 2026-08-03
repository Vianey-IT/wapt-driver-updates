# run_driver_updates_lenovo.ps1
# Tache planifiee WAPT-DriverUpdate-Lenovo - drivers uniquement via LSUClient - compte SYSTEM

$LogDir = "C:\Logs\wapt-drivers"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$LogFile = Join-Path $LogDir ("lenovo_update_" + (Get-Date -Format "yyyy-MM-dd_HH-mm") + ".log")

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

# Mutex pour eviter conflit avec le paquet now
$mutex = New-Object System.Threading.Mutex($false, "Global\LenovoDriverUpdate")
if (-not $mutex.WaitOne(0)) {
    Write-Log "AVERTISSEMENT : Une mise a jour Lenovo est deja en cours. Abandon."
    exit 0
}

try {
    Write-Log "--- Demarrage LSUClient (scheduled - drivers uniquement) ---"
    Write-Log "Fabricant : $Manufacturer"

    # Vérifier que LSUClient est disponible
    if (-not (Get-Module -ListAvailable -Name LSUClient)) {
        Write-Log "ERREUR : module LSUClient introuvable. vcte-lsuclient-lenovo est-il deploye ?"
        Write-Registry -Status "ERREUR - LSUClient introuvable" -Detail "Le module LSUClient est absent." -ExitCode -1
        exit 1
    }

    Import-Module LSUClient

    Write-Log "Recherche des mises a jour disponibles (hors BIOS)..."
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended -and $_.Type -ne 'BIOS' }

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
    $results = $updates | Install-LSUpdate -Verbose 2>&1
    $results | ForEach-Object { Write-Log $_ }

    # Vérifier si un redémarrage est requis parmi les résultats
    $rebootRequired = $results | Where-Object { $_ -match "reboot|restart|3010" }

    if ($rebootRequired) {
        $status = "OK - Redemarrage requis"
        $detail = "Des MAJ drivers necessitent un redemarrage."
        $exitCode = 3010
    } else {
        $status = "OK - MAJ installees"
        $detail = "LSUClient a installe des MAJ drivers."
        $exitCode = 1
    }

    Write-Registry -Status $status -Detail $detail -ExitCode $exitCode
    Write-Log "Registre mis a jour : $status"
    Write-Log "--- Script termine ---"

} catch {
    Write-Log "ERREUR : $($_.Exception.Message)"
    Write-Registry -Status "ERREUR - $($_.Exception.Message)" -Detail $_.Exception.Message -ExitCode -1
} finally {
    $mutex.ReleaseMutex()
}
