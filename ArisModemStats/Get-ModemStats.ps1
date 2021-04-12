<#
.SYNOPSIS
Retrieves Up & Donwstream channel status data from an Arris cable-modem.
The retrieved data is displayed and optionally logged to a file.

.DESCRIPTION
The Arris cable-modem has a status page at: http://192.168.100.1
The Up/Downstream channel data contained in this page is parsed into 
PowerShell structures. The (Min,Average,Max and Range) statistics for
the Power & Signal/Noise values are evaluated over all then channels.
The sript outputs the channel data and statistics as tables to stdout.
This output can also be logged if the LogFile parameter is specified.
The modems power statistics is optionally appended to a csv file, 
to facilitate automated data collection and monitoring over time.

.PARAMETER LogName
This value is used to tag the logged data. The default is 'TM1602A'
which is the modem type this script was developed for.

.PARAMETER LogFile
The scripts output is not logged by default unless this parameter is 
specified. A timestamp is automatically appended to the logfile name 
to avoid overwriting the file when the script is invoked repeatedly 
with the same LogFile argument.

.PARAMETER CsvFile
Specifiy this parameter in order to append the modems power statistics 
into a csv file.

.NOTES
Task scheduler command to run this powershell script (assumed to be in the user\Documents\ folder):
PowerShell.exe -NonInteractive -ExecutionPolicy Bypass -file ~\Documents\Get-ModemStatus.ps1 -CsvFile ~\Documents\ModemStats.csv
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $LogName = "TM1602A",

    [Parameter()]
    $LogFile = $null,

    [Parameter()]
    $CsvFile = $null
)


function Get-ModemStatusPage
{
    [OutputType([string])]
    $BaseUri = "http://192.168.100.1"
    $Reply = Invoke-RestMethod -Uri $BaseUri -Method Get
    if ($Reply)
    {
        $StatusUrl= "$BaseUri/cgi-bin/status_cgi"
        if ($Reply -match 'url\=(?<url>.*)\"')
        {
            $StatusUrl = "$BaseUri$($Matches.Url)"
        }
        $StatusPage = Invoke-RestMethod -Uri $StatusUrl -Method Get
        return $StatusPage
    }
}


function Read-ModemChannels
{
    [OutputType("Modem.Channels")]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string] $StatusPage
    )
    [array] $DownStreamS = $null
    [array] $UpStreamS = $null
    if ($StatusPage)
    {
        $LineS = ($StatusPage -replace "\<tr\>\<td\>","`n<tr><td>") -split "`n" | Select-String -Pattern "^\<tr\>\<td\>"
        $DnLineS = $LineS | Select-String -Pattern "Downstream"
        $Doc = [xml]"<dn>$DnLineS</dn>"
        $DownStreamS = foreach ($line in $Doc.dn.tr)
        {
            $Freq = $Power = $Snr = $null
            if (![single]::TryParse(($line.td[2] -split " ")[0], [ref]$Freq))
            {
                $Freq = $null
            }
            if (![single]::TryParse(($line.td[3] -split " ")[0], [ref]$power))
            {
                $Power = $null
            }
            if (![single]::TryParse(($line.td[4] -split " ")[0], [ref]$Snr )) 
            {
                $Snr = $null
            }
            $Octets = $Correcteds = $Uncorrectables = $null
            if (![int]::TryParse($line.td[6], [ref]$Octets))
            {
                $Octets = $null
            }
            if (![int]::TryParse($line.td[7], [ref]$Correcteds))
            {
                $Correcteds = $null
            }
            if (![int]::TryParse($line.td[8], [ref]$Uncorrectables ))
            {
                $Uncorrectables = $null
            }
            $DownStream= [PSCustomObject]@{
                PSTypeName      = "Modem.DownStream"
                Channel         = $line.td[0]
                DCID            = [int]$line.td[1]
                'Freq/MHz'      = $Freq
                'Power/dBmV'    = $Power
                'SNR/dB'        = $Snr
                Modulation      = $line.td[5]
                Octets          = $Octets
                Correcteds      = $Correcteds
                Uncorrectables  = $Uncorrectables
            }
            $DownStream
        }

        $UpLineS = $LineS | Select-String -Pattern "Upstream" | ForEach-Object { "$_</tr>" } # Fix bad xml
        $Doc = [xml]"<dn>$UpLineS</dn>"    
        $UpStreamS = foreach ($line in $Doc.dn.tr)
        {
            $Freq = $Power = $SymbolRate = $null
            [void] ([single]::TryParse(($line.td[2] -split " ")[0], [ref]$Freq))
            [void] ([single]::TryParse(($line.td[3] -split " ")[0], [ref]$power))
            [void] ([int]::TryParse(($line.td[5] -split " ")[0], [ref]$SymbolRate ))
            $UpStream= [PSCustomObject]@{
                PSTypeName      = "Modem.UpStream"
                Channel         = $line.td[0]
                UCID            = [int]$line.td[1]
                'Freq/MHz'      = $Freq
                'Power/dBmV'    = $Power
                ChannelType     = $line.td[4]
                'kSymbols/s'    = $SymbolRate
                Modulation      = $line.td[6]
            }
            $UpStream
        }
    }

    $ModemChannels = [PSCustomObject]@{
        PSTypeName = "Modem.Channels"
        DownStream = $DownStreamS
        UpStream   = $UpStreamS
    }
    return $ModemChannels
}


