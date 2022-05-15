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

    # Validate/prepare the the folder
    $Path = [System.IO.Path]::GetFullPath($Path)
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

# Define the alias: Touch
if (!(Test-Path -Path Alias:Touch)) 
{
    New-Alias -Name 'Touch' -Value 'Update-FileTime'
}
