
<#
.SYNOPSIS
    Returns cim process(s) currently running that match the ProcessName.
    If no process instance is currently running then we wait until the timeout for a process to be started.

.PARAMETER ProcessName
    We match with the 'like' operator if the name contains % characters

.PARAMETER UserName   
    Use this optional parameter to filter out the processes created by a user
    
.PARAMETER TimeoutSec
    Use TimeoutSec to limit how long to wait until a new process instance is started.
    The default (-1) will wait indefinitely

.EXAMPLE
    Wait up to 1 minute for notepad.exe and/or notepad++.exe
    Wait-ProcessRunning -ProcessName 'Notepad%' -Timeout 60 -UserName $ENV:USERNAME

.EXAMPLE
    Wait indefinitely for notepad.exe
    Wait-ProcessRunning -ProcessName 'Notepad.exe'
#>
function Wait-ProcessRunning
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string] $ProcessName,

        [Parameter()]
        [string] $UserName = $null,

        [Parameter()]
        [Alias('Timeout')]
        [int] $TimeoutSec = -1,

        [Parameter()]
        [int] $SleepSec = 1 # Private
    )
   
    
    [array]$ProcS = $null
    $EndTime = $null
    if ($TimeoutSec -ge 0)
    {
        $EndTime = (Get-Date).AddSeconds($TimeoutSec)
    }    
    do {
        if ($ProcessName.Contains('%'))
        {
            [array]$ProcS = Get-CimInstance -ClassName Win32_Process -Filter "Name like '$ProcessName'"
        }
        else 
        {
            [array]$ProcS = Get-CimInstance -ClassName Win32_Process -Filter "Name = '$ProcessName'"
        }
        
        if ($UserName)
        {
            $UserProcS = foreach ($Proc in $ProcS) 
            {
                if ((Invoke-CimMethod -InputObject $Proc -MethodName 'GetOwner').User -eq $UserName)
                {
                    Write-Output $Proc
                }
            }
            $ProcS = $UserProcS
        }
        if (!$ProcS)
        {
            Start-Sleep -Seconds $SleepSec  ##// TODO is there a more efficient way ??
        }
    } until ($ProcS -or !$EndTime -or ((Get-Date) -ge $EndTime))
    return $ProcS
}
