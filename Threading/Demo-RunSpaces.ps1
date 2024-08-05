<#
    PowerShell RunSpaces
    https://devblogs.microsoft.com/scripting/beginning-use-of-powershell-runspaces-part-1/
#>
function Start-BackgroundJob
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [scriptblock] $ScriptBlock = $null,

        [Parameter()]
        [hashtable] $ArgumentS = $null
    )

  
    Write-Verbose "Creating Runspace"
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace | Format-List | Out-String | Write-Verbose

    $PowerShell = [powershell]::Create()
    $PowerShell.Runspace = $Runspace
    $Runspace.Open()

    if ($ScriptBlock)
    {
        Write-Verbose "Adding Script"
        $AddScript = $PowerShell.AddScript($ScriptBlock)
        $AddScript | Format-List | Out-String | Write-Verbose
        if ($ArgumentS)
        {
            $AddScript.AddParameters($ArgumentS)
        }    
    }

    Write-Verbose "Starting Runspace: $($Runspace.Name)"
    $AsyncResult = $PowerShell.BeginInvoke()
    $BackgroundJob =@{
        PowerShell  = $PowerShell
        AsyncResult = $AsyncResult
    }
    return $BackgroundJob
}


function Remove-BackgroundJob
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Object] $Job = $null
    )

    if ($Job)
    {
        $Job.PowerShell.Dispose()
    }
}


function Wait-BackgroundJob
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Object] $Job = $null,

        [Parameter()]
        [Alias('Timeout')]
        [Int] $TimeoutSec = -1,

        [Parameter()]
        [Int] $SleepMSec = 1000
    )

    if ($Job)
    {
        if ($TimeoutSec -ge 0)
        {
            $EndTime = (Get-Date).Add($TimeoutSec)
            while (!$Job.AsyncResult.IsCompleted) 
            {
                Start-Sleep -Seconds $SleepMSec
                if ((Get-Date) -ge $EndTime )
                {
                    $Job = $null
                    break
                }
            }    
        }
        else 
        {
            while (!$Job.AsyncResult.IsCompleted) 
            {
                Start-Sleep -Milliseconds $SleepMSec
            }    
        }    
    }
    return $Job
}


function Receive-BackgroundJob
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Object] $Job = $null
    )

    if ($Job)
    {
        $JobResult = $Job.PowerShell.EndInvoke($Job.AsyncResult)
        return $JobResult
    }
}



##### Unit Test #####
$ArgumentS = @{
    Param1 = 'Hello'
    Param2 = 'World'
}
[scriptblock] $ScriptBlock = { Param ($Param1, $Param2) 
    Write-Output "Process Pid($Pid) Thread($([System.Environment]::CurrentManagedThreadId)) - Background-Job says: $Param1 $Param2"
    Write-Host "The Host-Stream does not get captured"
    Start-Sleep -Seconds 2
}

Write-Host "Process Pid($Pid) Thread($([System.Environment]::CurrentManagedThreadId)) - Starting Background-Job"
$BackgroundJob = Start-BackgroundJob -ScriptBlock $ScriptBlock -Arguments $ArgumentS #-Verbose

Wait-BackgroundJob -Job $BackgroundJob | Out-Null
$JobResult = Receive-BackgroundJob -Job $BackgroundJob
$JobResult | Write-Host
Remove-BackgroundJob -Job $BackgroundJob
