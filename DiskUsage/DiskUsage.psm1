
<#
.SYNOPSIS
Measures the amount of disk space used, and the number of file contained, by the items in the specified path,
The arguments and aliases were patterned after the UNIX du (disk-usage) utility

.DESCRIPTION
Long description

.PARAMETER Path
Parameter description

.PARAMETER Include
Parameter description

.PARAMETER Exclude
Parameter description

.PARAMETER FullName
Parameter description

.PARAMETER Total
Parameter description

.PARAMETER Summarize
Parameter description

.PARAMETER All
Parameter description

.PARAMETER Depth
Parameter description

.EXAMPLE
Get usage stats for all files in and under the users document folder
Measure-DiskUsage $Home\Documents -All

.EXAMPLE
Get usage stats for .exe files in the 'Program Files' folder. 
Ignore directories with privileged access errors
Measure-DiskUsage $ENV:ProgramFiles -ErrorAction Ignore -All -Include *.exe

.EXAMPLE
Get a single summery for all the files in the 'Program Files' folder. 
Ignore directories with privileged access errors
Measure-DiskUsage $ENV:ProgramFiles -ErrorAction Ignore -All -Summarize
#>
function Measure-DiskUsage
{
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [Parameter(ValueFromPipeline)]
        [object] $Path = ".",

        [Parameter()]
        [array] $Include = $null,

        [Parameter()]
        [array] $Exclude = $null,

        [Parameter()]
        [switch] $FullName,

        [Parameter()]
        [Alias("c")]
        [switch] $Total,

        [Parameter()]
        [Alias("s")]
        [switch] $Summarize,

        [Parameter()]
        [Alias("a")]
        [switch] $All,

        [Parameter()]
        [Alias("d")]
        [int] $Depth = 1000
    )

    [double] $TotalBytesUsed = 0
    [int] $TotalFileCount = 0
    $Depth = [math]::Max($Depth-1, 0)

    if ($All -and ($Include -or $Exclude))
    {
        [double] $BytesUsed = 0
        [int] $FileCount = 0
        $FileS = Get-ChildItem -Path "$Path\*" -File -Include $Include -Exclude $Exclude -ErrorAction $ErrorActionPreference
        foreach ($Item in $FileS) 
        {
            $BytesUsed += $Item.Length
            $FileCount++ 
            if (!$Summarize)
            {
                $Name = if ($FullName) {$Item.FullName} else {$Item.Name}
                $Usage = [PSCustomObject]@{
                    Size = $Item.Length
                    Files = 1
                    Name = $Name
                }
                Write-Output $Usage           
            }
        }
        $TotalBytesUsed += $BytesUsed
        $TotalFileCount += $FileCount
        $ItemS = Get-ChildItem -Path $Path -Directory -ErrorAction $ErrorActionPreference

    }
    else 
    {
        if ($All)
        {
            $ItemS = Get-ChildItem -Path $Path -ErrorAction $ErrorActionPreference
        }
        else 
        {
            $ItemS = Get-ChildItem -Path $Path -Directory -ErrorAction $ErrorActionPreference
        }        
    }

    foreach ($Item in $ItemS) 
    {
        Write-Verbose $Item.FullName
        [double] $BytesUsed = 0
        [int] $FileCount = 0
        if ($Item.PSIsContainer)
        {
            $FileS = Get-ChildItem -Path $Item.FullName -File -Include $Include -Exclude $Exclude -Recurse -Depth $Depth -ErrorAction $ErrorActionPreference
            foreach ($File in $FileS) 
            {
                $BytesUsed += $File.Length
                $FileCount++
            }                
        }
        else 
        {
            $BytesUsed += $Item.Length
            $FileCount++
        }
        
        if (!$Summarize)
        {
            $Name = if ($FullName) {$Item.FullName} else {$Item.Name}
            $Usage = [PSCustomObject]@{
                Size = $BytesUsed
                Files = $FileCount
                Name = $Name
            }
            Write-Output $Usage           
        }

        $TotalBytesUsed += $BytesUsed
        $TotalFileCount += $FileCount
    }

    $Name = if ($FullName) {Resolve-Path -Path $Path} else {"$(Split-Path -Path $Path -Leaf)"}
    $Usage = [PSCustomObject]@{
        Size = $TotalBytesUsed
        Files = $TotalFileCount
        Name = $Name
    }    
    Write-Output $Usage
    
    if (!$Summarize -and $Total)
    {
        $Usage = $Usage.PSObject.Copy()
        $Usage.Name = "Total"
        Write-Output $Usage
    }
}



