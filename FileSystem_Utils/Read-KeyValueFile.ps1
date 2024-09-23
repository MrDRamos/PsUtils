
<#
.SYNOPSIS
Parses each line in the specified file for 'key = value' pairs.
Returns a [Hashtable] of the found entries

Features:
- Leading and trailing white spaces around a value are automatically removed
- Use singled or double quoted values if leading or trailing whitespace characters must be preserved.
- The quotes around a value are removed. Use two quotes if the a values must include quotes
- All text following a # character is removed except if the value is quoted

Multiline-Values:
- Multiline-Values use the PowersShell Here-String convention.
  The lines to include are delimited by the start-line: @" or  and end-line: "@ characters
  The end-line: "@ delimiter must be the first characters in the line
  Alternate Multiline delimiters are the start-line: @' or  and end-line: '@ characters
- Example of a value consisting of 2 lines:
Key = @"
  line 1
  line 2
@"
#>
function Read-KeyValueFile
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter()]
        [string] $Path = $null
    )

    [hashtable]$IemVarS = @{}
    if ($Path -and (Test-Path -Path $Path))
    {
        $AllLineS = Get-Content -Path $Path -Encoding utf8
        $AllLineS | Write-Host -ForegroundColor White

        $MultiLineDelim = ''
        $MultiLineKey = $null
        [array]$MultiLineValue = $null
        [int]$LineNo = 0
        foreach ($Line in $AllLineS) 
        {
            $LineNo++
            if (![string]::IsNullOrWhiteSpace($Line))
            {
                if ($MultiLineKey)
                {
                    if ($Line.StartsWith($MultiLineDelim))
                    {
                        $IemVarS[$MultiLineKey] = $MultiLineValue -join "`n"
                        $MultiLineKey = $null
                        $MultiLineValue = $null
                    }
                    else 
                    {
                        $MultiLineValue += $Line
                    }                
                }
                else 
                {
                    $Line = $Line.Trim()
                    [int]$idx = $Line.IndexOf('=')
                    if ($idx -ge 1)
                    {
                        $Key = $Line.Substring(0, $idx).TrimEnd()
                        $Value = $Line.Substring($idx + 1).TrimStart()
                        if ($Value.StartsWith('@"'))
                        {
                            $MultiLineKey = $key
                            $MultiLineDelim = '"@'
                        }
                        elseif ($Value.StartsWith("@'"))
                        {
                            $MultiLineKey = $key
                            $MultiLineDelim = "'@"
                        }
                        else 
                        {
                            if ($Value)
                            {
                                $idx = $Value.IndexOf('#')
                                if ($idx -ge 0)
                                {
                                    if (!$Value.EndsWith('"') -and !$Value.EndsWith("'"))
                                    {
                                        $Value = $Value.Substring(0, $idx).TrimEnd()
                                    }
                                }

                                if ($Value.Length -gt 1)
                                {
                                    if ($Value[0] -eq '"' -and $Value[$Value.Length - 1] -eq '"')
                                    {
                                        $Value = $Value.Substring(1, $Value.Length - 2)
                                    }
                                    elseif ($Value[0] -eq "'" -and $Value[$Value.Length - 1] -eq "'")
                                    {
                                        $Value = $Value.Substring(1, $Value.Length - 2)
                                    }
                                }

                            }
                            $IemVarS[$Key] = $Value
                        }
                    }
                    else 
                    {
                        if (!$Line.StartsWith('#'))
                        {
                            Write-Warning "Invalid Key = Value format in line: $LineNo"
                        }
                    }
                }
            }
        }
    }
    return $IemVarS
}


<# Unit Test
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$SampleText = @"
0=0
Str00 = abc00  
  Str01  =  abc01
Str02=abc02
Str03=
Str04
=
#line 8
    #line 9

Str20 ="abc20  "
Str21 = ""abc21""
Str22 = ''abc22''
Str23 = 'abc23''
Str24 = ''abc24'
Str25 = 'abc'25'
Str26 = "abc"26"
Str27 = ""
Str28 = "

Str30 = abc30   # comment
Str31 = 'abc31' # comment
Str32 = "abc32" # comment
Str33 = "abc33" # comment"
Str34 = abc34" # comment"
Str35 = abc35 # comment #more comment

Str40 = @'       
Hello
  '@ 40
    World  
'@
Str41 = @"       
Hello
  "@ 41
    World  
`"@
Str50 = 50
"@
$SampleFile = '.\Test-KeyValues.txt'
$SampleText | Set-Content -Path $SampleFile -Encoding UTF8 -Force

$IemVarS = Read-KeyValueFile -Path $SampleFile
$IemVarS.Keys | Sort-Object | ForEach-Object { @{$_ = ">$($IemVarS[$_])<"} } | Format-Table -AutoSize -Wrap
#>