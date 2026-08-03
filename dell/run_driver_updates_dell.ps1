# run_driver_updates_dell.ps1
# Tache planifiee WAPT-DriverUpdate-Dell - compte SYSTEM

$LogDir = "C:\Logs\wapt-drivers"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$LogFile = Join-Path $LogDir ("dell_update_" + (Get-Date -Format "yyyy-MM-dd_HH-mm") + ".log")

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

Write-Log "--- Demarrage Dell Command Update ---"
Write-Log "Fabricant : $Manufacturer"

$dcu = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"

if (Test-Path $dcu) {
    Write-Log "Lancement Dell Command Update..."
    $proc = Start-Process -FilePath $dcu -ArgumentList `
    "/applyUpdates", "-updateType=driver,firmware,application", "-reboot=disable" `
    -Wait -PassThru -NoNewWindow

    Write-Log "Dell termine. Code retour : $($proc.ExitCode)"

    switch ($proc.ExitCode) {
        0    { $status = "OK - Aucune MAJ necessaire" ; $detail = "Dell Command Update n a rien trouve." }
        1    { $status = "OK - MAJ installees"        ; $detail = "Dell Command Update a installe des MAJ." }
        2    { $status = "OK - Redemarrage requis"    ; $detail = "Des MAJ necessitent un redemarrage." }
        102  { $status = "OK - Redemarrage en attente" ; $detail = "Un redemarrage est requis avant de pouvoir installer de nouvelles MAJ." }
        500  { $status = "OK - Aucune MAJ disponible"   ; $detail = "Aucune mise a jour disponible pour ce modele." }
        default { $status = "ERREUR - Code $($proc.ExitCode)" ; $detail = "Dell Command Update a retourne un code inattendu." }
    }
} else {
    Write-Log "ERREUR : dcu-cli.exe introuvable a $dcu"
    $status = "ERREUR - dcu-cli.exe introuvable"
    $detail = "Le fichier $dcu est absent. tis-dell-command-update-uwp est-il deploye ?"
    $proc   = [PSCustomObject]@{ ExitCode = -1 }
}

Write-Registry -Status $status -Detail $detail -ExitCode $proc.ExitCode
Write-Log "Registre mis a jour : $status"
Write-Log "--- Script termine ---"
