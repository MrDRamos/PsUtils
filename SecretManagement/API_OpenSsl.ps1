#region OpenSsl

<#
.SYNOPSIS
    A wrapper around Get-Command to locate Unix-like commands that can run on a Windows host.

.DESCRIPTION
    This function attempts to locate a Unix-style command (e.g., from WSL or Git Bash) on a Windows system.
    By default, it searches using the system's PATH environment variable, which gives priority to commands 
    available through WSL or other Unix-like environments installed on the system.

    If the command is not found in the PATH, the function attempts to locate it within the Git for Windows 
    distribution (typically installed with Git Bash).

.PARAMETER Name
    The name of the Unix-style command to locate. This can be a partial name (e.g., 'openssl'), 
    a fully qualified name (e.g., 'openssl.exe'), or a full path (e.g., 'C:\Program Files\Git\mingw64\bin\openssl').

.PARAMETER NixCmdInGitDistro
    If specified, restricts the search to the Git for Windows distribution only, ignoring the system PATH.
    This behavior can also be triggered by setting the environment variable `NixCmdInGitDistro` to `1` or `true`.
    This is useful in scenarios where you want to enforce Git-only command resolution globally or in scripts

.EXAMPLE
    Get-NixCommand -Name 'curl.exe'
    # Searches for 'curl' in the system PATH and Git for Windows if not found.

.EXAMPLE
    Get-NixCommand -Name 'bash' -NixCmdInGitDistro
    # Searches only within the Git for Windows distribution for 'bash'.
   
.EXAMPLE
    $env:NixCmdInGitDistro = '1'
    Get-NixCommand -Name 'ssh'
    # Searches only within Git for Windows due to the environment variable setting.

.NOTES
    Author: David Ramos
    Purpose: Enhance cross-platform compatibility by locating Unix-style commands on Windows.
#>
function Get-NixCommand
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Alias('Application', 'Command')]
        [string] $Name,

        [Parameter()]
        [switch] $NixCmdInGitDistro
    )

    $Cmd = $null
    if ($ENV:NixCmdInGitDistro -in @('1','true'))
    {
        $NixCmdInGitDistro = $true
    }
    if (!$NixCmdInGitDistro)
    {
        $Cmd = Get-Command -Name $Name -ErrorAction Ignore
    }
    if (!$Cmd)
    {
        $GitApp = Get-Command -Name 'git.exe' -ErrorAction Ignore
        if ($GitApp)
        {
            $GitRoot = Split-Path -Path $GitApp.Path -Parent | Split-Path -Parent
            # Some commands exist in more that one folder.
            $Cmd = Get-Command -Name "$GitRoot\bin\$Name" -ErrorAction Ignore
            if (!$Cmd)
            {
                $Cmd = Get-Command -Name "$GitRoot\mingw64\bin\$Name" -ErrorAction Ignore
                if (!$Cmd)
                {
                    $Cmd = Get-Command -Name "$GitRoot\usr\bin\$Name" -ErrorAction Ignore
                }
            }
        }    
    }
    return $Cmd
}
#Get-NixCommand -Name 'ssh'
#Get-NixCommand -Name 'bash' -NixCmdInGitDistro



<#
.SYNOPSIS
Executes openssl.exe command. 
Requires MinGW64 (Minimalist GNU for Windows) tools which are installed with git for windows
#>
function Invoke-OpenSsl
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$AppArgs,

        [Parameter()]
        [switch] $NixCmdInGitDistro
    )

    $App = Get-NixCommand 'openssl.exe' -NixCmdInGitDistro:$NixCmdInGitDistro
    if (!$App)
    {
        throw "openssl.exe is not installed on this system."
    }

    $Cmd = "& $($App.Path) $AppArgs"
    if ($VerbosePreference)
    {
        Write-Verbose $Cmd
    }
    $CmdOutput = & $App.Path $AppArgs 2>&1
    if ($LASTEXITCODE -ne 0)
    {
        Write-Host "Invoke-OpenSsl failed: $Cmd" -ForegroundColor 'Red'
        throw $CmdOutput
    }
    $CmdOutput | Write-Output 
}



<#
.SYNOPSIS
Converts X509 certificate from a PFX(binary) file to its equivalent PEM(ASCII text) format.
Returns nothing if an output PemFile was specified.
Returns a PEM output string if no PemFile was specified
See details in: https://docs.openssl.org/3.0/man1/openssl-pkcs12/

.PARAMETER PfxFile
The input PFX file to export

.PARAMETER PassIn
The passphrase needed to decrypt the private-key read in from the PFX file

