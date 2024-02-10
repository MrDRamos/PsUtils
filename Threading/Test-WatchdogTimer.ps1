[CmdletBinding()]
param (
    [Parameter()]
    [int]$IntervalMiliSec = 500,

    [Parameter()]
    [int]$WatchDogSec = 3,

    [Parameter()]
    [int]$TotalSec = 10
)

#Region PsEvent
##################### PowerShell Event Handler #####################
<#
Powershell Event Registration
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/register-objectevent?view=powershell-7.2

PowerShell Event Examples:
https://learn-powershell.net/2013/02/08/powershell-and-events-object-events/

# System.Timers.Timer Class: 
https://docs.microsoft.com/en-us/dotnet/api/system.timers.timer?view=net-6.0
#>

Function Remove-AppResources
{
    [CmdletBinding()]
    param ()

    Write-Verbose "`nReleasing Script Resources"
   if ($Global:G_Hash)
   {
        Remove-Variable -Name G_Hash -Scope Global
   }

    if ($WatchDogDoneSignal)
    {
        Write-Verbose "Removing Done-AutoResetEvent"
        $WatchDogDoneSignal.Dispose()
        Remove-Variable -Name WatchDogDoneSignal -ErrorAction Ignore
    }

    if ($WatchDogTimerEventId)
    {
        $OldSubscription = Get-EventSubscriber -SourceIdentifier $WatchDogTimerEventId -ErrorAction Ignore
        if ($OldSubscription)
        {
            Write-Verbose "UnRegistering Event Subscribers"
            ($OldSubscription | Format-List | Out-String).Trim() | Write-Verbose
            Unregister-Event -SourceIdentifier $WatchDogTimerEventId
            Remove-Variable -Name WatchDogTimerEventId -ErrorAction Ignore
        }    
    }

    # Remove Events in the Event Queue
    $OldEventS = Get-Event -ErrorAction Ignore
    if ($OldEventS)
    {
        Write-Verbose "Removing Events in Queue:" -NoNewline
        ($OldEventS | Format-Table | Out-String).Trim() | Write-Verbose
        $OldEvents | Remove-Event #-SourceIdentifier $WatchDogTimerEventId
    }

    if ($WatchDogTimer)
    {
        Write-Verbose "Removing WatchDogTimer"
        $WatchDogTimer.Dispose()
        #Remove-Variable -Name WatchDogTimer -Scope Script # Can't be removed
        $WatchDogTimer = $null
    }
}
Remove-AppResources # Just in case last test failed before final cleanup



# This demo has several mechanisms for the WatchDog event handler to signal back to the main loop when its done
$WatchDogDoneEventId = $WatchDogDoneSignal = $WatchDogDoneFlag = 0
# Uncomment one of the variable initializes below to activate that mechanism:
#$WatchDogDoneEventId = "Custom.Done-Event"
#$WatchDogDoneSignal  = New-Object System.Threading.AutoResetEvent -ArgumentList $false
$WatchDogDoneFlag    = 1

$WatchDogTimerEventId = "WatchDogTimer.Elapsed"

#Global scope is required to make variables visible in event handler
$Global:G_Hash = @{
    # These variables are modified the Event handler
    EventCount           = 0  
    WatchDogDoneFlag     = [ref]$WatchDogDoneFlag

    # Constant variable copies:
    WatchDogTimerEventId = $WatchDogTimerEventId 
    WatchDogDoneEventId  = $WatchDogDoneEventId
    WatchDogDoneSignal   = $WatchDogDoneSignal
}



$WatchDogTimer = New-Object System.Timers.Timer -Property @{
    Interval  = $WatchDogSec * 1000
    Autoreset = $True
}

