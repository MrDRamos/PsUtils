function Update-FileTime
{
    [CmdletBinding()]
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
    $Folder = Split-Path -Path $Path -Parent
    if (!(Resolve-Path -Path $Folder -ErrorAction Ignore))
    {
        if ($Force)
        {
            $null = New-Item -ItemType Directory -Path $Folder
        }
        else 
        {
            Write-Error "The folder does not exist: $Folder"
            exit 1
        }
    }

    # Update the file
    if (!(Test-Path $Path)) 
    {
        New-Item -ItemType File -Path $Path
    }
    else 
    {
        (Get-ChildItem $Path).LastWriteTime = $LastWriteTime
    }
}


# Define the alias: Touch
if (!(Test-Path -Path Alias:Touch)) 
{
    New-Alias -Name Touch Update-FileTime -Force
}
