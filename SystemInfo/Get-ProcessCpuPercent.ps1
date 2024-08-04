param (
    [Parameter()]
    [int] $Top = -1
)

function Get-ProcessCpuPercent
{
    param (
        [Parameter()]
        [int] $Top = -1
    )
    
    $CpuPercent = @{
        Name = 'CpuPercent'
        Expression = {
            $TotalSec = (New-TimeSpan -Start $_.StartTime).TotalSeconds
            [Math]::Round( ($_.CPU * 100 / $TotalSec), 2)
        }
    }
    $Result = Get-Process | Where-Object { $null -ne $_.StartTime } | Select-Object -Property Name, $CpuPercent, Description | Sort-Object -Property CpuPercent, Name -Descending

    if ($Top -gt 0)
    {
        $Result = $Result | Select-Object -First $Top
    }
    return $Result
}

Get-ProcessCpuPercent -Top $Top
