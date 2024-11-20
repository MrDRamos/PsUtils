<#
Outputs a list of all DotNet Assemblies that the Input-Assembly (=Path parameter) depends on.
If Path parameter points to a directory instead of a file, then all files that match the 
-Include & -Exclude pattern contained in that directory are included. 
The default -Include pattern = @('*.exe', '*.dll') 
#>
[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline)]
    [string[]] $Path = $null,

    [Parameter()]
    [string[]] $Include = @('*.exe', '*.dll'),

    [Parameter()]
    [string[]] $Exclude = $null,

    [Parameter()]
    [switch] $Recurse,

    [Parameter()]
    [string[]] $ExcludeAssembly = @(),

    [Parameter()]
    [switch] $ExcludeSystemAssembly,

    [Parameter()]
    [string] $IlDasmPath = $null
)


<#
Outputs a list of all DotNet Assemblies that the Input-Assembly (=Path parameter) depends on.
If Path parameter points to a directory instead of a file, then all files that match the 
-Include & -Exclude pattern contained in that directory are included. 
The default -Include pattern = @('*.exe', '*.dll') 
#>
function Get-DependentAssembly
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string[]] $Path = $null,

        [Parameter()]
        [string[]] $Include = @('*.exe', '*.dll'),

        [Parameter()]
        [string[]] $Exclude = $null,

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [string[]] $ExcludeAssembly = @(),

        [Parameter()]
        [switch] $ExcludeSystemAssembly,

        [Parameter()]
        [string] $IlDasmPath = $null
   )

   Begin 
   {
        if ($ExcludeSystemAssembly)
        {
            $ExcludeAssembly += @('system', 'mscorlib')
        }
        $ExcludeAssembly = $ExcludeAssembly | Sort-Object -Unique
    
        if ([string]::IsNullOrWhiteSpace($IlDasmPath))
        {
            $IlDasmPath = Get-IlDasmPath
        }
    }

    Process 
    {
        if ([string]::IsNullOrWhiteSpace($Path))
        {
            return
        }
        if (Test-Path -Path $Path -PathType Container)
        {
             if ($Recurse)
             {
                 $PathFileS = Get-ChildItem -File -Path $Path -Include $Include -Exclude $Exclude -Recurse:$Recurse -ErrorAction Ignore
             }
             else 
             {
                 $PathFileS = Get-ChildItem -File -Path "$Path\*" -Include $Include -Exclude $Exclude -ErrorAction Ignore
             }        
        }
        else 
        {
             $PathFileS = Get-ChildItem -File -Path $Path -Include $Include -Exclude $Exclude -ErrorAction Ignore
        }
        if (!$PathFileS)
        {
             return
        }
     
        foreach ($File in $PathFileS.FullName) 
        {
            $LineS = & $IlDasmPath /TEXT /NOCA /ITEM=.assembly $File 2>$null
            $LineNo = 0
            while ($LineNo -lt $LineS.Count) 
            {
                $Line = $LineS[$LineNo++]
                if ($Line -match '^\.assembly extern (.*)')
                {           
                    $AssemblyName = $Matches[1]           
                    $Line = $LineS[$LineNo++]
                    while ($Line -ne '}')
                    {
                        if ($Line -match '\s*\.publickeytoken = \(([^\)]*)')
                        {
                            $PublicKeyToken = $Matches[1] -replace '\s+', ''
                        }
                        elseif ($Line -match '\s*\.ver (.*)')
                        {
                            $Version = $Matches[1] -replace ':', '.'
                        }
                        $Line = $LineS[$LineNo++]
                    }
                    
                    if (!($ExcludeAssembly | Where-Object {$AssemblyName -match $_}))
                    {
                        $Assembly = [PSCustomObject]@{
     #                       FileName      = (Split-Path -Path $File -Leaf)
                            AssemblyName  = $AssemblyName
                            Version       = $Version
                            PublicKeyToken= $PublicKeyToken
                            FilePath      = $File
                        }
                        Write-Output $Assembly    
                    }
                }
            }
        }   
    }     
}


function Get-IlDasmPath
{
    $IlDasmPath = $null
    $BinDir = Get-ChildItem -Path "${ENV:ProgramFiles(x86)}\Microsoft SDKs\Windows\v10.0A\bin" -Directory -ErrorAction Ignore |
                Sort-Object -Property name -Descend | Select-Object -First 1
    if ($BinDir)
    {
        $IlDasmPathS = Get-ChildItem -Path $BinDir.FullName -Recurse -Include 'ildasm.exe' -File -ErrorAction Ignore
        if ($IlDasmPathS)
        {
            $IlDasmPath = $IlDasmPathS | Sort-Object length -Descending | Select-Object -First 1
        }
    }

    if (!$IlDasmPath)
    {
        Throw "Can't find ildasm.exe"
    }
    return $IlDasmPath.FullName
}


Get-DependentAssembly @PSBoundParameters


<#### Unit Tests ####

'1) Test single file'
Get-DependentAssembly 'C:\Program Files\WindowsPowerShell\Modules\PackageManagement\1.0.0.1\Microsoft.PackageManagement.MsiProvider.dll' -ExcludeSystemAssembly

"`n2) Test pipe input of 2 folders"
@(  'C:\Program Files\WindowsPowerShell\Modules\PackageManagement'
    'C:\Program Files\WindowsPowerShell\Modules\PSReadLine'
) | Get-DependentAssembly -Recurse -Exclude 'allegro.UI*' #-ExcludeSystemAssembly
#>
