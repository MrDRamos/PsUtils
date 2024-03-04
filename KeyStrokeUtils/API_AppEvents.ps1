
# DotSource libraries
. "$PSScriptRoot\Test-KeyPressed.ps1"


#region App-Events

# Global script vars:
$Script:G_AppExitEvent = $false
[System.Threading.EventWaitHandle] $Script:G_AppCloseEventHandle = $null

<#
  Creates a new (or obtains an existing) windows system EventWaitHandle
  Returns boolean success of fail status

  .Example
  Commands to signal the event from a second Powershell console:
  $MyCloseEvent = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, 'MyDemoApp.Close')
  $MyCloseEvent.Set()
  $MyCloseEvent..Dispose() # Don't forget to dispose or else you will have an orphaned system handle that can only be removed by exiting the powershell session
#>
function Initialize-AppCloseEventHandle
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $CloseEventName,

        [Parameter()]
        [switch] $OpenExisting # Don't try to create a new handle
    )

    $retval = $true
    if (!$Script:G_AppCloseEventHandle -and ![string]::IsNullOrWhiteSpace($CloseEventName))
    {
        if ($OpenExisting)
        {
            $retval = [System.Threading.EventWaitHandle]::TryOpenExisting($CloseEventName, [ref]$Script:G_AppCloseEventHandle)
            if ($retval)
            {
                Write-Verbose "Using existing Close-Event: $CloseEventName"
            }
            else
            {
                Write-Verbose "Failed to obtain en existing Close-Event handle: $CloseEventName"
            }
        }
        else 
        {
            $CreateNewEvent = $false
            $Script:G_AppCloseEventHandle = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, $CloseEventName, [ref]$CreateNewEvent)
            if ($CreateNewEvent)
            {
                Write-Verbose "Create new Manual Reset Close-Event: $CloseEventName"
            }
            else 
            {
                Write-Verbose "Using existing Close-Event: $CloseEventName"
            }
        }
    }

    $Script:G_AppExitEvent = $false
    return $retval
}


function Clear-AppCloseEventHandle
{
    if ($Script:G_AppCloseEventHandle)
    {
        $Script:G_AppCloseEventHandle.Dispose()
        $Script:G_AppCloseEventHandle = $null
    }
}


function Test-AppCloseEventSignaled
{
    $isSignaled = $Script:G_AppCloseEventHandle -and $Script:G_AppCloseEventHandle.WaitOne(0)
    if ($isSignaled)
    {
        Clear-AppCloseEventHandle
    }
    return $isSignaled
}


<#
.EXAMPLE
$null = Initialize-AppCloseEventHandle -CloseEvent 'MyDemoApp' -OpenExisting -Verbose
do
{
    Write-Host '.' -NoNewline
    Start-Sleep -Seconds 1
} until (Test-AppExitEvent -Verbose)
Clear-AppCloseEventHandle
#>
function Test-AppExitEvent
{
    if (!$Script:G_AppExitEvent)
    {
        if ((Test-Path -Path Function:Test-AppCloseEventSignaled) -and (Test-AppCloseEventSignaled))
        {
            $Script:G_AppExitEvent = $true
            Write-Verbose "Program terminating because the Close-Event was signaled"
        }
        elseif ((Test-Path -Path Function:Test-KeyPressed) -and (Test-KeyPressed))
        {
            $Script:G_AppExitEvent = $true
            Write-Verbose 'Program terminating because the <ESC> key was pressed'
        }
    }
    return $Script:G_AppExitEvent
}


#endregion App-Events

<# Test driver
$null = Initialize-AppCloseEventHandle -CloseEvent 'MyDemoApp' -OpenExisting -Verbose
do
{
    Write-Host '.' -NoNewline
    Start-Sleep -Seconds 1
} until (Test-AppExitEvent -Verbose)
Clear-AppCloseEventHandle
#>
