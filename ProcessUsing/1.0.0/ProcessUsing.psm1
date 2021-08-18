<#
.SYNOPSIS
  Utility to discover/kill processes that have open file handles to a file or folder.

  Find-ProcessUsingPath()
    This function retrieves process and user information that have a file handle open 
    to the specified path.
    Example: Find-ProcessUsingPath -Path $Env:LOCALAPPDATA

  Stop-ProcessUsingPath()
    This function kills all processes that have a file handle open to the specified path.
    Example: Stop-ProcessUsingPath -Path $Home\Documents 
#>



<#
.SYNOPSIS
Helper function to initialize the EulaAccepted property of a SysInternals application.
This must be done to avoid interactive promping of the tool.
#>
function Initialize-SystemInternalsApp
{
    [OutputType([System.Management.Automation.ApplicationInfo])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $AppPath
    )

    $AppInfo = Get-Command $AppPath -ErrorAction Ignore
    if ($AppInfo)
    {
        $AppName = [System.IO.Path]::GetFileNameWithoutExtension($AppInfo.Name)
        $RegKey = Get-ChildItem -Path "Registry::HKCU\Software\Sysinternals" -ErrorAction Ignore | Where-Object { $_.Name -match "\\$AppName`$" }
        if ($RegKey)
        {
            if (!$RegKey.GetValue("EulaAccepted"))
            {
                Set-ItemProperty -Path $RegKey -Name "EulaAccepted" -Value 1
            }
        }
        else
        {
            $RegKey = New-Item -Path "Registry::HKCU\Software\Sysinternals\$AppName" -Force
            $null = $RegKey | New-ItemProperty -Name "EulaAccepted" -Value 1
        }
    }
    return $AppInfo
}



<#
.SYNOPSIS
Helper function to stop a process with extra error handling and logging.
We first try stop the process nicely by calling Stop-Process().
But if the process is still running after the timeout expires then we
do a hard kill.
#>
function Stop-ProcessOrKill
{
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline)]
        [int[]] $ProcessId,

        [parameter()]
        [int] $TimeoutSec = 0
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
                $Timeout = [Math]::Max($TimeoutSec, 2) # wait at least 2 sec
                if ($TimeoutSec)
                {
                    Write-Verbose "Waiting for processes to stop TimeoutSec: $Timeout"
                }
                Wait-Process -Id $StoppedIdS -Timeout $Timeout -ErrorAction ignore

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
Find-ProcessUsingPath -Path $Env:LOCALAPPDATA
#>
function Find-ProcessUsingPath
{
    [OutputType([array])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [object] $Path
    )

    $AppInfo = Initialize-SystemInternalsApp -AppPath $Script:HandleApp
    if ($AppInfo)
    {
        $PathName = (Resolve-Path -Path $Path).Path # Ensures proper \ and Case
        $LineS = & $AppInfo.Path -nobanner -u $PathName
        foreach ($Line in $LineS) 
        {
            # "pwsh.exe           pid: 5808   type: File          Domain\UserName             48: D:\MySuff\Modules"
            if ($Line -match "(?<proc>.+)\s+pid: (?<pid>\d+)\s+type: (?<type>\w+)\s+(?<user>.+)\s+(?<hnum>[0-9a-fA-F]+)\:\s+(?<path>.*)\s*")
            {
                $Proc = $Matches.proc.Trim()
                if (@("handle.exe", "Handle64.exe") -notcontains $Proc)
                {
                    $Retval = [PSCustomObject]@{
                        Process = $Proc
                        Pid     = $Matches.pid
                        User    = $Matches.user.Trim()
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
Stop-ProcessUsingPath -Path $Home\Documents 
#>
function Stop-ProcessUsingPath
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [object] $Path
    )

    $ProcS = Find-ProcessUsingPath -Path $Path | Sort-Object -Property Pid -Unique
    Stop-ProcessOrKill -ProcessId $ProcS.Pid
}



#########   Initialize script   #########
$Script:HandleApp = "$PSScriptRoot\Handle.exe"
