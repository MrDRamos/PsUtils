
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
Ineractively select the conties for California from a Pick list
.\Covid_NYT_Analysis.ps1 -State California
#>
[CmdletBinding()]
param (
	[Parameter()]
	#[string] $State = $null,
	[string] $State = "New York",
	[Parameter()]
	#[string[]] $CountieS = $null,
	[string[]] $CountieS = @("suffolk", "nassau", "New York"),
	[Parameter()]
	[datetime] $StartDate = 0,
	[Parameter()]
	[switch] $Passthru
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
1st Download the latest(todays) covid 19 data from the NYT GIT repo to a csv file.
2nd Filter out data for one or more states (takes a long time)
Returns the dataset for the selected states, default is all states (several GB)

.EXAMPLE
$LongIslandData = Get-NYT_CovidStateData -State "New York"
#>
function Get-NYT_CovidStateData([string[]] $State = $null)
{
	$TodayName = Get-Date -Format "MMMdd"
	$TodaysFilename = "covid__us-counties_$TodayName.csv"
	if (!(Test-Path $TodaysFilename))
	{
		Write-Host "Downloading $TodayName Covid-19 Data From NYT - https://github.com/nytimes/covid-19-data" -ForegroundColor Yellow
		Get-NYT_CovidGitFile -OutFile $TodaysFilename
	}
	$StateNames = $State -join "','"
	Write-Host "Extracting '$StateNames' Covid-19 Data From $TodaysFilename ..." -ForegroundColor Yellow
	if ($State)
	{
		$NytStateData = Import-Csv -Path $TodaysFilename | Where-Object { $State -contains $_.State }
	}
	else 
	{
		$NytStateData = Import-Csv -Path $TodaysFilename
	}
	
	return $NytStateData
}


function Expand-NYT_CovidStateData($NytStateData, $CountyInfoS)
{
	$AllFips = $CountyInfoS.Fips
	$CountyInfo = $null
	$LastFips = $null
	[int]$LastCases = 0
	[int]$LastDeaths = 0
	foreach ($Daily in $NytStateData) 
	{
		if (!$Daily.Fips -and $Daily.County -eq "New York City") # Fix NYT nonstandard naming convention
		{
			$Daily.County = "New York"
			$Daily.Fips = "36061"
		}
		if ($AllFips -contains $Daily.Fips)
		{
			if ($LastFips -eq $Daily.Fips)
			{
				$DailyCases = $Daily.Cases - $LastCases
				$DailyDeaths = $Daily.Deaths - $LastDeaths

				$DeltaValueS = [ordered] @{
					CasesPct       = $Daily.Cases / $CountyInfo.Population
					DeathsPct      = $Daily.Deaths / $CountyInfo.Population
					DailyCases     = $DailyCases
					DailyDeaths    = $DailyDeaths
					DailyCasesPct  = $DailyCases / $CountyInfo.Population
					DailyDeathsPct = $DailyDeaths / $CountyInfo.Population
				}
			}
			else 
			{
				$LastFips = $Daily.Fips
				$CountyInfo = $CountyInfoS | Where-Object { $_.Fips -eq $LastFips }
				$DeltaValueS = [ordered] @{
					CasesPct       = 0
					DeathsPct      = 0
					DailyCases     = 0
					DailyDeaths    = 0
					DailyCasesPct  = 0
					DailyDeathsPct = 0
				}
			}
			$Daily | Add-Member -NotePropertyMembers $DeltaValueS
			$LastCases = $Daily.Cases
			$LastDeaths = $Daily.Deaths
		}
	}
}


<#
.SYNOPSIS
1st Download the latest(todays) covid 19 data from the NYT GIT repo to a csv file.
2nd Filter out data for a state (takes a long time)
3rd Expand the raw NTY data with: a) daily values and b) % of population values
4th Save the extracted state data to a csv file so that its quickly retrieved on the next call
5th Filter the returned data for the StartDate and counties names specified in CountyInfoS
Returns a daily time-series for each wanted county in a hashtable by county name
#>
function Select-CovidDataByCounty([array] $CountyInfoS, [datetime] $StartDate = $null)
{
	$TodayName = Get-Date -Format "MMMdd"

	$NeededStateS = $CountyInfoS.State | Sort-Object -Unique

	#region Generate expanded NYT datasets
	$MissingStateS = @()
	foreach ($State in $NeededStateS) 
	{
		$StateName = $State.Replace(" ", "")
		$StateFile = ".\covid_$($StateName)_$($TodayName).csv"
		if (!(Test-Path $StateFile))
		{
			$MissingStateS += $State;
		}
	}
	if ($MissingStateS)
	{
		$NytStateData = Get-NYT_CovidStateData -State $MissingStateS
		if ($NytStateData)
		{
			$NytByStateS = @{}
			$MissingStateS | ForEach-Object { $NytByStateS.Add($_, [System.Collections.ArrayList]::new()) }
			foreach ($Item in $NytStateData)
			{
				if ($MissingStateS -contains $Item.State)
				{
					[void]$NytByStateS[$Item.State].Add($Item)
				}
			}

			$AllCountyInfoS = Get-UsCensus_ByCounty #-Force
			foreach ($State in $MissingStateS)
			{
				Write-Host "Preserving '$State' Covid-19 Data From NYT($TodayName) ..." -ForegroundColor Yellow
				$StateName = $State.Replace(" ", "")
				$StateFile = ".\covid_$($StateName)_$($TodayName).csv"

				$StateCountyInfo = $AllCountyInfoS | Where-Object { $_.State -eq $State }
				$StateData = $NytByStateS[$State] | Sort-Object -Property County, Date
				Expand-NYT_CovidStateData -NytStateData $StateData -CountyInfoS $StateCountyInfo
				$StateData | Export-Csv -Path $StateFile -NoTypeInformation	
			}
		}
	}
	#endregion Generate expanded NYT dataset


	$StartDateStr = $null
	if ($StartDate -gt (Get-Date "2020-01-1"))
	{
		$StartDateStr = $StartDate.Date.ToString("yyyy-MM-dd")
	}

	$DataByCounty = @{}
	foreach ($State in $NeededStateS) 
	{
		$StateName = $State.Replace(" ", "")
		$StateFile = ".\covid_$($StateName)_$($TodayName).csv"
		$StateData = Import-Csv -Path $StateFile
		$CountyS = $CountyInfoS | Where-Object { $_.State -eq $State }
		foreach ($CountyInfo in $CountyS) 
		{
			$CountyData = $StateData | Where-Object { $_.Fips -eq $CountyInfo.Fips -and $_.Date -ge $StartDateStr }
			$DataByCounty[$CountyInfo.County] = $CountyData | Sort-Object -Property Date
		}
	}
	return $DataByCounty
}