# Script block to handle WatchdogTimer events
[ScriptBlock] $OnTimerElapsedAction = {
    <# Automatic PowerShell variables within a registered Action Script-Block:
    $Sender     = The object (Timer,Watcher...) that generated the event 
    $EventArgs  = The data associated with the event, generated by the Sender
    $Event      {
        ComputerName
        RunspaceId      = Unique [int]
        EventIdentifier = Unique [int]
        Sender          = $Sender
        SourceEventArgs = $EventArgs
        SourceArgs[]    = @(Sender, $EventArgs)
        SourceIdentifier= Unique name for the event e.g: "SenderName.EventName"
        TimeGenerated   = [DateTime]
        MessageData     = Optional data associated with New-Event -or
                          Optional data associated with event subscription
    }
    #>

    try 
    {
    # No thread-save locking is needed to modify $EventCount, since the timer events run on the main thread
    # But we need to access the variables of the main script block using the Global scope
    $L_Hash = $Global:G_Hash # $L_Hash is now alias for $Global:G_Hash
    $L_Hash.EventCount++
    Write-Host "`nAction handler received event: $($L_Hash.EventCount) - $($L_Hash.WatchDogTimerEventId)" -ForegroundColor Green

    $Verbose = $false
    #$Verbose = $True
    if ($Verbose)
    {
        $RunSpace = Get-Runspace
        $RuntimeInfo = @{
            ThreadId         = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            HostRunspace     = $Host.Runspace.Id
            RunspaceId       = $RunSpace.Id
        }
        ($RuntimeInfo | Format-Table | Out-String).Trim() | Write-Host
        
        Write-Host "`$EventArgs:" -ForegroundColor Cyan
        $EventArgs | ConvertTo-Json | Write-Host
    
        Write-Host "`$Event:" -ForegroundColor Cyan
        $Event | ConvertTo-Json | Write-Host
    
        Write-Host "ThreadId: " -ForegroundColor Cyan -NoNewline
        Write-Host ([System.Threading.Thread]::CurrentThread.ManagedThreadId)    
    }

    #Region Notify Main loop
    # Notify Main loop that the Event handler is done using one of the mechanisms below:
    $DoneMsg = "Action handler exiting event: $($L_Hash.EventCount)"
    if ($L_Hash.WatchDogDoneSignal)
    {
        Write-Host "$DoneMsg -> Setting Done-AutoResetEvent" -ForegroundColor Green
        $L_Hash.WatchDogDoneSignal.Set()
    }
    elseif ($L_Hash.WatchDogDoneEventId)
    {
        if ($Host.Name -eq "_ConsoleHost")
        {
            <#
                Execution after calling New-Event() depends on the Powershell Hosting environment:
                When running from a Powershell Console, execution of commands stop, after New-Event(),
                But NOT when running within Vs-Code.
            #>
            Write-Host "$DoneMsg`nNot calling New-Event(Done) because of side effects within Powershell console." -ForegroundColor Magenta
        }
        else 
        {
            Write-Host "$DoneMsg -> Posting Custom-Done-Event" -ForegroundColor Green
            $MsgData = @{EventCount = $L_Hash.EventCount; TimeGenerated = $Event.TimeGenerated }
                New-Event -SourceIdentifier $L_Hash.WatchDogDoneEventId -Sender "WatchdogTimer.EventHandler" -MessageData $MsgData #-EventArguments
        }
    }
    elseif ($L_Hash.WatchDogDoneFlag)
    {
        Write-Host "$DoneMsg -> Setting Done-Flag" -ForegroundColor Green
        $null = [Threading.Interlocked]::CompareExchange($L_Hash.WatchDogDoneFlag, 2, 1)
    }
    else 
    {
        Write-Host $DoneMsg -ForegroundColor Green
    }
    #EndRegion Notify Main loop

    #Region Kill the application
    if ($L_Hash.EventCount -ge 3)
    {
        <#
            # Terminate powershell Session
            # Method 1
            $R = [runspace]::DefaultRunspace
            $R[0].CloseAsync()

            # Method 2
            [Environment]::FailFast("Just terminate already")

            # Method 3
            Exit #  <== Does not work in event handler

            # Method 4
            [Environment]::Exit(1)
        #>
    }
    #EndRegion Kill the application
    }
    catch 
    {    
        # Note: Exception are silently caught by the event dispatcher
        Write-Host "`nFatal error in event handler: $($_.Exception.Message)" -ForegroundColor Red
    }
}



$RegisterParamS = @{
    InputObject      = $WatchDogTimer
    EventName        = 'Elapsed'    # Name of System.Timers.Timer.Elapsed Delegate
    SourceIdentifier = $WatchDogTimerEventId
    Action           = $OnTimerElapsedAction
}
$TimerJob = Register-ObjectEvent @RegisterParamS -MessageData @{ MyData = "Hello Timer"}
Write-Host "Registered WatchDogTimer Event Handler:"
$TimerJob | Format-Table
#EndRegion PsEvent

#Region Main
##################### Main #####################
Write-Host "Start Watch-Dog Timer Demo Script" -ForegroundColor Yellow
if ($VerbosePreference)
{
    $RunSpace = Get-Runspace
    $RuntimeInfo = @{
        ThreadId         = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        HostRunspace     = $Host.Runspace.Id
        RunspaceId       = $RunSpace.Id
    } 
    ($RuntimeInfo | Format-Table | Out-String).Trim() | Write-Host
}

Write-Host "Main loop waiting for WatchDog events:" -NoNewline
$EndTime = (Get-Date).AddSeconds($TotalSec)
$WatchDogTimer.Enabled = $True
try
{
    do 
    {
        Write-Host "." -NoNewline
        if ($WatchDogDoneSignal)
        {
            if ($WatchDogDoneSignal.WaitOne($IntervalMiliSec))
            {
                Write-Host "Main loop received Done-AutoResetEvent:" -NoNewline
            }
        }
        else 
        {
            Start-Sleep -Milliseconds $IntervalMiliSec
        }

        if ($WatchDogDoneEventId)
        {
            $WatchDogTimerEvent = Wait-Event -SourceIdentifier $WatchDogDoneEventId -Timeout 0
            if ($WatchDogTimerEvent)
            {
                $WatchDogTimerEvent | Remove-Event
                Write-Host "Main loop received Custom-Done-Event:" -NoNewline
            }
        }
        
        if ($WatchDogDoneFlag)
        {
            if ([Threading.Interlocked]::CompareExchange([ref]$WatchDogDoneFlag, 1, 2) -eq 2)
            {
                Write-Host "Main loop noticed Done-Flag:" -NoNewline                
            }
        }

    } until ((Get-Date) -ge $EndTime)
}
catch
{
    Write-Host "`n$_.Exception.Message" -ForegroundColor Red
}

$WatchDogTimer.Enabled = $false
Write-Host "`nMain loop completed. Total Watch-Dog events: $($G_Hash.EventCount)"
#EndRegion Main

# Free Event Resources
Remove-AppResources #-Verbose
