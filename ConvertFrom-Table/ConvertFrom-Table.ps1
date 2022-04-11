<#
.SYNOPSIS
Converts an array of strings that are formated as rows of column data
into an array of Powershell PsCustomObjects.
The table must have a header line of column names seperated by spaces.
The column data must must be left alligned with the column name.

.PARAMETER RowS
The input row to parse.
Note: Blank rows and comment rows are ignored.

.PARAMETER HeaderRow
Optional value indicating the row that contains the column names.
The default is the first row that is not blank
Note: All row numbers is 0 based. 

.PARAMETER FirstRow
Optional value indicates the first data record to parse. 
Use this to skip over the first few lines after the column header row.
The default is the next row after the header.
Note: The line after the header row is automatically skipped if it
starts with -- or == characters.

.PARAMETER LastRow
Optional value specifies the last row to include.
The default is the last row.

.PARAMETER NumRows
Alternate value to indicate how many rows to parse, instead of specifying LastRow.

.PARAMETER Comment
A regex expression that defines which rows are comments. 
The default is rows that start with a # character.
#>
function ConvertFrom-Table
{
    [CmdletBinding(DefaultParameterSetName = 'LastRow')]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [array] $RowS,

        [Parameter()]
        [int] $HeaderRow = 0,

        [Parameter()]
        [int] $FirstRow = 0,

        [Parameter(ParameterSetName = 'LastRow')]
        [int] $LastRow = 0,

        [Parameter(ParameterSetName = "NumRows")]
        [int] $NumRows = 0,

        [Parameter()]
        [string] $Comment = '^#'
    )

    New-Variable -Name AnsiSeq -Value "$([char]0x1B)[" -Option Constant

    # $Input is an automatic variable that references the pipeline value
    if ($Input)
    {
        $RowS = $Input
    }

    # Skip over leading blank lines & commens until we reach the header containig the column names
    if (!$HeaderRow)
    {
        for ($HeaderRow= 0; $HeaderRow -lt $RowS.Count -1; $HeaderRow++)
        {
            $Line = $RowS[$HeaderRow]
            if ([string]::IsNullOrWhiteSpace($Line) -or $Line -match $Comment)
            {
                Continue
            }
            if ($Line.StartsWith($AnsiSeq))
            {
                break    
            }
            if ($Line -match "[\x00-\x1F]") # ignore leading lines with control characters
            {
                Continue
            }            
            break
        }
    }

    # Skip over the (optional) header line containing underscore characters
    if (!$FirstRow)
    {
        for ($FirstRow= $HeaderRow +1; $FirstRow -lt $RowS.Count -1; $FirstRow++)
        {
            $Line = $RowS[$FirstRow]
            if ($Line.StartsWith('--') -or $Line.StartsWith('==') -or $Line.StartsWith($AnsiSeq))
            {
                Continue
            }
            break
        }
    }

    # Ensure $LastRow does no exceed actual number of rows
    if ($PSCmdlet.ParameterSetName -eq 'NumRows')
    {
        $LastRow = $FirstRow + $NumRows
    }
    if ($LastRow)
    {
        $LastRow = [math]::Min($LastRow, $RowS.Count -1)    
    }
    else 
    {
        $LastRow = $RowS.Count -1
    }
    

    # Parse the column names (and positions) in the header line
    $Hdr = $RowS[$HeaderRow]
    if ($Hdr -match "(?:\x1B\[[\d|;]+m)(.*)\x1B\[")
    {
        $Hdr = $Matches[1] # Remove embeded ANSI Color Sequences
    }
    $ColNameS = $Hdr.TrimEnd() -split " +"
    if ([string]::IsNullOrWhiteSpace($ColNameS[0]))
    {
        $ColNameS = $ColNameS[1..($ColNameS.Count-1)]
    }
    $ColPos = $ColNameS | ForEach-Object { $Hdr.IndexOf($_) }
    $ColS = for ($i= 0; $i -lt $ColNameS.Count -1; $i++)
    {
        [PSCustomObject]@{
            Name  = $ColNameS[$i]
            Start = $ColPos[$i]
            Len   = $ColPos[$i+1] - $ColPos[$i]
        }
    }
    $ColS += [PSCustomObject]@{ Name = $ColNameS[$ColNameS.Count-1]; Start = $ColPos[$ColNameS.Count-1]; Len = 0 }    

    # Process each data row
    foreach ($Row in $RowS[$FirstRow .. $LastRow]) 
    {
        if ([string]::IsNullOrWhiteSpace($Row) -or $Row -match $Comment)
        {
            continue    # Ignore empty lines and commens
        }
        $RetObj = New-Object -TypeName psobject
        foreach($Col in $ColS)
        {
            if ($Row.Length -ge $Col.Start)
            {
                if ($Col.Len -gt 0 -and $Row.Length -ge $Col.Start + $Col.Len)
                {
                    Add-Member -InputObject $RetObj -MemberType NoteProperty -Name $Col.Name -Value $Row.Substring($Col.Start, $Col.Len).TrimEnd()
                }
                else 
                {
                    Add-Member -InputObject $RetObj -MemberType NoteProperty -Name $Col.Name -Value $Row.Substring($Col.Start).TrimEnd()
                }
            }
            else 
            {
                Add-Member -InputObject $RetObj -MemberType NoteProperty -Name $Col.Name -Value $null
            
            }
        }
        $RetObj                
    }            
}




<# Example using output from: Get-Service
$TextRowS = Get-Service -Name win* | Out-String -Stream
$TextRowS
$ServiceS = $TextRowS | ConvertFrom-Table
$ServiceS | Format-Table
#>

<# Bad Example using output from: Get-Process
 # The column data is right alligned !
if (!$TextRowS)
{
    $TextRowS = Get-Process -Name win* | Out-String -Stream
    $TextRowS
    $WinProcS = $TextRowS | ConvertFrom-Table
    $WinProcS | Format-Table    
}
#>

<# Example using output from: winget upgrade
if (!$TextRowS)
{
    $ProgressPreference_Org = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $TextRowS = & winget upgrade
    $ProgressPreference = $ProgressPreference_Org
}

$UpgradeS = ConvertFrom-Table -RowS $TextRowS -LastRow ($TextRowS.Count -2) #-HeaderRow 2 -FirstRow 4
$UpgradeS | Format-Table

$TextRowS2 = $UpgradeS | Format-Table | Out-String -Stream
$TextRowS2[3] = "#$($TextRowS2[3])" # Add a comment
$UpgradeS2 = $TextRowS2 | ConvertFrom-Table
$UpgradeS2 | Format-Table

Compare-Object -ReferenceObject $UpgradeS -DifferenceObject $UpgradeS2 -Property 'Name'
#>
