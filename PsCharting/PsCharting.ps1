<#
.SYNOPSIS
  Plot the accumlated modem power statistics stored in the csv file
  Inspired by:
    https://www.sqlshack.com/create-charts-from-sql-server-data-using-powershell/
    https://www.alkanesolutions.co.uk/2019/03/13/charting-with-powershell/
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    $CsvFile = "$pwd\logs\ModemStats.csv",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    $ImageFile = "$pwd\ModemStats"
)


# load the appropriate assemblies 
Add-Type -AssemblyName "System.Windows.Forms"
Add-Type -AssemblyName "System.Windows.Forms.DataVisualization"


Function New-ChartArea
{
    [OutputType([System.Windows.Forms.DataVisualization.Charting.ChartArea])]
    [CmdletBinding()]
    param (
        [parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$Name = "DefaultChartArea",

        # Axis Title & labels
        [parameter()]
        [Drawing.Font]$Font = #"Sans Serif,16pt", # simple font definition
            #(New-Object Drawing.Font("Sans Serif",12)),
            (New-Object Drawing.Font("Sans Serif",12,[Drawing.Fontstyle]::Bold)),

        [parameter()]
        [string]$TitleX = "",
        
        [parameter()]
        [int]$IntervalX = 0,

        [parameter()]
        [string]$TitleY = "",

        [parameter()]
        [int]$IntervalY = 0,

        [parameter()]
        [Windows.Forms.DataVisualization.Charting.Chart]
        $Chart= $null
    )

    $NewChartArea = New-Object Windows.Forms.DataVisualization.Charting.ChartArea
    if ($null -eq $NewChartArea)
    {
        throw "Failed to create: Windows.Forms.DataVisualization.Charting.ChartArea"
    }

    $NewChartArea.Name = $Name

    $NewChartArea.AxisX.Title = $TitleX
    $NewChartArea.AxisX.Titlefont = $Font
    $NewChartArea.AxisX.LabelStyle.Font = $Font
    $NewChartArea.AxisX.Interval = $IntervalX
        
    $NewChartArea.AxisY.Title = $TitleY
    $NewChartArea.AxisY.Titlefont = $Font
    $NewChartArea.AxisY.LabelStyle.Font = $Font 
    $NewChartArea.AxisY.Interval = $IntervalY

    if ($Chart)
    {
        $Chart.ChartAreas.Add($NewChartArea)
    }
    return $NewChartArea
}


<#
  System.Windows.Forms.DataVisualization.Charting Namespace
  https://docs.microsoft.com/en-us/dotnet/api/system.windows.forms.datavisualization.charting?view=netframework-4.8
#>
Function New-Chart() 
{
    [OutputType([System.Windows.Forms.DataVisualization.Charting.Chart])]
    [CmdletBinding()]
    param (
        [parameter()]
        [int]$Width = 800,

        [parameter()]
        [int]$Height= 600,

        [parameter()]
        [Drawing.Color]$BackColor = [Drawing.Color]::White, #Transparent

        [parameter()]
        [string]$Title,

        [parameter()]
        [Drawing.Font]$TitleFont = #"Sans Serif,16pt", # simple font definition
            (New-Object Drawing.Font("Sans Serif",16,[Drawing.Fontstyle]::Bold)),

        # [Enum]::GetNames("Drawing.ContentAlignment")
        # TopLeft, TopCenter, TopRight
        # MiddleLeft, MiddleCenter, MiddleRight
        # BottomLeft, BottomCenter, BottomRight
        [parameter()]
        [Drawing.ContentAlignment]
        $TitleAlignment = [Drawing.ContentAlignment]::TopCenter,

        # Axis Title & labels
        [parameter()]
        [Drawing.Font]$ChartFont = #"Sans Serif,16pt", # simple font definition
            #(New-Object Drawing.Font("Sans Serif",12)),
            (New-Object Drawing.Font("Sans Serif",12,[Drawing.Fontstyle]::Bold)),

        [parameter()]
        [switch]$NoChartArea,

        # [Enum]::GetNames("Windows.Forms.DataVisualization.Charting.Docking")
        # Top, Right, Bottom, Left
        [parameter()]
        [Windows.Forms.DataVisualization.Charting.Docking]
        $LegendDocking = [Windows.Forms.DataVisualization.Charting.Docking]::Right,

        # [Enum]::GetNames("Drawing.StringAlignment")
        # Near, Center, Far
        [parameter()]
        [Drawing.StringAlignment]
        $LegendAlignment = [Drawing.StringAlignment]::Center,

        [parameter()]
        [switch]$NoLegend
    )
        
    $NewChart = New-object Windows.Forms.DataVisualization.Charting.Chart
    if ($null -eq $NewChart) 
    {
        throw "Failed to create: Windows.Forms.DataVisualization.Charting.Chart"
    }
    
    $NewChart.Width      = $Width 
    $NewChart.Height     = $Height
    $NewChart.BackColor  = $BackColor
    
    if (![String]::IsNullOrEmpty($Title)) 
    {
        [void]$NewChart.Titles.Add($Title)
        $NewChart.Titles[0].Font = $TitleFont
        $NewChart.Titles[0].Alignment = $TitleAlignment
    }

    if (!$NoChartArea) 
    {
        $null = New-ChartArea -Chart $NewChart -Font $ChartFont
    }
        
    if(!$NoLegend) 
    {
        # https://docs.microsoft.com/en-us/dotnet/api/system.windows.forms.datavisualization.charting.legend?view=netframework-4.8
        $Legend = New-Object Windows.Forms.DataVisualization.Charting.Legend
        $Legend.Name = "DefaultLegend"
        # By default, the legend is positioned in the top-right corner of the chart
        $Legend.Docking = $LegendDocking
        $Legend.Alignment = $LegendAlignment
        $Legend.Font = $ChartFont
        $NewChart.Legends.Add($Legend)
    }
    
    return $NewChart
}


Function New-ChartSeries() 
{
    [OutputType([System.Windows.Forms.DataVisualization.Charting.Series])]
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]$SeriesName,

        [parameter()]
        [Windows.Forms.DataVisualization.Charting.Chart]$Chart,

        [parameter()]
        [array]$XValueS = $null,

        [parameter()]
        [array]$YValueS = $null,

        [parameter()]
        [Alias("LineWidth")]
        [int]$BorderWidth = 2, # = The line thickness for line charts

        # [Enum]::GetNames("Windows.Forms.DataVisualization.Charting.ChartDashStyle")
        # NotSet, Dash, DashDot, DashDotDot, Dot, Solid
        [parameter()]
        [Alias("LineStyle")]
        [Windows.Forms.DataVisualization.Charting.ChartDashStyle]
        $BorderDashStyle = [Windows.Forms.DataVisualization.Charting.ChartDashStyle]::Solid,

        [parameter()]
        [boolean]$IsVisibleInLegend = $true,

        [parameter()]
        [string]$ChartAreaName = $null,

        [parameter()]
        [string]$LegendName = $null,

        [parameter()]
        [Drawing.Color]$Color = [Drawing.Color]::Transparent,

        # [Enum]::GetNames("Windows.Forms.DataVisualization.Charting.SeriesChartType")
		# Point,FastPoint,Bubble,Line,Spline,StepLine,FastLine,Bar,StackedBar,StackedBar100
		# Column,StackedColumn,StackedColumn100,Area,SplineArea,StackedArea,StackedArea100
		# Pie,Doughnut,Stock,Candlestick,Range,SplineRange,RangeBar,RangeColumn,Radar,Polar
		# ErrorBar,BoxPlot,Renko,ThreeLineBreak,Kagi,PointAndFigure,Funnel,Pyramid        
        [parameter()]        
        [Windows.Forms.DataVisualization.Charting.SeriesChartType]
        $ChartType = [Windows.Forms.DataVisualization.Charting.SeriesChartType]::Column
    )
    
    $NewSeries = New-Object Windows.Forms.DataVisualization.Charting.Series
    if ($null -eq $NewSeries) 
    {
        throw "Failed to create: Windows.Forms.DataVisualization.Charting.Series"
    }
    
    $NewSeries.Name                = $SeriesName
    $NewSeries.ChartType           = $ChartType 
    $NewSeries.BorderDashStyle     = $BorderDashStyle
    $NewSeries.BorderWidth         = $BorderWidth 
    $NewSeries.IsVisibleInLegend   = $IsVisibleInLegend 
    
    if (![string]::IsNullOrEmpty($ChartAreaName))
    {
        $NewSeries.ChartArea = $ChartAreaName
    }
    
    if (![string]::IsNullOrEmpty($LegendName))
    {
        $NewSeries.Legend = $LegendName
    }
    
    if ($Color -ne [Drawing.Color]::Transparent)
    {
        $NewSeries.Color = $Color
    }

    if ($XValueS -and $YValueS)
    {
        $NewSeries.Points.DataBindXY($XValueS, $YValueS)
    }

    if ($Chart)
    {
        $Chart.Series.Add($NewSeries)       
    }
    return $NewSeries
}


