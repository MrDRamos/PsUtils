<#
.SYNOPSIS
Wrapper around the DOS TREE command that allows clipping the displayed tree to a given depth level.
Also accepts PowerShell pipeline input of the Path parameter.

.PARAMETER Path
The root path of the TREE. The default is the current working directory

.PARAMETER Depth
By default TREE shows the entire sub-folder structure by recusing through all levels.
Specify a Depth value to restrict the sub-folder level to display.

.PARAMETER Files
By default TREE only shows folders. Specify this switch to also show files

.PARAMETER ASCII
By default TREE uses graphic characters in the DOS Code-Page to draw nice tree connections.
Specify this switch to substitute the tree connections with 7-Bit ASCII characters.
#>
[CmdletBinding()]
param (
    [Parameter(Position = '1', ValueFromPipeline = $True)]
    [object] $Path = $PWD,

    [Parameter()]
    [Alias('D')]
    [int] $Depth = 0,

    [Parameter()]
    [Alias('F')]
    [switch] $Files,

    [Parameter()]
    [Alias('A')]
    [switch] $Ascii
)

    
$ParamS = @($Path)
if ($Files)
{
    $ParamS += '/F'
}
if ($Ascii)
{
    $ParamS += '/A'
    $DepthPattern = '[\|\+\- \\]{4,4}'
}
else 
{
    $DepthPattern = "[`u{2502}`u{2500}`u{251c}`u{2514} ]{4,4}" ##//4 Box Drawing Chars "[│─├└ ]{4,4}"
}

if ($Depth -lt 1)
{
    & tree @ParamS
}
else 
{
    $DepthFilter = '^'
    for ($i = 0; $i -le $Depth; $i++) 
    {
        $DepthFilter += $DepthPattern
    }
    & tree @ParamS | Select-String -Pattern $DepthFilter -NotMatch
}
