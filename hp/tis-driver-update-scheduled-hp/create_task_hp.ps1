# create_task_hp.ps1
$TaskName   = "WAPT-DriverUpdate-HP"
$ScriptPath = "C:\Scripts\wapt\run_driver_updates_hp.ps1"

Write-Output "Debut creation tache : $TaskName"

try {
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NonInteractive -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

    $triggerWeekly = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "14:00"

    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -RunOnlyIfNetworkAvailable `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew

    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask `
        -TaskName  $TaskName `
        -Action    $action `
        -Trigger   $triggerWeekly `
        -Settings  $settings `
        -Principal $principal `
        -Force `
        -ErrorAction Stop

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Output "Tache '$TaskName' creee avec succes."
        exit 0
    } else {
        Write-Output "ERREUR : tache non trouvee apres creation."
        exit 1
    }
} catch {
    Write-Output "EXCEPTION : $($_.Exception.Message)"
    Write-Output "StackTrace : $($_.ScriptStackTrace)"
    exit 1
}