.PARAMETER PemFile
The output PEM file. 
The default = $null in which case a string with the PEM file content is returned, and
the temporary PEM file is deleted before the function returns

.PARAMETER PassOut
The passphrase used encrypt the private-key written out to the PEM file

.PARAMETER NoEnc
Optional switch to disable encryption of the PEM output.
Its equivalent to adding '-legacy -noenc' to ExtraSslArgS

.PARAMETER NoKeys
Optional switch to exclude the private-key from the PEM output.
Its equivalent to adding '-nokeys' to ExtraSslArgS

.PARAMETER ExtraSslArgS
Optional arguments to pass to openssl.exe

.PARAMETER HELP
run openssl.exe pkcs12 -help

.EXAMPLE
Don't encrypt the private-key in the PEM output
ConvertFrom-PfxFileToPem -PfxFile $PfxFile -PassIn $PfxPassPhrase -PemFile $PemFile -NoEnc -Verbose

.EXAMPLE
Encrypt the private-key exported to the PEM output with a new different PassPhrase
ConvertFrom-PfxFileToPem -PfxFile $PfxFile -PassIn $PfxPassPhrase -PemFile $PemFile -PassOut $PemPassPhrase

.EXAMPLE
Don't include the private-key in the PEM output
ConvertFrom-PfxFileToPem -PfxFile $PfxFile -PassIn $PfxPassPhrase -PemFile $PemFile -NoKeys -Verbose

.EXAMPLE
Return the PEM outout as a string, only export the private-key
$KeyPem = ConvertFrom-PfxFileToPem -PfxFile $PfxFile -PassIn $PfxPassPhrase -NoEnc -ExtraSslArgS '-nocerts'

.EXAMPLE
Return the PEM outout as a string, don't include the private-key and don't include CA certificates
$CertPem = ConvertFrom-PfxFileToPem -PfxFile $PfxFile -PassIn $PfxPassPhrase -ExtraSslArgS '-nokeys', '-clcerts'
#>
function ConvertFrom-PfxFileToPem
{
    [CmdletBinding()]
    param (

        [Parameter(Mandatory, ParameterSetName = 'help')]
        [Alias('-h')]
        [switch] $Help,
        
        [Parameter(Mandatory, ParameterSetName = 'run')]
        [Alias('Path')]
        [string] $PfxFile,
        
        [Parameter()]
        [string] $PassIn = $null,

        [Parameter()]
        [string] $PemFile = $null,

        [Parameter()]
        [string] $PassOut = $null,

        [Parameter()]
        [switch] $NoEnc,

        [Parameter()]
        [switch] $NoKeys,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$ExtraSslArgS = $null,

        [Parameter()]
        [switch] $NixCmdInGitDistro
    )

    if ($Help)
    {
        Invoke-OpenSsl pkcs12 -help
        return
    }

    $TmpPem = $null
    if ([string]::IsNullOrWhiteSpace($PemFile))
    {
        $TmpPem = $PemFile = [System.IO.Path]::GetTempFileName()
    }
    
    if (![string]::IsNullOrEmpty($PassIn))
    {
        $ExtraSslArgS += '-passin', "pass:$PassIn"
    }

    if ($NoEnc)
    {
        $ExtraSslArgS += '-legacy'
        $ExtraSslArgS += '-noenc'
        #$ExtraSslArgS += '-nodes'
    }
    if ($NoKeys)
    {
        $ExtraSslArgS += '-nokeys'
    }

    if (![string]::IsNullOrEmpty($PassOut))
    {
        $ExtraSslArgS += '-passout', "pass:$PassOut"
    }
    else 
    {
        if ('-passin' -in $ExtraSslArgS -and '-noenc' -notin $ExtraSslArgS -and'-nodes' -notin $ExtraSslArgS -and '-nokeys' -notin $ExtraSslArgS)
        {
            throw "The PEM output password was not set"
        }
    }

    if ($ExtraSslArgS)
    {
        $CmdOutput = Invoke-OpenSsl -NixCmdInGitDistro:$NixCmdInGitDistro 'pkcs12' '-in' $PfxFile '-out' $PemFile @ExtraSslArgS
    }
    else
    {
        $CmdOutput = Invoke-OpenSsl -NixCmdInGitDistro:$NixCmdInGitDistro 'pkcs12' '-in' $PfxFile '-out' $PemFile 2>&1
    }

    if ($TmpPem)
    {
        $PemStr = Get-Content -Path $TmpPem
        Remove-Item -Path $TmpPem -Force
        return $PemStr
    }
}
#endregion OpenSsl
