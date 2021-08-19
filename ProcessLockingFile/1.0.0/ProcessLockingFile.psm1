<#
.SYNOPSIS
  Utility to discover/kill processes that have open file handles to a file or folder.

  Find-ProcessLockingFile()
    This function retrieves process and user information that have a file handle open 
    to the specified path.
    Example: Find-ProcessLockingFile -Path $Env:LOCALAPPDATA
    Example: Find-ProcessLockingFile -Path $Env:LOCALAPPDATA | Get-Process

  Stop-ProcessLockingFile()
    This function kills all processes that have a file handle open to the specified path.
    Example: Stop-ProcessLockingFile -Path $Home\Documents 
#>



<#
.SYNOPSIS
Helper function to stop one or more processes with extra error handling and logging.
We first try stop the process nicely by calling Stop-Process().
But if the process is still running after the timeout expires then we
do a hard kill.
#>
function Kill_Process
{
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline)]
        [int[]] $ProcessId,

        [parameter()]
        [int] $TimeoutSec = 2
    )

    begin
    {
        [int[]] $ProcIdS = @()
    }
    process
    {
        if ($ProcessId)
        {
            $ProcIdS += $ProcessId
        }
    }
    end
    {
        if ($ProcIdS)
        {
            [array]$CimProcS = $null
            [array]$StoppedIdS = $null
            foreach ($ProcId in $ProcIdS)
            {
                $CimProc = Get-CimInstance -Class Win32_Process -Filter "ProcessId = '$ProcId'" -Verbose:$false
                $CimProcS += $CimProc
                if ($CimProc)
                {
                    Write-Verbose "Stopping process: $($CimProc.Name)($($CimProc.ProcessId)), ParentProcessId:'$($CimProc.ParentProcessId)', Path:'$($CimProc.Path)'"
                    Stop-Process -Id $CimProc.ProcessId -Force -ErrorAction Ignore
                    $StoppedIdS += $CimProc.ProcessId
                }
                else 
                {
                    Write-Verbose "Process($ProcId) already stopped"
                }
            }

            if ($StoppedIdS)
            {
                if ($TimeoutSec)
                {
                    Write-Verbose "Waiting for processes to stop TimeoutSec: $TimeoutSec"
                    Wait-Process -Id $StoppedIdS -Timeout $TimeoutSec -ErrorAction ignore
                }

                # Verify that none of the stopped processes exist anymore
                [array] $NotStopped = $null
                foreach ($ProcessId in $StoppedIdS)
                {
                    # Hard kill the proess if the gracefull stop failed
                    $Proc = Get-Process -Id $ProcessId -ErrorAction Ignore
                    if ($Proc -and !$Proc.HasExited)
                    {
                        $ProcInfo = "Process: $($Proc.Name)($ProcessId)"
                        Write-Verbose "Killing process because of timeout waiting for it to stop, $ProcInfo" -Verbose
                        try 
                        {
                            $Proc.Kill()
                        }
                        catch 
                        {
                            Write-Warning "Kill Child-Process Exception: $($_.Exception.Message)"
                        }
                        Wait-Process -Id $ProcessId -Timeout 2 -ErrorAction ignore

                        $CimProc = Get-CimInstance -Class Win32_Process -Filter "ProcessId = '$ProcessId'" -Verbose:$false
                        if ($CimProc)
                        {
                            $NotStopped += $CimProc
                        }
                    }
                }

                if ($NotStopped)
                {
                    $ProcInfoS = ($NotStopped | ForEach-Object { "$($_.Name)($($_.ProcessId))" }) -join ", "
                    $ErrMsg = "Timeout-Error stopping processes: $ProcInfoS"
                    if (@("SilentlyContinue", "Ignore", "Continue") -notcontains $ErrorActionPreference)
                    {
                        Throw $ErrMsg
                    }
                    Write-Warning $ErrMsg
                }
                else 
                {
                    $ProcInfoS = ($CimProcS | ForEach-Object { "$($_.Name)($($_.ProcessId))" }) -join ", "
                    Write-Output "Finished stopping processes: $ProcInfoS"
                }
            }
        }
    }
}



<#
.SYNOPSIS
This function retrieves process and user information that have a file handle open 
to the specified path.
We extract the output from the handle.exe utility from SysInternals:
Link: https://docs.microsoft.com/en-us/sysinternals/downloads/handle

.Example
Find-ProcessLockingFile -Path $Env:LOCALAPPDATA
#>
function Find-ProcessLockingFile
{
    [OutputType([array])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [object] $Path
    )

    $AppInfo = Get-Command $Script:HandleApp -ErrorAction Stop
    if ($AppInfo)
    {
        #Initialize-SystemInternalsApp -AppRegName "Handle"
        $PathName = (Resolve-Path -Path $Path).Path.TrimEnd("\") # Ensures proper .. expansion & slashe \/ type
        $LineS = & $AppInfo.Path -accepteula -u $PathName -nobanner
        foreach ($Line in $LineS) 
        {
            # "pwsh.exe           pid: 5808   type: File          Domain\UserName             48: D:\MySuff\Modules"
            if ($Line -match "(?<proc>.+)\s+pid: (?<pid>\d+)\s+type: (?<type>\w+)\s+(?<user>.+)\s+(?<hnum>\w+)\:\s+(?<path>.*)\s*")
            {
                $Proc = $Matches.proc.Trim()
                if (@("handle.exe", "Handle64.exe") -notcontains $Proc)
                {
                    $Retval = [PSCustomObject]@{
                        Process = $Proc
                        Pid     = $Matches.pid
                        User    = $Matches.user.Trim()
                        #Handle  = $Matches.hnum
                        Path    = $Matches.path
                    }
                    Write-Output $Retval
                }
            }
        }
    }
}



<#
.SYNOPSIS
Stop all processes that have a file handle open to the specified path.

.Example
Stop-ProcessLockingFile -Path $Home\Documents 
#>
function Stop-ProcessLockingFile
{
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [object] $Path
    )

    $ProcS = Find-ProcessLockingFile -Path $Path | Sort-Object -Property Pid -Unique
    Kill_Process -ProcessId $ProcS.Pid
}



#########   Initialize Module   #########
$Script:HandleApp = "$PSScriptRoot\Handle.exe"