function Show-Chart() 
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $True)]
        [ValidateNotNull()]
        [Windows.Forms.DataVisualization.Charting.Chart]$Chart,

        [parameter()]
        [string]$WindowTitle = "PsChart",

        [parameter()]
        [int]$Width,

        [parameter()]
        [int]$Height,

        [parameter()]
        [string]$IconFile = $null,

        [parameter()]
        [switch]$Passthru
    )
       
    # Display the chart on a form     
    $Chart.Anchor =  [Windows.Forms.AnchorStyles]::Bottom `
                -bor [Windows.Forms.AnchorStyles]::Right `
                -bor [Windows.Forms.AnchorStyles]::Top `
                -bor [Windows.Forms.AnchorStyles]::Left

    # https://docs.microsoft.com/en-us/dotnet/api/system.windows.forms.form?view=netcore-3.1
    $NewWinForm = New-Object Windows.Forms.Form
    if ($null -eq $NewWinForm) 
    {
        throw "Failed to create: Windows.Forms.Form"
    }
    $NewWinForm.Text = $WindowTitle
    
    if ($null -eq $Width -or $Width -lt $Chart.Width) 
    {
        $Width = $Chart.Width
    }
    $NewWinForm.Width = $Width
    
    if ($null -eq $Height -or $Height -lt $Chart.Height) 
    {
        $Height = $Chart.Height * 1.05
    }    
    $NewWinForm.Height= $Height
    if ($IconFile)
    {
        $NewWinForm.Icon = New-Object System.Drawing.Icon($IconFile)
    }

    $NewWinForm.Controls.Add($Chart)
    if ($Passthru)
    {
        return $NewWinForm
    }
    else 
    {
        $NewWinForm.Add_Shown({ $NewWinForm.Activate() })
        $null = $NewWinForm.ShowDialog()   
    }
}


<#
.SYNOPSIS
  Scans ValueS for valid values i.e. Non-Numeric values are discarded
  Return the Mean,Population StandardDeviation, and valid sample count
#>
Function Find-ValidAvgStd([array]$ValueS)
{
    [OutputType([array])]
    [double]$Sum = [double]$Sum2 = 0
    [int]$N = 0
    foreach ($Value in $ValueS) 
    {
        [double] $X = 0
        if ([double]::TryParse($Value, [ref]$X))
        {
            $Sum += $X
            $Sum2 += $X * $X
            $N += 1    
        }
    }
    if (!$N)
    {
        return @(0,0,0)
    }
    $Avg = $Sum/$N
    $Var = $Sum2/$N - $Avg*$Avg
    return @($Avg, [math]::Sqrt($Var), $N)
}


<#
.SYNOPSIS
  Scans ValueS for valid values i.e. Non-Numeric values are discarded
  Return the MinValue, MinIndex, MaxValue, MaxIndex & valid sample count
#>
Function Find-ValidMinMax([array]$ValueS)
{
    [OutputType([array])]
    [double]$Min = [double]::MaxValue
    [double]$Max = [double]::MinValue
    [int]$N = 0
    $MinN = $MaxN = $null
    foreach ($Value in $ValueS) 
    {
        [double] $X = 0
        if ([double]::TryParse($Value, [ref]$X))
        {
            if ($X -gt $Max)
            {
                $Max = $x;
                $MaxN = $N
            }
            if ($X -lt $Min)
            {
                $Min = $x;
                $MinN = $N
            }
            $N += 1    
        }
    }
    if (!$N)
    {
        return @(0,0,0)
    }
    return @($Min, $MinN, $Max, $MaxN, $N)
}

Function Set-ChartAreaYAxisMax($ChartArea, [array]$ValueS)
{
    $YMin, $MinN, $YMax, $MaxN, $N = Find-ValidMinMax -Values $ValueS
    $ChartArea.AxisY.Maximum = [math]::Round($YMax +.5)
}

Function Set-ChartAreaYAxisMin($ChartArea, [array]$ValueS)
{
    $YMin, $MinN, $YMax, $MaxN, $N = Find-ValidMinMax -Values $ValueS
    $ChartArea.AxisY.Minimum = [math]::Round($YMin -.5)
}



