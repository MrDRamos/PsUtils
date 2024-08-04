# Cleanup
Get-EventSubscriber | ForEach-Object { Unregister-Event -SourceIdentifier $_.SourceIdentifier }
Get-Job | Stop-Job
Get-Job | Remove-Job
Get-Event | Remove-Event


<#
.SYNOPSIS
    Demonstrates a mechanism to monitor changes to files is a folder.
    We register event handlers with a FileSystemWatcher instance that:
        - Write output to the console
        - Raise a WaitHandle to that the main process logic can test for
    A simple application could just do all it work in the Action scriptblock.
    A more realistic application will utilize separate Create, Change and Delete events
    and execute this function in a background thread.
    It can then wait/test for the signaled event at the appropriate point in the program flow.

.NOTES
    System.IO.FileSystemWatcher
    https://learn.microsoft.com/en-us/dotnet/api/system.io.filesystemwatcher?view=netframework-4.8.1

    PowerShell and Events: Object Events
    https://learn-powershell.net/2013/02/08/powershell-and-events-object-events/
#>
function Enable-FileSystemWatcherEvents
{
    [CmdLetBinding()]            
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $Path,

        [Parameter()]
        [switch] $IncludeSubdirectories,

        [Parameter()]
        [Object] $EventWaitHandle = $null
    )

    # Note: The $EventWaitHandle argument does not persist after exiting this call, and therefore can't be used in the Action [scriptblock] 
    # The Action [scriptblock] will need a global variable. So here we create a global(private) variable reference to $EventWaitHandle
    if ($EventWaitHandle)
    {
        $Global:G_EventWaitHandle = $EventWaitHandle
    }

    $FileWatcher = New-Object System.IO.FileSystemWatcher
    $FileWatcher.Path = $Path
    $FileWatcher.IncludeSubdirectories = $IncludeSubdirectories
    Register-ObjectEvent -InputObject $FileWatcher -EventName 'Changed' -SourceIdentifier 'File.Changed' -Action {
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
        $Global:DbgEvent = $Event

        Write-Host ("File Changed: {0} on {1}" -f $event.SourceEventArgs.Name, (Split-Path $event.SourceEventArgs.FullPath))
        if ($Global:G_EventWaitHandle)
        {
            $Global:G_EventWaitHandle.Set()
        }
    } | Out-Null
    
    Register-ObjectEvent -InputObject $FileWatcher -EventName 'Created' -SourceIdentifier 'File.Created' -Action {
        $Global:DbgEvent = $event
        Write-Host ("File Created: {0} on {1}" -f $event.SourceEventArgs.Name, (Split-Path $event.SourceEventArgs.FullPath))
        if ($Global:G_EventWaitHandle)
        {
            $Global:G_EventWaitHandle.Set()
        }
    } | Out-Null
    
    Register-ObjectEvent -InputObject $FileWatcher -EventName 'Deleted' -SourceIdentifier 'File.Deleted' -Action {
        $Global:DbgEvent = $event
        Write-Host ("File Deleted: {0} on {1}" -f $event.SourceEventArgs.Name, (Split-Path $event.SourceEventArgs.FullPath))
        if ($Global:G_EventWaitHandle)
        {
            $Global:G_EventWaitHandle.Set()
        }
    } | Out-Null
    
    Register-ObjectEvent -InputObject $FileWatcher -EventName 'Error' -SourceIdentifier 'File.Error' -Action {
        $Global:DbgEvent = $event
        Write-Host "The FileSystemWatcher has detected an error $($event.SourceEventArgs.GetException().Message)"
    } | Out-Null
}
    
$Path = 'C:\temp'
$FileChangedEvent = New-Object System.Threading.AutoResetEvent -ArgumentList $false #Set the initial state to non-signaled
Enable-FileSystemWatcherEvents -Path $Path -IncludeSubdirectories -EventWaitHandle $FileChangedEvent

Write-Host "To generate FileSystemWatcher events: In another console Create, Edit or Delete files in: $Path"
# Note: No out is observed during call to ReadKey because this thread will blocking the Event-Actions
Write-Host "The events-handler output will show, once you press any key in this console... " -NoNewline
[void][System.Console]::ReadKey($true)
Write-Host                  # Yield to other background tasks that have been queued for execution on this thread
#Start-Sleep -Seconds 0     # Yield to other background tasks that have been queued for execution on this thread

[int]$index = [System.Threading.WaitHandle]::WaitAny($FileChangedEvent, 0)#, $true) 
if ($index -eq 0)
{
    Write-Host "The FileChangedEvent event was raised" -ForegroundColor Green
    Write-Host "The last event was for: $($Global:DbgEvent.SourceArgs.FullPath)"
}
elseif ($index -eq [System.Threading.WaitHandle]::WaitTimeout)
{
    Write-Host "Timeout waiting for: FileChangedEvent event" -ForegroundColor Yellow
}

# Get-EventSubscriber | Format-Table
@"

The registered events-handlers are still active.
Create, Edit or Delete more files in: $Path
to show the realtime output of additional FileSystemWatcher events.

To stop the events run:  
Get-Job | Stop-Job

"@ | Write-Host
