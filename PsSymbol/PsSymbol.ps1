

function Find-Symbol
{
    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Pattern,

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path = ".",

        [Parameter()]
        [string[]]$Include = $null,

        [Parameter()]
        [string[]]$Exclude = $null,

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [switch]$CaseSensitive,

        # Return whole-words contianing $Pattern
        [Parameter()]
        [switch]$WordsContaining,

        [Parameter()]
        [object]$Context = $null
    )

    begin
    {
        [array]$FileS = @()
    }
    
    process
    {
        # Note: the exclusions are applied after the inclusions, which can affect the final output
        if ($Include)
        {
            $FileS = Get-ChildItem -File -Path "$Path\*" -Include $Include -Recurse:$Recurse -Exclude $Exclude
        }
        else 
        {
            $FileS = Get-ChildItem -File -Path $Path -Recurse:$Recurse -Exclude $Exclude
        }
    }
    
    end
    {
        $Result = [System.Collections.ArrayList]::new()
        foreach ($File in $FileS) 
        {
            $FileSymbolS = [System.Collections.ArrayList]::new()
            $FileContent = Get-Content $File
            foreach ($PatternI in $Pattern) 
            {
                if ($WordsContaining)
                {
                    $PatternI = "(\w+-$PatternI\w+)"
                }

                [array]$FoundItemS = $FileContent | Select-String -Pattern $PatternI -CaseSensitive:$CaseSensitive
                if ($FoundItemS)
                {
                    [array]$SymbolS = foreach ($Found in $FoundItemS) 
                    {
                        $CaptureGroupS = $Found.Matches.Groups
                        if ($CaptureGroupS.Count -gt 1)
                        {
                            $CaptureGroupS[1].Value
                        }
                        else 
                        {
                            $CaptureGroupS.Value
                        }
                    } 
                    foreach ($Symbol in $SymbolS) 
                    {
                        $Entry = $FileSymbolS | Where-Object { $_.Symbol -eq $Symbol }
                        if ($Entry)
                        {
                            $Entry.Count++
                        }
                        else 
                        {
                            [void]$FileSymbolS.Add([PSCustomObject]@{
                                Symbol    = $Symbol
                                Count     = 1
                                File      = (Resolve-Path -Path $File -Relative)
                                Directory = (Resolve-Path -Path $File.Directory -Relative)
                                Context   = $Context
                            })
                        }
                    }
                }
            }
            if ($FileSymbolS)
            {
                [array]$SortedSymbolS = ($FileSymbolS | Sort-Object Symbol, File)
                $Result.AddRange($SortedSymbolS)
            }
        }
        Write-Output -NoEnumerate $Result  # Avoid converting ArrayList to Powershell Object[]
    }
}



function Find-SymbolPsFunction
{
    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Pattern = "^\s*function\s+(?:private:)?(?:global:)?(?<func>\w+-?\w+)",

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path = ".",

        [Parameter()]
        [string[]]$Include = "*.ps1",

        [Parameter()]
        [string[]]$Exclude = $null,

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [switch]$CaseSensitive,

        [Parameter()]
        [object]$Context = $null
    )
    Find-Symbol -Pattern $Pattern -Path $Path -Include $Include -Exclude $Exclude -Recurse:$Recurse -CaseSensitive:$CaseSensitive -Context $Context
}



function Join-Symbol
{
    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [array]$Symbol, 
        
        [Parameter()]
        [int]$MinCount = 1
    )

    $Retval = [System.Collections.ArrayList]::new()
    $PropS = $Symbol | Group-Object -Property "Symbol"
    foreach ($Prop in $PropS) 
    {
        if ($Prop.Count -gt $MinCount)
        {
            $Total = ($Prop.Group | ForEach-Object { $_.Count } | Measure-Object).Count # Sum over all groups
            [void]$Retval.Add([PSCustomObject]@{
                    Symbol    = $Prop.Name
                    Count     = $Total
                    File      = $Prop.Group.File | Sort-Object -Unique
                    Directory = $Prop.Group.Directory | Sort-Object -Unique
                    Context   = $Prop.Group.Context | Sort-Object -Unique
                })
        }
    }
    Write-Output -NoEnumerate $Retval
}



function Test-Symbol
{
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [string[]]$Pattern, 

        [Parameter(ValueFromPipeline)]
        [string[]] $Path = ".",

        [Parameter()]
        [string[]]$Include = "*",

        [Parameter()]
        [string[]]$Exclude = $null,

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [switch]$CaseSensitive
    )

    begin
    {
        [array]$FileS = @()
    }
    
    process
    {
        # Note: the exclusions are applied after the inclusions, which can affect the final output
        if ($Include)
        {
            $FileS = Get-ChildItem -File -Path "$Path\*" -Include $Include -Recurse:$Recurse -Exclude $Exclude
        }
        else 
        {
            $FileS = Get-ChildItem -File -Path $Path -Recurse:$Recurse -Exclude $Exclude
        }
    }
    
    end
    {
        foreach ($Symbol in $Pattern) 
        {
            foreach ($File in $FileS) 
            {
                if ($File | Select-String -Pattern $Symbol -List -CaseSensitive:$CaseSensitive)
                {
                    return $true
                }
            }
        }
        return $False
    }
}



