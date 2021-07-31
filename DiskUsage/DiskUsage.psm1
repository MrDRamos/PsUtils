
<#
    Measures the amound of disk space used, and the number of file contianed, by the items in the specified path,
    The arguments and aliases were patterned after the unix du (disk-usage) utility
#>
function Measure-FolderUsage
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
        [int] $Depth = 1000
    )

    $ErrorAction = $PSBoundParameters["ErrorAction"]
    if(-not $errorAction)
    {
        $ErrorAction = $ErrorActionPreference
    }
    [double] $TotalBytesUsed = 0
    [int] $TotalFileCount = 0
    $Depth = [math]::Max($Depth-1, 0)

    if ($All -and $Include -or $Exclude)
    {
        [double] $BytesUsed = 0
        [int] $FileCount = 0
        $FileS = Get-ChildItem -Path "$Path\*" -File -Include $Include -Exclude $Exclude -ErrorAction $ErrorAction
        foreach ($Item in $FileS) 
        {
            $BytesUsed += $Item.Length
            $FileCount++ 
            if (!$Summarize)
            {
                $Name = (if ($FullName) {$Item.FullName} else {$Item.Name})
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
        $ItemS = Get-ChildItem -Path $Path -Directory

    }
    else 
    {
        if ($All)
        {
            $ItemS = Get-ChildItem -Path $Path -ErrorAction $ErrorAction
        }
        else 
        {
            $ItemS = Get-ChildItem -Path $Path -Directory -ErrorAction $ErrorAction
        }        
    }

    foreach ($Item in $ItemS) 
    {
        Write-Verbose $Item.FullName
        [double] $BytesUsed = 0
        [int] $FileCount = 0
        if ($Item.PSIsContainer)
        {
            $FileS = Get-ChildItem -Path $Item.FullName -File -Include $Include -Exclude $Exclude -Recurse -Depth $Depth -ErrorAction $ErrorAction
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
    
    if ($Total -or $Summarize)
    {
        #$Name = if ($FullName) {Resolve-Path -Path $Path} else {"$(Split-Path -Path $Path -Leaf)"}
        $Name = "Total"
        $Usage = [PSCustomObject]@{
            Size = $TotalBytesUsed
            Files = $TotalFileCount
            Name = $Name
        }    
        Write-Output $Usage
    }
}



<#
    Measures the amound of disk space used, and the number of file contianed, by the items in the specified path,
    Simular to Measure-FolderUsage. But the uses byte size can be format in KB, MG or GB 
#>
function Show-FolderUsage
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
        [Alias("-c")]
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
        [ValidateSet("Bytes", "KB", "MB", "GB")]
        [string] $Unit = "Bytes",

        [Parameter()]
        [switch] $Descending
    )

    $Norm = @{Bytes=1; KB=1KB; MB=1MB; GB=1GB}[$Unit]
    $Usage = Measure-FolderUsage -Path $Path -Include $Include -Exclude $Exclude -FullName:$FullName -Total:$Total -Summarize:$Summarize -Depth $Depth -All:$All
    $Usage | Sort-Object -Descending:$Descending -Property Size | Format-Table -Property @{Name="Size($Unit)"; Expression={"{0:N3}" -f ($_.Size / $Norm)} }, Files, Name
}