function Get-UsCensus_ByCounty([switch] $Force)
{
	$CenPop2020File = ".\CenPop2020_ByCounty.csv"
	if ($Force -or !(Test-Path $CenPop2020File))
	{
		$PopByCountyUri = "https://www2.census.gov/geo/docs/reference/cenpop2020/county/CenPop2020_Mean_CO.txt"
		$PopByCountyRaw = (Invoke-RestMethod -Method Get -Uri $PopByCountyUri).Remove(0, 3) # Remove the first 2 BOM chars
		$PopByCounty = foreach ($Item in ($PopByCountyRaw | ConvertFrom-Csv))
		{
			[PSCustomObject]@{
				State = $Item.STNAME
				County = $Item.COUNAME
				Fips   = $Item.STATEFP + $Item.COUNTYFP
				Population = $Item.POPULATION
				Latitude = $Item.LATITUDE
				Longitude = $Item.LONGITUDE
			} 
		}
		$PopByCounty | Export-Csv -Path $CenPop2020File -Force -NoTypeInformation
	}
	else 
	{
		$PopByCounty = Import-Csv -Path $CenPop2020File -Encoding utf8	
	}
	return $PopByCounty
}



#EndRegion Retrieve Data


######## Main ########
$PopByCounty = Get-UsCensus_ByCounty #-Force
if (!$State)
{
	$State = $PopByCounty | Select-Object State -Unique | Out-GridView -OutputMode Single -Title "Select a State"
}
if (!$State)
{
	return
}

if ($CountieS)
{
	$CountyInfoS = $PopByCounty | Where-Object { $_.State -eq $State -and $CountieS -contains $_.County }
}
else
{
	$CountyInfoS = $PopByCounty | Where-Object { $_.State -eq $State} | Out-GridView -OutputMode Multiple -Title "Select one or more Counties"
}
if (!$CountyInfoS)
{
	return
}


#Region Report Results
$DataByCounty = Select-CovidDataByCounty -CountyInfoS $CountyInfoS -StartDate $StartDate
if (!$DataByCounty)
{
	return
}

if ($Passthru)
{
	$DataByCounty.Values | Format-Table
	return
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
	foreach ($Kvp in $DataByCounty.GetEnumerator())
	{
		$Data = $Kvp.Value
		$Series = New-ChartSeries -SeriesName $Kvp.Key -Chart $Chart -ChartType FastLine -XValues $Data.Date -YValues $Data.CasesPct
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
	foreach ($Kvp in $DataByCounty.GetEnumerator())
	{
		$Data = $Kvp.Value
		$Series = New-ChartSeries -SeriesName $Kvp.Key -Chart $Chart -ChartType FastLine -XValues $Data.Date -YValues $Data.DailyCasesPct
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
	foreach ($Kvp in $DataByCounty.GetEnumerator())
	{
		$Data = $Kvp.Value
		$Series = New-ChartSeries -SeriesName $Kvp.Key -Chart $Chart -ChartType FastLine -XValues $Data.Date -YValues $Data.Deaths
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
	foreach ($Kvp in $DataByCounty.GetEnumerator())
	{
		$Data = $Kvp.Value
		$Series = New-ChartSeries -SeriesName $Kvp.Key -Chart $Chart -ChartType FastLine -XValues $Data.Date -YValues $Data.DailyDeaths
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
