# Dot-Source charting API's
. "$PSScriptRoot\PsCharting.ps1"


# Read in the data
$ChannelStatS = Import-Csv -Path $CsvFile -Encoding UTF8


# Create the main [Forms.DataVisualization.Charting.Chart] object
# New-Chart() creates a default ChartArea and Legend
$DnPrwChart = New-Chart -Title "Daily Downstream Power (bad when less than -5)" -LegendDocking Bottom

# Modify the default ChartArea properties:
$ChartArea = $DnPrwChart.ChartAreas[0]
$ChartArea.AxisY.Title = "Power / dBmV"
$ChartArea.AxisX.Interval = 24  # The data has 24 samples/day
#$ChartArea.AxisY.Maximum = [math]::Round(($ChannelStatS.DnPwrMax | Measure-Object -Maximum).Maximum/2)*2
#$ChartArea.AxisY.Minimum = [math]::Round(($ChannelStatS.DnPwrMin | Measure-Object -Minimum).Minimum/2)*2
Set-ChartAreaYAxisMax -ChartArea $ChartArea -ValueS $ChannelStatS.DnPwrMax
Set-ChartAreaYAxisMin -ChartArea $ChartArea -ValueS $ChannelStatS.DnPwrMin

# Create Downstream Power Series
$DnPwrMax = New-ChartSeries -SeriesName "Max" -Chart $DnPrwChart -ChartType FastLine
$DnPwrAvg = New-ChartSeries -SeriesName "Avg" -Chart $DnPrwChart -ChartType FastLine
$DnPwrMin = New-ChartSeries -SeriesName "Min" -Chart $DnPrwChart -ChartType FastLine

# For the first chart we explicitly initialize each $Date label & add each data points to the chart
# In subsequent charts use New-ChartSeries() to add all the data with a single call
[string[]] $DateS = $null
Foreach ($Stat in $ChannelStatS) 
{
    $DatePart = (Get-Date $Stat.Date).ToString("MMM-dd")
    if ($ChannelStatS.Count -lt 336) # 2 weeks
    {
        # We create detailed labels having 2-lines if there is enough room (not to much data)
        $TimePart = $($Stat.Time).Substring(0,5)
        $Date = "$TimePart`n$DatePart"
    }
    else 
    {
        # With so many data points we only wand a simple shart label
        $Date = $DatePart
    }
    $DateS += $Date  # Cache the label for reuse in sub-sequent charts
    # Add a data point to each of the charts
    [void]$DnPwrMin.Points.AddXY($Date, $Stat.DnPwrMin)
    [void]$DnPwrAvg.Points.AddXY($Date, $Stat.DnPwrAvg)
    [void]$DnPwrMax.Points.AddXY($Date, $Stat.DnPwrMax)
}


# Create Downstream SNR Chart & Series
$DnSnrChart = New-Chart -Title "Daily Downstream Signal/Noise (bad when less than 31)" -LegendDocking Bottom -NoChartArea
$ChartArea = New-ChartArea -Chart $DnSnrChart -TitleY "Signal to Noise / dB" -IntervalX 24
Set-ChartAreaYAxisMax -ChartArea $ChartArea -ValueS $ChannelStatS.DnSnrMax
Set-ChartAreaYAxisMin -ChartArea $ChartArea -ValueS $ChannelStatS.DnSnrMin
$null = New-ChartSeries -SeriesName "Max" -Chart $DnSnrChart -ChartType FastLine -xValueS $DateS -yValueS $ChannelStatS.DnSnrMax
$null = New-ChartSeries -SeriesName "Avg" -Chart $DnSnrChart -ChartType FastLine -xValueS $DateS -yValueS $ChannelStatS.DnSnrAvg
$null = New-ChartSeries -SeriesName "Min" -Chart $DnSnrChart -ChartType FastLine -xValueS $DateS -yValueS $ChannelStatS.DnSnrMin


# Create Upstream Power Chart & Series
$UpPwrChart = New-Chart -Title "Daily Upstream Power (bad when more than 49)" -LegendDocking Bottom -NoChartArea
$ChartArea = New-ChartArea -Chart $UpPwrChart -TitleY "Power / dBmV" -IntervalX 24
Set-ChartAreaYAxisMax -ChartArea $ChartArea -ValueS $ChannelStatS.UpPwrMax
Set-ChartAreaYAxisMin -ChartArea $ChartArea -ValueS $ChannelStatS.UpPwrMin
$null = New-ChartSeries -SeriesName "Min" -Chart $UpPwrChart -ChartType FastLine -xValueS $DateS -yValueS $ChannelStatS.UpPwrMin
$null = New-ChartSeries -SeriesName "Avg" -Chart $UpPwrChart -ChartType FastLine -xValueS $DateS -yValueS $ChannelStatS.UpPwrAvg
$null = New-ChartSeries -SeriesName "Max" -Chart $UpPwrChart -ChartType FastLine -xValueS $DateS -yValueS $ChannelStatS.UpPwrMax


# Show the chart in a modal window 
Show-Chart -Chart $DnPrwChart -WindowTitle "Modem-Statistics" -IconFile "bars.ico"
Show-Chart -Chart $DnSnrChart -WindowTitle "Modem-Statistics" -IconFile "bars.ico"
Show-Chart -Chart $UpPwrChart -WindowTitle "Modem-Statistics" -IconFile "bars.ico"

# Save the chart to a file
if ($ImageFile)
{
    $DnPrwChart.SaveImage("$ImageFile`_DnPwr.png", "png")
    $DnSnrChart.SaveImage("$ImageFile`_DnSnr.png", "png")
    $UpPwrChart.SaveImage("$ImageFile`_UpPwr.png", "png")
}
