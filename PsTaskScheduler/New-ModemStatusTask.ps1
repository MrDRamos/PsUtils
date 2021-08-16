
function New-HourlyTaskTrigger
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet("", "5M","10M","15M","30M","1H")] # "" = No Repetitions
        [string] $RepeatRate = "1H",

        [Parameter()]
        [ValidateSet("15M","30M","1H","12H","1D","INF","")] # "" = infinite
        [string] $RepeatDuration = "1D",
        
        [Parameter()]
        [datetime] $StartTime = (Get-Date),

        [Parameter()]
        [datetime] $EndTime = 0
    )

    #Create a Daily trigger instance from TaskScheduler Cim classes
    #See: Trigger types: https://wutils.com/wmi/root/microsoft/windows/taskscheduler/msft_tasktrigger/
    $TriggerClass = Get-CimClass MSFT_TaskDailyTrigger root/Microsoft/Windows/TaskScheduler
    $Trigger = $TriggerClass | New-CimInstance -ClientOnly
    $Trigger.Enabled = $true
    $Trigger.DaysInterval = 1 # Evert day
    $Trigger.StartBoundary = $StartTime
    if ($EndTime.Ticks -gt 0)
    {
        $Trigger.EndBoundary = $EndTime
    }
    
    #Create an Hourly Repetition instance from TaskScheduler Cim classes
    #See: https://wutils.com/wmi/root/microsoft/windows/taskscheduler/msft_taskrepetitionpattern/
    $Repetition = Get-CimClass MSFT_TaskRepetitionPattern root/Microsoft/Windows/TaskScheduler | New-CimInstance -ClientOnly
    $Repetition.Interval = switch ($RepeatRate) {
        "5M"  { "PT5M" }
        "10M" { "PT10M" }
        "15M" { "PT15M" }
        "30M" { "PT30M" }
        "1H"  { "PT1H" }
        Default { "" } # = No repetitions
    }
    if ($Repetition.Interval)
    {
        $Repetition.Duration = switch ($RepeatDuration) {
            "15M" { "PT15M" }
            "30M" { "PT30M" }
            "1H"  { "P1H" }
            "12H" { "PT12H" }
            "1D"  { "P1D" }
            Default { "" } # = Indefinitely
        }    
    }
    $Repetition.StopAtDurationEnd = $false
    $Trigger.Repetition = $Repetition
    return $Trigger
}


function New-PsScheduledTaskAction
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ScriptFile,

        [Parameter()]
        [string] $ScriptArgs = "",

        [Parameter()]
        [switch] $NoProfile,  # Dont load the PowerShell profiles

        [Parameter()]
        [string] $Edition = $PSEdition
    )

    if ($Edition = "Desktop")
    {
        $PsCmd = "$ENV:SystemRoot\system32\WindowsPowerShell\v1.0\powershell.exe"
    }
    else 
    {
        $PsCmd = "pwsh.exe"
    }

    $PsOptions = "-NonInteractive -ExecutionPolicy Bypass"
    if ($NoProfile)
    {
        $PsOptions += "-NoProfile"
    }

    $Action = New-ScheduledTaskAction -Execute $PsCmd -Argument "$PsOptions -File '$ScriptFile' $ScriptArgs"
    return $Action
}


function New-PsScheduledTask
{
    [CmdletBinding(DefaultParameterSetName="ByPrincipal")]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $TaskName,

        [Parameter()]
        [string] $TaskPath = "", # Default uses root folder

        [Parameter()]
        [string] $Description = "",

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ScriptFile,

        [Parameter()]
        [string] $ScriptArgs = "",

        # New-ScheduledTaskTrigger
        [Parameter(Mandatory = $true)]
        [CimInstance[]] $Trigger,

        [Parameter(ParameterSetName="ByUser", Mandatory = $true)]
        [System.Management.Automation.PSCredential] $RunAsCredential,

        # New-ScheduledTaskPrincipal
        # https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtaskprincipal?view=win10-ps
        [Parameter(ParameterSetName="ByPrincipal")]
        [CimInstance] $RunAsPrincipal = (New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel "Highest"),

        # New-ScheduledTaskSettingsSet
        # https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasksettingsset?view=win10-ps
        [Parameter()]
        [CimInstance] $Setings = $null
    )

    if ($TaskPath)
    {
        $TaskPath = $TaskPath.Trim()
        if (!($TaskPath.StartsWith("\"))) { $TaskPath = "\" + $TaskPath }
        if (!($TaskPath.EndsWith("\"))) { $TaskPath = $TaskPath + "\" }
    }
    else 
    {
        $TaskPath = "\"    
    }

    $Action = New-PsScheduledTaskAction -ScriptFile $ScriptFile -ScriptArgs $ScriptArgs    
    $Parameters = @{
        TaskName    = $TaskName
        Description = $Description
        TaskPath    = $TaskPath
        Action      = $Action
        Settings    = $Settings
        Trigger     = $Trigger
    }
        
    if ($RunAsCredential)
    {
        $pswd = $RunAsCredential.GetNetworkCredential().Password
        Register-ScheduledTask @Parameters -User $RunAsCredential.UserName -Password $pswd
    }
    else 
    {
        Register-ScheduledTask @Parameters -Principal $RunAsPrincipal
    }
}


$ScripDir = "C:\Users\mrdra\OneDrive\Lobby\Arris_Cable_Modem"
$ScriptFile = "$ScripDir\Get-ModemStatus.ps1"
$ScriptArgs = "-LogDir '$ScripDir\logs'"

$TaskName = "Log Modem Test"
$TaskDescription= @"
Retrieve the signal levels of the cable modem channels.
Log the data and append the statistics to a csv file.
"@

$StartTime = (Get-Date) + [timespan]::FromHours(1)
$Trigger = New-HourlyTaskTrigger -RepeatRate "1H" -StartTime $StartTime
$Settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -WakeToRun -Compatibility Win8

$UsrPswd = ConvertTo-SecureString "<Your-Password>" -AsPlainText -Force
$UsrName = $ENV:USERNAME
$RunAs = New-Object PSCredential($UsrName, $UsrPswd)

New-PsScheduledTask -TaskName $TaskName -Description $TaskDescription `
    -ScriptFile $ScriptFile -ScriptArgs $ScriptArgs `
    -Trigger $Trigger -Setings $Settings #-RunAsCredential $RunAs

$Task = Get-ScheduledTask -TaskName $TaskName
$Task
#Unregister-ScheduledTask -TaskName $TaskName #-Confirm:$false
