$TaskName  = "WAPT-DriverUpdate-HP-Now"
$ScriptDst = "C:\Scripts\wapt\run_driver_updates_hp_now.ps1"

$action    = New-ScheduledTaskAction -Execute "powershell.exe" `
             -Argument "-NonInteractive -NoProfile -ExecutionPolicy Bypass -File `"$ScriptDst`""
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $action `
    -Principal $principal -Force | Out-Null

Start-ScheduledTask -TaskName $TaskName
Write-Output "Tache $TaskName creee et declenchee."
