<#
.SYNOPSIS
Wrapper on Get-ChildItem() to filter out files that are hard linked.

.PARAMETER Path
Specifies a path to one or more locations. Wildcards are accepted. 
The default location is the current directory (.).
Note: The Wildcard patterns, Filter, Include & Exclude parameters apply to the 
folders discovered while recursing child folders, just like Get-ChildItem().

.PARAMETER Include
The Include pattern is a secondary filter that is applied to the files that were 
selected by the wildcard pattern of the Path parameter.

.PARAMETER Exclude
The Exclude pattern is a secondary filter that is applied to the files that were 
selected by the wildcard pattern of the Path parameter.

.PARAMETER Filter
An additional wildcard pattern to qualify the files selected by the first wildcard 
pattern of the Path parameter, note the default wildcard Path pattern is '*'. 
Note: Using a native file system Filter pattern is more efficient than using Include 
and Exclude lists.

.PARAMETER Recurse
Gets the items in the specified locations and in all child items of the locations.

.PARAMETER Force
Include hidden files
#>
function Get-Hardlinks
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [Parameter()]
        [string[]] $Include = $null,

        [Parameter()]
        [string[]] $Exclude = $null,

        [Parameter()]
        [string] $Filter = $null,

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [switch] $Force
    )   

    process 
    {
        $FileS = Get-ChildItem -File -Path $Path -Filter $Filter -Include $Include -Exclude $Exclude -Recurse:$Recurse
        foreach ($File in $FileS) 
        {
            if ($File.LinkType -eq 'HardLink')
            {
                Write-Output $File
            }
        }
    }
}
