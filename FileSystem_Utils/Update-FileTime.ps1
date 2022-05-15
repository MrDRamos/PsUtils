[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [object] $Path, 

    [Parameter()]
    [datetime] $LastWriteTime = (Get-Date),

    [Parameter()]
    [switch] $Force
)

function Update-FileTime
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Path, 

        [Parameter()]
        [datetime] $LastWriteTime = (Get-Date),

        [Parameter()]
        [switch] $Force
    )

    # Make sure $Path is fully qualified
    if (![System.IO.Path]::IsPathFullyQualified($Path))
    {
        $Path = [System.IO.Path]::GetFullPath($Path, $PWD)
    }

    # Validate/Prepare the the folder
    $Folder = Split-Path -Path $Path -Parent
    if (!(Resolve-Path -Path $Folder -ErrorAction Ignore))
    {
        if ($Force)
        {
            $null = New-Item -ItemType Directory -Path $Folder -Verbose:$VerbosePreference
        }
        else 
        {
            Write-Error "The folder does not exist: $Folder"
            return
        }
    }

    # Update the file
    if (!(Test-Path $Path)) 
    {
        $null = New-Item -ItemType File -Path $Path -Verbose:$VerbosePreference
    }
    else 
    {
        $Operation = "Update LastWriteTime to: $LastWriteTime"
        if ($PSCmdlet.ShouldProcess($Path, $Operation))
        {
            Write-Verbose "$Operation on file: `"$Path`"" -Verbose:$VerbosePreference
            (Get-ChildItem $Path).LastWriteTime = $LastWriteTime
        }
    }
}

Update-FileTime -Path $Path -LastWriteTime $LastWriteTime -Force:$Force


<# 
Define the alias: Touch
# In Profile.ps1
# Copy this file to: "$(Split-Path $PROFILE.CurrentUserAllHosts -Parent)\Scripts"
New-Alias -Name 'Touch' -Value 'Update-FileTime.ps1'

#When Dot Sources
if (!(Test-Path -Path Alias:Touch)) 
{
    New-Alias -Name 'Touch' -Value 'Update-FileTime'
}
#>
