# run_driver_updates_hp_now.ps1
# Mise en service - drivers + BIOS + Firmware via HPCMSL - compte SYSTEM

$LogDir = "C:\Logs\wapt-drivers"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$LogFile = Join-Path $LogDir ("hp_update_now_" + (Get-Date -Format "yyyy-MM-dd_HH-mm") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Output $line
    Add-Content -Path $LogFile -Value $line
}

$RegPath      = "HKLM:\SOFTWARE\WAPT\DriverUpdate"
$TracePath    = "HKLM:\SOFTWARE\WAPT\HPSoftpaqs"
$Manufacturer = (Get-WmiObject Win32_ComputerSystem).Manufacturer
if (-not (Test-Path $RegPath))  { New-Item -Path $RegPath  -Force | Out-Null }
if (-not (Test-Path $TracePath)) { New-Item -Path $TracePath -Force | Out-Null }

function Write-Registry {
    param([string]$Status, [string]$Detail, [int]$ExitCode)
    Set-ItemProperty -Path $RegPath -Name "LastRun"      -Value (Get-Date -Format "yyyy-MM-dd HH:mm")
    Set-ItemProperty -Path $RegPath -Name "Manufacturer" -Value $Manufacturer
    Set-ItemProperty -Path $RegPath -Name "LastExitCode" -Value $ExitCode
    Set-ItemProperty -Path $RegPath -Name "LastStatus"   -Value $Status
    Set-ItemProperty -Path $RegPath -Name "LastDetail"   -Value $Detail
    Set-ItemProperty -Path $RegPath -Name "LastLogFile"  -Value $LogFile
}

function Get-InstalledSoftpaqVersion {
    param([string]$Id)
    try {
        return (Get-ItemProperty -Path "$TracePath\$Id" -ErrorAction SilentlyContinue).Version
    } catch {
        return $null
    }
}

function Set-InstalledSoftpaqVersion {
    param([string]$Id, [string]$Version)
    if (-not (Test-Path "$TracePath\$Id")) {
        New-Item -Path "$TracePath\$Id" -Force | Out-Null
    }
    Set-ItemProperty -Path "$TracePath\$Id" -Name "Version"     -Value $Version
    Set-ItemProperty -Path "$TracePath\$Id" -Name "LastInstall" -Value (Get-Date -Format "yyyy-MM-dd HH:mm")
}

$mutex = New-Object System.Threading.Mutex($false, "Global\HPDriverUpdate")
if (-not $mutex.WaitOne(0)) {
    Write-Log "AVERTISSEMENT : Une mise a jour HP est deja en cours. Abandon."
    exit 0
}

try {
    Write-Log "--- Demarrage HPCMSL (mise en service - drivers + BIOS + Firmware) ---"
    Write-Log "Fabricant : $Manufacturer"

    if (-not (Get-Module -ListAvailable -Name HP.Softpaq)) {
        Write-Log "ERREUR : module HPCMSL introuvable. vcte-hpcmsl est-il deploye ?"
        Write-Registry -Status "ERREUR - HPCMSL introuvable" -Detail "Le module HPCMSL est absent." -ExitCode -1
        exit 1
    }

    Import-Module HP.Softpaq

    Write-Log "Recherche des mises a jour disponibles (drivers + BIOS + Firmware)..."
    $softpaqs = Get-HPSoftpaqList -Category Driver,Bios,Firmware,Dock -Characteristic SSM
    Write-Log "Mises a jour trouvees : $($softpaqs.Count)"

    if ($softpaqs.Count -eq 0) {
        Write-Log "Aucune mise a jour disponible."
        Write-Registry -Status "OK - Aucune MAJ necessaire" -Detail "HPCMSL n a rien trouve." -ExitCode 0
        exit 0
    }

    $errors  = 0
    $success = 0
    $skipped = 0

    foreach ($sp in $softpaqs) {
        $installedVersion = Get-InstalledSoftpaqVersion -Id $sp.Id

        if ($installedVersion -eq $sp.Version) {
            Write-Log "  SKIP : $($sp.Name) v$($sp.Version) deja installe"
            $skipped++
            continue
        }

        Write-Log "Installation : $($sp.Name) ($($sp.Id)) v$($sp.Version)..."
        try {
            $output = Get-HPSoftpaq -Number $sp.Id -Action silentinstall -Overwrite yes -ErrorAction SilentlyContinue 2>&1
            $output | ForEach-Object { Write-Log "  $_" }
            Set-InstalledSoftpaqVersion -Id $sp.Id -Version $sp.Version
            Write-Log "  OK : $($sp.Name)"
            $success++
        } catch {
            Write-Log "  ERREUR ignoree : $($sp.Name) - $($_.Exception.Message)"
            $errors++
        }
    }

    Write-Log "Resultats : $success installes, $skipped deja a jour, $errors erreurs"

    if ($success -eq 0 -and $errors -eq 0) {
        Write-Registry -Status "OK - Aucune MAJ necessaire" -Detail "Tous les drivers sont deja a jour." -ExitCode 0
    } elseif ($errors -eq 0) {
        Write-Registry -Status "OK - MAJ installees" -Detail "$success MAJ installees via HPCMSL." -ExitCode 1
    } else {
        Write-Registry -Status "OK - MAJ partielles" -Detail "$success OK, $skipped deja a jour, $errors erreurs." -ExitCode 1
    }

    Write-Log "--- Script termine ---"

} catch {
    Write-Log "ERREUR : $($_.Exception.Message)"
    Write-Registry -Status "ERREUR" -Detail $_.Exception.Message -ExitCode -1
} finally {
    $mutex.ReleaseMutex()
}