<#
.SYNOPSIS
Measures the amount of disk space used, and the number of file contained, by the items in the specified path,
Similar to Measure-DiskUsage. But the used byte size can be format in Bytes, KB, MB or GB 

.DESCRIPTION
Long description

.PARAMETER Path
Parameter description

.PARAMETER Include
Parameter description

.PARAMETER Exclude
Parameter description

.PARAMETER FullName
Parameter description

.PARAMETER Total
Parameter description

.PARAMETER Summarize
Parameter description

.PARAMETER All
Parameter description

.PARAMETER Depth
Parameter description

.PARAMETER Kilobyte
Parameter description

.PARAMETER Megabytes
Parameter description

.PARAMETER Gigabytes
Parameter description

.PARAMETER Descending
Parameter description

.EXAMPLE
Show disk usage for all files in and under the users document folder
Sort by the folders with the largest number of files
Show-DiskUsage $Home\Documents -All

.EXAMPLE
Show disk usage for the ProgramFiles(x86) folder in Megabytes.
Ignore directories with privileged access errors
Show-DiskUsage ${ENV:ProgramFiles(x86)} -ErrorAction Ignore -Megabytes
#>
function Show-DiskUsage
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [object] $Path = ".",

        [Parameter()]
        [array] $Include = $null,

        [Parameter()]
        [array] $Exclude = $null,

        [Parameter()]
        [switch] $FullName,

        [Parameter()]
        [Alias("c")]
        [switch] $Total,

        [Parameter()]
        [Alias("s")]
        [switch] $Summarize,

        [Parameter()]
        [Alias("a")]
        [switch] $All,

        [Parameter()]
        [Alias("d")]
        [int] $Depth = 1000,

        [Parameter()]
        [Alias("kb")]
        [switch] $Kilobyte,

        [Parameter()]
        [Alias("mb")]
        [switch] $Megabytes,

        [Parameter()]
        [Alias("gb")]
        [switch] $Gigabytes,

        [Parameter()]
        [ValidateSet($null, "Size", "Files", "Name")]
        [string] $SortBy = $null,

        [Parameter()]
        [switch] $Descending
    )
   
    if ($Gigabytes) 
    { 
        #        123456789-12345 
        $UHdr = "       Size(GB)"
        $UFmt = "{0,15:N3}"
        $Ufac = 1GB
    }
    elseif ($Megabytes) 
    { 
        #        123456789-12345 
        $UHdr = "       Size(MB)"
        $UFmt = "{0,15:N3}"
        $Ufac = 1MB
    }
    elseif ($Kilobyte) 
    { 
        #        123456789-12345 
        $UHdr = "       Size(KB)"
        $UFmt = "{0,15:N3}"
        $Ufac = 1KB
    }
    else 
    {
        #        123456789-12345 
        $UHdr = "    Size(Bytes)"
        $UFmt = "{0,15:N0}"
        $Ufac = 1
    }
    $TblColS = @(@{Name=$UHdr; Expression={$Ufmt -f ($_.Size / $Ufac)} }, "Files", "Name")

    $ParamS = @{
        Path      = $Path
        Include   = $Include 
        Exclude   = $Exclude 
        FullName  =  $FullName
        Total     = $Total 
        Summarize = $Summarize 
        Depth     = $Depth 
        All       = $All
    }
    if ($SortBy)
    {
        $Usage = Measure-DiskUsage @ParamS
        $Usage | Sort-Object -Descending:$Descending -Property $SortBy | Format-Table -Property $TblColS
    }
    else 
    {
        Measure-DiskUsage @ParamS | Format-Table -Property $TblColS
    }
}