function Get-SymbolPsCallGraph
{
    [OutputType([array])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [Object[]] $DirS = $null,

        [Parameter()]
        [string[]] $Exclude = $null,

        [Parameter()]
        [switch]$CaseSensitive
    )

    [array] $Result = $null
    if (!$DirS)
    {
        $DirS = Get-ChildItem -Directory
    }

    foreach ($SrcDir in $DirS) 
    {
        $FuncNameS = Find-SymbolPsFunction -Path $SrcDir -Exclude $Exclude -Recurse -CaseSensitive:$CaseSensitive
        if ($FuncNameS)
        {
            $RelSrcDir = Resolve-Path -Path $SrcDir -Relative
            Write-Verbose "-----------------------------------------------------------------------------------------"
            Write-Verbose "Functions exported by: $RelSrcDir"
            $FuncNameS | Format-Table | Out-String | Write-Verbose
            $SearchDirS = $DirS | Where-Object { $SrcDir -ne $_ }
            foreach ($SearchDir in $SearchDirS)
            {
                $DirSymbolS = Find-Symbol -Path $SearchDir -Include "*.ps1" -Pattern $FuncNameS.Symbol -CaseSensitive:$CaseSensitive -Context $RelSrcDir
                if ($DirSymbolS)
                {
                    Write-Verbose "Functions imported by: $(Resolve-Path -Path $SearchDir -Relative) --> Calling Context: $RelSrcDir"
                    $DirSymbolS | Format-Table | Out-String | Write-Verbose
                    $Result += $DirSymbolS
                }
            }
        }
    }
    return $Result
}



$ExcludeFileS = @(
    "VmScript-RunCustomWrapper.ps1"
    "VmScript-RunServiceStartStop.ps1"
    "VmScript-RunServiceRestart.ps1"
    "VmScript-RunGetServiceStatus.ps1"
    "VmScript-Run_PkgSetup.ps1"
    "VmScript-Run_OlfSetup.ps1"
    "VmScript-RunCustomWrapper.ps1"
    "VmScript_Util.ps1"
)

Write-Host "Sourcing PsSymbol.ps1" -ForegroundColor Magenta
#Set-Location D:\Builds\OlcPortal\IEM-Automation

exit
#------

$SymbolS = Find-Symbol -Include "*.ps1" -Pattern "AzRm" -WordsContaining -Path .\tools
$SymbolS | Format-Table

<#
$CallGraph = Get-SymbolPsCallGraph -Verbose
$CallGraph | Format-Table -GroupBy Context
#>

#<#  Duplicaates
Write-Host "Duplicat function definitions - All Files" -ForegroundColor Yellow
$SymbolS = Find-SymbolPsFunction -Recurse
$DupSymbolS = Join-Symbol -Symbol $SymbolS -MinCount 2
foreach ($item in $DupSymbolS) 
{
    Write-Host "$($item.Symbol) - Source Files:" -ForegroundColor Cyan
    Write-Host "   $(($item.File | Resolve-Path -Relative) -join "`n   ")"
} 


Write-Host "Duplicat function definitions - Excluding VmScripts" -ForegroundColor Yellow
$SymbolS = Find-SymbolPsFunction -Recurse -Exclude $ExcludeFileS
$DupSymbolS = Join-Symbol -Symbol $SymbolS -MinCount 2
foreach ($item in $DupSymbolS) 
{
    Write-Host "$($item.Symbol) - Source Files:" -ForegroundColor Cyan
    Write-Host "   $(($item.File | Resolve-Path -Relative) -join "`n   ")"
} 
#>


<#
Find-SymbolPsFunction -Recurse
Find-Symbol2 "Write_Log" -Recurse
Find-Symbol "Write_Log" -Recurse -Include "*.ps1"
"*.ps1" | Find-Symbol "Write_Log" -Recurse
"IEM_Service\*" | Find-Symbol "Write_Log" -Recurse

$SymbolS = "Api_VmScript" | Find-SymbolPsFunction -Recurse
$SymbolS
exit
#>

<#
Get-SymbolDependencies -DirS (Get-ChildItem -Directory) -CaseSensitive | Tee-Object -FilePath dependencies.txt
Get-SymbolDependencies -DirS (Get-ChildItem -Directory) | Tee-Object -FilePath dependencies2.txt
Get-SymbolDependencies -DirS (Get-ChildItem -Directory) -Exclude $ExcludeFileS | Tee-Object -FilePath dependencies3.txt
#>


exit
