<#
Framework code for an application that processes tasks in an endless loop until:
    -All application tasks were completed
    -An exit key <escape> was pressed by the user
    -A System.Threading.EventWaitHandle was signaled
        # e.g. In a second powershell console, create a close-event handle and signal it
        $MyCloseEvent = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, 'MyDemoApp.Close')
        $MyCloseEvent.Set()
        $MyCloseEvent..Dispose() # Don't forget to dispose or else you will have an orphaned system handle that can only be removed by exiting the powershell session
#>

# DotSource libraries
. "$PSScriptRoot\API_AppEvents.ps1"


# Initialize Application Vars
$AppName = 'MyDemoApp'
$PollingIntervalSec = 4
$SleepSec = 1
$MaxAppTasks = 25
$CloseEventName = "${AppName}.Close"
#$CloseEventName = $null


# Initialize Event Vars
Write-Host "Starting $AppName"
if ($CloseEventName)
{
    $OpenExisting = $false
    #$OpenExisting = $true
    $Success = Initialize-AppCloseEventHandle -CloseEvent $CloseEventName -OpenExisting:$OpenExisting
    if ($Success)
    {
        Write-Host "Program will exit when this Close-Event is signaled: $CloseEventName"
    }
    elseif($OpenExisting)
    {
        Write-Host "Failed to obtain then specified Close-Event: $CloseEventName" -ForegroundColor Red
        exit 1
    }
}
if (Test-Path -Path Function:Test-KeyPressed)
{
    Write-Host 'Press <ESC> key to exit ...'
}


# Initialize Loop
$PollingIntervalSec = [math]::Min([math]::Max(0, $PollingIntervalSec), 600) # Limit range [0..600(=10Minutes)]
$SleepSec = [math]::Min([math]::Max(0, $SleepSec), $PollingIntervalSec)     # Limit range [0..$PollingIntervalSec]
[int] $SleepCount = 0
[int] $AppTasks = 0
$AppCanSleep = $true


# Main loop
$ExitLoop = $False
do {
    ## .. main app code
    $AppTasks++
    $AppCanSleep = ($AppTasks % 5) -ne 0 # Example showing that we don't want to sleep after every 5th tasks
    ## .. main app code

    # Show application idle dots ...
    if (!$ExitLoop)
    {                
        if ($SleepCount * $PollingIntervalSec -ge 60)
        {
            $SleepCount = 0
            Write-Host '.' -NoNewline
        }
        else
        {
            Write-Host '.' -NoNewline
        }        
    }

    # Check if app should exit
    if (!$ExitLoop -and ($MaxAppTasks -ge 0 -and $AppTasks -ge $MaxAppTasks) -or $PollingIntervalSec -le 0)
    {
        Write-Host "Program terminating because all $MaxAppTasks Application-Tasks were completed"
        $ExitLoop = $true
    }
    elseif (Test-AppExitEvent)
    {
        $ExitLoop = $true
    }

    # Sleep for $PollingIntervalSec before continuing the loop
    if (!$ExitLoop)
    {
        if ($AppCanSleep -and $PollingIntervalSec -gt 0)
        {
            $SleepCount++
            $EndTime = (Get-Date).AddSeconds($PollingIntervalSec)
            do
            {
                # For better responsiveness we split the total sleep time into smaller chunks
                Start-Sleep -Seconds $SleepSec
                if (Test-AppExitEvent)
                {
                    $ExitLoop = $true
                    break
                }
            } while ((Get-Date) -lt $EndTime)
        }
    }
} until ($ExitLoop)

Write-Host "Exiting $AppName" -ForegroundColor Cyan
Clear-AppCloseEventHandle
Exit 0
