$TaskName = "Log Modem Status"

### Get Schedule Task Properties
$Task = Get-ScheduledTask -TaskName $TaskName
$Task | Format-List *


### Get Schedule Task history
$TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
$TaskInfo


### Start a Task
Start-ScheduledTask -TaskName $TaskName


### Create a new Task
$AppDir = "C:\Users\mrdra\OneDrive\Lobby\Arris_Cable_Modem"
$AppCmd = "$AppDir\Get-ModemStatus.ps1"
$AppArgs = "-LogDir '$AppDir\logs'"
$ActionParameters = @{
    Execute  = "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe"
    Argument = "-NonInteractive -ExecutionPolicy Bypass -File '$AppCmd' $AppArgs"
}
$Action = New-ScheduledTaskAction @$ActionParameters

$Trigger =  New-ScheduledTaskTrigger -Daily -At "1:00AM"

$TaskName = "Log Modem Test"
$TaskDescription= @"
Retrieve the signal levels of the cable modem channels.
Log the data and append the statistics to a csv file.
"@
Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName $TaskName -Description $TaskDescription
### or see: https://xplantefeve.io/posts/SchdTskOnEvent
$Principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount
$Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -WakeToRun -RunOnlyIfNetworkAvailable
#Create a Daily trigger instance from TaskScheduler Cim classes
#See: Trigger types: https://wutils.com/wmi/root/microsoft/windows/taskscheduler/msft_tasktrigger/
$class = Get-cimclass MSFT_TaskDailyTrigger root/Microsoft/Windows/TaskScheduler
$Trigger = $class | New-CimInstance -ClientOnly
$Trigger.Enabled = $true
$Trigger.DaysInterval = 1 # Evert day
$Trigger.StartBoundary = Get-Date("2020-10-25T13:00:00")
#Create an Hourly Repetition instance from TaskScheduler Cim classes
#See: https://wutils.com/wmi/root/microsoft/windows/taskscheduler/msft_taskrepetitionpattern/
$Repetition = Get-cimclass MSFT_TaskRepetitionPattern root/Microsoft/Windows/TaskScheduler | New-CimInstance -ClientOnly
$Repetition.Duration = "PID"  # Period of 1 Day
$Repetition.Interval = "PT1H" # Time-Perirod of 1 Hour
$Repetition.StopAtDurationEnd = $false
$Trigger.Repetition = $Repetition
$RegSchTaskParameters = @{
    TaskName    = $TaskName
    Description = "runs every hour"
    TaskPath    = "\Event Viewer Tasks\"
    Action      = $Action
    Principal   = $Principal
    Settings    = $Settings
    Trigger     = $Trigger
}
Register-ScheduledTask @RegSchTaskParameters

### Change the user account to run the scheduled task
# https://adamtheautomator.com/how-to-set-up-and-manage-scheduled-tasks-with-powershell/
# Set the task principal's user ID and run level.
$UserName = "$ENV:COMPUTERNAME\$ENV:USERNAME"
$UserPassord = "password"
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $UserName -RunLevel Highest
#$taskPrincipal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# Set the task compatibility value to Windows 10.
$taskSettings = New-ScheduledTaskSettingsSet -Compatibility Win8
# Update the task principal settings
Set-ScheduledTask -TaskName $TaskName -Principal $taskPrincipal -Settings $taskSettings
# Update the task user account and password
Set-ScheduledTask -TaskName $TaskName -User $taskPrincipal.UserID -Password $UserPassord


### Changing the Trigger to run the scheduled task
$taskTrigger1 = New-ScheduledTaskTrigger -Daily -At "9:00PM"
$taskTrigger2 = New-ScheduledTaskTrigger -Daily -At "17:00Z"
Set-ScheduledTask -Trigger $taskTrigger1,$Trigger2 -TaskName $TaskName -User $taskPrincipal -Password $UserPassord


### Export scheduled task properties
Export-ScheduledTask -TaskName $TaskName


### Export/Serialize the scheduled task
$Task = Get-ScheduledTask -TaskName $TaskName
$Task | Export-Clixml -Path "$TaskName.xml"


### Delete the scheduled task
Unregister-ScheduledTask -TaskName $TaskName #-Confirm:$false


### Import/De-Serialize the Schedule Task
$ImpTask = Import-Clixml -Path "$TaskName.xml"
# Resetting the LogonType value is critical to ensure successful scheduled task restoration
# Reset the logon type to "Run only when the user is logged on."
$ImpTask.Principal.LogonType = 'Interactive'
# Create a new Scheduled Task object using the imported values
$RestoreTask = New-ScheduledTask `
    -Action $ImpTask.Actions `
    -Trigger $ImpTask.Triggers `
    -Settings $ImpTask.Settings `
    -Principal $ImpTask.Principal
Register-ScheduledTask -TaskName $TaskName -InputObject $RestoreTask -User $UserName -Password $UserPassord