Function Get-ModemChannelStatistics
{
    [OutputType("Modem.ChannelStatistics")]
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$LogName, 

        [parameter(Mandatory = $true)]
        [DateTime]$TimeStamp, 

        [parameter(Mandatory = $true, ValueFromPipeline)]
        [PSTypeName("Modem.Channels")]$ModemChannels
    )
    
    $DownStream = $ModemChannels.DownStream
    $UpStream = $ModemChannels.UpStream

    if ($PSEdition -eq "Desktop")
    {
        $Dn = $DownStream.'Power/dBmV' | Measure-Object -Maximum -Minimum -Average
        $Sn = $DownStream.'SNR/dB'     | Measure-Object -Maximum -Minimum -Average
        $Up = $UpStream.'Power/dBmV'   | Measure-Object -Maximum -Minimum -Average
        $DnStd = $SnStd = $UpStd = ""
    }
    else
    {
        $Dn = $DownStream.'Power/dBmV' | Measure-Object -Maximum -Minimum -Average -StandardDeviation
        $Sn = $DownStream.'SNR/dB'     | Measure-Object -Maximum -Minimum -Average -StandardDeviation
        $Up = $UpStream.'Power/dBmV'   | Measure-Object -Maximum -Minimum -Average -StandardDeviation
        $DnStd = [math]::Round($Dn.StandardDeviation,1)
        $SnStd = [math]::Round($Sn.StandardDeviation,1)
        $UpStd = [math]::Round($Up.StandardDeviation,1)
    }

    $ChannelStatistics = [PSCustomObject]@{
        LogName = $LogName
        Date = $TimeStamp.ToString("yyyy-MM-dd")
        Time = $TimeStamp.ToString("HH:mm:ss")

        DnN = $Dn.Count
        DnPwrMin = $null
        DnPwrAvg = $null
        DnPwrMax = $null
        DnPwrRange = $null
        DnPwrStd = $DnStd

        DnSnrMin = $null
        DnSnrAvg = $null
        DnSnrMax = $null
        DnSnrRange = $null
        DnSnrStd = $SnStd

        UpN = $Up.Count
        UpPwrMin = $null
        UpPwrAvg = $null
        UpPwrMax = $null
        UpPwrRange = $null
        UpPwrStd = $UpStd
    }

    if ($Dn.Count -ne 0)
    {
        $ChannelStatistics.DnPwrMin = [math]::Round($Dn.Minimum,1)
        $ChannelStatistics.DnPwrAvg = [math]::Round($Dn.Average,1)
        $ChannelStatistics.DnPwrMax = [math]::Round($Dn.Maximum,1)
        $ChannelStatistics.DnPwrRange = [math]::Round($Dn.Maximum-$Dn.Minimum,1)

        $ChannelStatistics.DnSnrMin = [math]::Round($Sn.Minimum,1)
        $ChannelStatistics.DnSnrAvg = [math]::Round($Sn.Average,1)
        $ChannelStatistics.DnSnrMax = [math]::Round($Sn.Maximum,1)
        $ChannelStatistics.DnSnrRange = [math]::Round($Sn.Maximum-$Sn.Minimum,1)
    }

    if ($Up.Count -ne 0)
    {
        $ChannelStatistics.UpPwrMin = [math]::Round($Up.Minimum,1)
        $ChannelStatistics.UpPwrAvg = [math]::Round($Up.Average,1)
        $ChannelStatistics.UpPwrMax = [math]::Round($Up.Maximum,1)
        $ChannelStatistics.UpPwrRange = [math]::Round($Up.Maximum-$Up.Minimum,1)
    }

    $ChannelStatistics.PSTypenames.insert(0, "Modem.ChannelStatistics")
    return $ChannelStatistics
}


