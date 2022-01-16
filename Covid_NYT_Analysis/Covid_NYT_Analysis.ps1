
<#
.SYNOPSIS
Downloads the latest(todays) covid 19 data from the NYT GIT repo.
The data is then filtered for the specified state and counties.
Then we plot 2 graphs: 
	1) Number of Covid cases by county
	3) Number of Covid deaths by county

.EXAMPLE
Plot the cases and deaths for the default NY counties: suffolk, nassau
.\Covid_NYT_Analysis.ps1

.EXAMPLE
Output a table of daily stats for: New York City
.\Covid_NYT_Analysis.ps1 -State "New York" -CountieS "New York City" -Passthru

.EXAMPLE
Output a list of counties in the state of california
.\Covid_NYT_Analysis.ps1 -State california -ListCounties
#>
[CmdletBinding()]
param (
	[Parameter()]
	[string] $State = "New York",
	[Parameter()]
	[string[]] $CountieS = @("suffolk", "nassau", "New York City"),
	[Parameter()]
	[datetime] $StartDate = 0,
	[Parameter()]
	[switch] $Passthru,
	[Parameter()]
	[switch] $ListCounties
)



#Region Retrieve Data

<#
.Example
 Select-DataByRegion -Data $AllCounties -State "New York" -CountieS @("suffolk", "nassau")
#>
function Select-DataByRegion($Data, $State=$null, [string[]] $CountieS=$null)
{
	if ($State)
	{
		if ($CountieS)
		{
			return $Data | Where-Object { $_.state -eq $State -and $CountieS -contains $_.county }
		}
		else
		{
		 	return $Data | Where-Object { $_.state -eq $State }
		}
	}
	elseif ($CountieS)
	{
		return $Data | Where-Object { $CountieS -contains $_.county }
	}
	throw New-Object argumentexception("No State and|or County specified to Select-DataByRegion()")
}



function Get-NYT_CovidGitFile($FileName = "us-counties.csv", $OutFile = "covid_nyt_us-counties.csv")
{
	$gitUrl = "https://raw.githubusercontent.com"
	$gitOwner = "nytimes"
	$gitRepo = "covid-19-data"
	$gitBranch = "master"	
	$FileUrl = "$gitUrl/$gitOwner/$gitRepo/$gitBranch/$FileName"
	Invoke-RestMethod -Uri $FileUrl -OutFile $OutFile
}


<#
.SYNOPSIS
Download the latest(todays) covid 19 data from the NYT GIT repo to a csv file.
Returns the read in csv
#>
function Get-NYT_CovidData_AllCounties
{
	$TodayName = Get-Date -Format "MMMdd"
	$AllDateFile = "covid__us-counties_$TodayName.csv"
	if (!(Test-Path $AllDateFile))
	{
		Write-Host "Downloading $TodayName Covid-19 Data From NYT - https://github.com/nytimes/covid-19-data" -ForegroundColor Yellow
		Get-NYT_CovidGitFile -OutFile $AllDateFile
	}
	Write-Host "Parsing $TodayName Covid-19 Data From $AllDateFile ..." -ForegroundColor Yellow
	$AllCounties = Import-Csv -Path $AllDateFile
	return $AllCounties
}


<#
.SYNOPSIS
1st Download the latest(todays) covid 19 data from the NYT GIT repo to a csv file.
2nd Filter out data for a state (takes a long time)
3rd Save the extracted state data to a csv file so that its quickly retrieved on the next call
Returns the state dataset

.EXAMPLE
$LongIslandData = Get-NYT_CovidData -State "New York"
#>
function Get-NYT_CovidStateData([string] $State, [datetime] $StartDate = $null)
{
	$TodayName = Get-Date -Format "MMMdd"
	$StateName = $State.Replace(" ","")
	$StateFile = ".\covid_$($StateName)_$($TodayName).csv"
	$StateData = $null

	if (Test-Path $StateFile)
	{
		$StateData = Import-Csv -Path $StateFile
	}
	elseif ($State)
	{
		$AllData = Get-NYT_CovidData_AllCounties
		Write-Host "Analyzing $State Covid-19 Data From NYT($TodayName) ..." -ForegroundColor Yellow
		$StateData = Select-DataByRegion -Data $AllData -State $State #-CountieS $CountieS
		$StateData = $StateData | Sort-Object "County", "Date"
		$AddDelta = $true
		if ($AddDelta)
		{
			$LastFips = $null
			[int]$LastCases = 0
			[int]$LastDeaths = 0
			foreach ($Daily in $StateData) 
			{
				if ($LastFips -eq $Daily.Fips)
				{
					$DeltaValueS = [ordered] @{
						dCases  = $Daily.Cases - $LastCases
						dDeaths = $Daily.Deaths - $LastDeaths			
					}
				}
				else 
				{
					$DeltaValueS = [ordered] @{
						dCases  = 0
						dDeaths = 0
					}
					$LastFips = $Daily.Fips
				}
				$Daily | Add-Member -NotePropertyMembers $DeltaValueS
				$LastCases = $Daily.Cases
				$LastDeaths = $Daily.Deaths
			}
		}
		$StateData | Export-Csv -Path $StateFile 
	}

	if ($StartDate -gt (Get-Date "2020-01-1"))
	{
		$DateStr = $StartDate.Date.ToString("yyyy-MM-dd")
		$StateData = $StateData | Where-Object { $_.Date -ge $DateStr }
	}
	return $StateData
}


