
# Dot-Source charting API's
. "$PSScriptRoot\PsCharting.ps1"


# Generate some Data to plot
$NSamples = 100
$PointS = foreach ($i in 1..$NSamples)
{
    $Step = $i/$NSamples # 0..1
    [PSCustomObject]@{ 
        x = $i
        f1 = [math]::Sin(3.14159* 2*$Step)
        f2 = 2 * [math]::Abs(1 - 2*$Step) -1
        f3 = 8 * ($Step-0.5) * ($Step-0.5) -1
    }
}


# Create the main [Forms.DataVisualization.Charting.Chart] object
# New-Chart() creates a default ChartArea and Legend
$Chart = New-Chart -Title "Powershell Charting Example" -LegendDocking Bottom #-Width 1024 -Height 800
#$Chart = New-Chart -Title "Powershell Charting Example" -NoLegend

# Modify some default ChartArea properties:
$ChartArea = $Chart.ChartAreas[0]
$ChartArea.AxisY.Title = "Y-Axis Title"
$ChartArea.AxisX.Title = "X-Axis Title"
$ChartArea.AxisX.Interval = 10

# Create ChartSeries
$Series1 = New-ChartSeries -SeriesName "Sin"   -Chart $Chart -ChartType FastLine
$Series2 = New-ChartSeries -SeriesName "| X |" -Chart $Chart -XValues $PointS.X -YValues $PointS.f2
$Series2.ChartType = [Windows.Forms.DataVisualization.Charting.SeriesChartType]::FastLine
$Series3 = New-ChartSeries -SeriesName "Sqr"   -Chart $Chart -ChartType Column
Foreach ($Point in $PointS) 
{
    [void]$Series1.Points.AddXY($Point.x, $Point.f1) # Explicitly bind each data point to the series
    # $Series3 ... See alternate DataBindXY() method in next line
}
$Series3.Points.DataBindXY($PointS.x, $PointS.f3)



# Display the Chart
$SaveFile = $null
#$SaveFile = "$Pwd\PsChartExample"
if ($SaveFile)
{
    #$ImageType = "JPEG"
    #$ImageType = "BMP"
    #$ImageType = "GIF"
    $ImageType = "PNG"
    $SaveFile += ".$ImageType"
    $Chart.SaveImage($SaveFile, $ImageType)
    # https://docs.microsoft.com/en-us/dotnet/api/system.windows.forms.datavisualization.charting.chart.saveimage?view=netframework-4.8
    & $SaveFile # Spwan a new process to show the chart
}
else 
{
    # Show the chart in a modal window 
    Show-Chart -Chart $Chart -WindowTitle "PsChartExample"
}