Function Out-ModemChannelSnapshot
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [DateTime]$TimeStamp, 

        [parameter(Mandatory = $true, ValueFromPipeline)]
        [PSTypeName("Modem.Channels")]$ModemChannels,

        [parameter(Mandatory = $false)]
        [PSTypeName("Modem.ChannelStatistics")]$ChannelStats = $null,

        [parameter(Mandatory = $false)]
        $LogFile = $null
    )

    $LogTxt = do {
        $TimeStamp

        $ModemChannels.DownStream | Format-Table
        if ($ChannelStats)
        {
            "Downstream - $($ChannelStats.LogName)"
            "Power/dBmV Min={0,4:f1}  Avg={1,4:f1}  Max={2,4:f1}  Range={3,4:f1}  N={4}" -f `
                $ChannelStats.DnPwrMin , $ChannelStats.DnPwrAvg, $ChannelStats.DnPwrMax, $ChannelStats.DnPwrRange, $ChannelStats.DnN
            "SNR  /dB   Min={0,4:f1}  Avg={1,4:f1}  Max={2,4:f1}  Range={3,4:f1}  N={4}" -f `
                $ChannelStats.DnSnrMin , $ChannelStats.DnSnrAvg, $ChannelStats.DnSnrMax, $ChannelStats.DnSnrRange, $ChannelStats.DnN
            ""
        }
    
        $ModemChannels.UpStream | Format-Table
        if ($ChannelStats)
        {
            "Upstream - $($ChannelStats.LogName)"
            "Power/dBmV Min={0,4:f1}  Avg={1,4:f1}  Max={2,4:f1}  Range={3,4:f1}  N={4}" -f `
                $ChannelStats.UpPwrMin , $ChannelStats.UpPwrAvg, $ChannelStats.UpPwrMax, $ChannelStats.UpPwrRange, $ChannelStats.UpN
            $Sym = $ModemChannels.UpStream."kSymbols/s" | Measure-Object -Maximum -Minimum -Average
            "kSymbols/s Min={0,4:f0}  Avg={1,4:f0}  Max={2,4:f0}  Range={3,4:f0}  N={4}" -f `
                $Sym.Minimum,$Sym.Average,$Sym.Maximum,($Sym.Maximum-$Sym.Minimum), $ChannelStats.UpN
            ""
        }
    } until ($true)

    Write-Output $LogTxt
    if ($LogFile)
    {
        $LogDir = Split-Path -Path $LogFile -Parent       
        if ($LogDir -and (!(Test-Path $LogDir)))
        {
            $null = New-Item -Path $LogDir -ItemType Directory
        }
        
        $Filename = Split-Path -Path $LogFile -LeafBase
        $Filetime = $TimeStamp.ToString("yyyyMMddTHHmmss")
        $FileExt = Split-Path -Path $LogFile -Extension
        $FilePath = "$LogDir\$Filename`_$Filetime`.$FileExt"
        $LogTxt | Set-Content -FilePath $FilePath -Encoding utf8
    }
}


Function Update-ModemChannelStats
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSTypeName("Modem.ChannelStatistics")]$ChannelStats,

        [parameter(Mandatory = $false)]
        $CsvFile = $null
    )

    if (!$CsvFile)
    {
        return
    }

    $LogDir = Split-Path -Path $CsvFile -Parent       
    if ($LogDir -and (!(Test-Path $LogDir)))
    {
        $null = New-Item -Path $LogDir -ItemType Directory
    }

    if (Test-Path $CsvFile)
    {
        $ChannelStats | Export-Csv -Path $CsvFile -Encoding utf8 -Append
    }
    else 
    {
        $ChannelStats | Export-Csv -Path $CsvFile -Encoding utf8 -NoTypeInformation
    }
}


$ErrorActionPreference = "Continue"

$TimeStamp = Get-Date 
$Channels = Get-ModemStatusPage | Read-ModemChannels
$ChannelStats = $Channels | Get-ModemChannelStatistics -LogName $LogName -TimeStamp $TimeStamp

Out-ModemChannelSnapshot -TimeStamp $TimeStamp -ModemChannels $Channels -ChannelStats $ChannelStats -LogFile $LogFile
Update-ModemChannelStats -ChannelStats $ChannelStats -CsvFile $CsvFile