function Get-NYT_CountyNames([string] $State = $null)
{
	if ($State)
	{
		$AllCounties = Get-NYT_CovidStateData -State $State
		$UniqueCounties = $AllCounties | Sort-Object county -Unique
	}
	else 
	{
		$AllCounties = Get-NYT_CovidData_AllCounties
		$UniqueCounties = $AllCounties | Sort-Object state, county -Unique
	}
	return $UniqueCounties | Select-Object State, County, Fips
}

#EndRegion Retrieve Data


######## Main ########
if ($ListCounties)
{
	Get-NYT_CountyNames -State $State
	return
}

#Region Report Results
$StateData = Get-NYT_CovidStateData -State $State -StartDate $StartDate

if ($Passthru)
{
	$Dataset = Select-DataByRegion -Data $StateData -CountieS $CountieS
	return $Dataset | Sort-Object "County", "Date" | Format-Table -Property date, county, cases, deaths
}

$ReportGraph = $true
if ($ReportGraph)
{
	$PsChartingFile = "$PSScriptRoot\PsCharting.ps1"
	if (!(Test-Path $PsChartingFile))
	{
		Throw "Can't find powershell script to graph data: Graphing PsCharting.ps1"
	}

	. $PsChartingFile
	$ChartS = @()

	######## Cases #########
	########################
	# Create the main [Forms.DataVisualization.Charting.Chart] object
	$Chart = New-Chart -Title "Covid-19 Total Cases" -LegendDocking Bottom #-Width 1024 -Height 800

	# Modify some default ChartArea properties:
	$ChartArea = $Chart.ChartAreas[0]
	$ChartArea.AxisY.Title = "Total Cases"
	$ChartArea.AxisX.Title = "Date"
	$ChartArea.AxisX.Interval = 10

	# Create ChartSeries
	foreach ($County in $CountieS)
	{
		$Data = Select-DataByRegion -Data $StateData -CountieS $County
		$Series = New-ChartSeries -SeriesName $County -Chart $Chart -ChartType FastLine -XValues $Data.Date -YValues $Data.Cases
		$Series | Write-Debug
	}

	# Show the chart in a modal window 
	$ChartS += Show-Chart -Chart $Chart -WindowTitle "NYT Covid-19 Cases" -Passthru


	######## dCases #########
	########################
	# Create the main [Forms.DataVisualization.Charting.Chart] object
	$Chart = New-Chart -Title "Covid-19 Daily Cases" -LegendDocking Bottom #-Width 1024 -Height 800

	# Modify some default ChartArea properties:
	$ChartArea = $Chart.ChartAreas[0]
	$ChartArea.AxisY.Title = "Daily Cases"
	$ChartArea.AxisX.Title = "Date"
	$ChartArea.AxisX.Interval = 10

	# Create ChartSeries
	foreach ($County in $CountieS)
	{
		$Data = Select-DataByRegion -Data $StateData -CountieS $County
		$Series = New-ChartSeries -SeriesName $County -Chart $Chart -ChartType FastLine -XValues $Data.Date -YValues $Data.dCases
		$Series | Write-Debug
	}

	# Show the chart in a modal window 
	$ChartS += Show-Chart -Chart $Chart -WindowTitle "NYT Covid-19 Cases" -Passthru


	######## Deaths ########
	########################
	$Chart = New-Chart -Title "Covid-19 Total Deaths" -LegendDocking Bottom #-Width 1024 -Height 800

	# Modify some default ChartArea properties:
	$ChartArea = $Chart.ChartAreas[0]
	$ChartArea.AxisY.Title = "Total Deaths"
	$ChartArea.AxisX.Title = "Date"
	$ChartArea.AxisX.Interval = 7

	# Create ChartSeries
	# Create ChartSeries
	foreach ($County in $CountieS)
	{
		$Data = Select-DataByRegion -Data $StateData -CountieS $County
		$Series = New-ChartSeries -SeriesName $County -Chart $Chart -ChartType FastLine -XValues $Data.Date -YValues $Data.deaths
		$Series | Write-Debug
	}

	# Show the chart in a modal window 
	$ChartS += Show-Chart -Chart $Chart -WindowTitle "NYT Covid-19 Deaths" -Passthru


	######## dDeaths ########
	########################
	$Chart = New-Chart -Title "Covid-19 Daily Deaths" -LegendDocking Bottom #-Width 1024 -Height 800

	# Modify some default ChartArea properties:
	$ChartArea = $Chart.ChartAreas[0]
	$ChartArea.AxisY.Title = "Daily Deaths"
	$ChartArea.AxisX.Title = "Date"
	$ChartArea.AxisX.Interval = 7

	# Create ChartSeries
	# Create ChartSeries
	foreach ($County in $CountieS)
	{
		$Data = Select-DataByRegion -Data $StateData -CountieS $County
		$Series = New-ChartSeries -SeriesName $County -Chart $Chart -ChartType FastLine -XValues $Data.Date -YValues $Data.dDeaths
		$Series | Write-Debug
	}

	# Show the chart in a modal window 
	$ChartS += Show-Chart -Chart $Chart -WindowTitle "NYT Covid-19 Deaths" -Passthru

	# Show all the charts, Closing the first 1 closes all the others
	$ParentChart = $ChartS[0]
	$ChildChartS = $ChartS[1..($ChartS.Count - 1)]
	$ParentChart.Add_Shown({ $ChildChartS | ForEach-Object { $_.Owner = $ParentChart; $_.Show() } })
	$ParentChart.ShowDialog()
}

#EndRegion Report Results
