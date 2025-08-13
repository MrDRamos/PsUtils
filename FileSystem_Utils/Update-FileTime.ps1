<#
.SYNOPSIS
Creates an empty file or updates the LastWriteTime and LastAccessTime of one or more files to the current system time, a specified time, or UTC time.

.DESCRIPTION
This function is equivalent to the Linux 'touch' command. It updates the LastWriteTime and LastAccessTime of specified files. If a file does not exist, it is created unless the -CreateDisabled switch is used. You can set timestamps to the current local time, a specific local time, a UTC time, or match another file. Optionally, parent directories can be created automatically.

.PARAMETER Path
Specifies the file or files to update. This argument can be passed from the pipeline.

.PARAMETER ReferenceFile
Optional. Sets the timestamps based on another file. Both LastWriteTime and LastAccessTime are set to match the ReferenceFile.

.PARAMETER TimeStamp
Optional. Sets a specific timestamp in local time. Defaults to the current system time.

.PARAMETER TimeStampUTC
Optional. Specifies the timestamp in UTC. If provided, it overrides TimeStamp and is converted to local time for file operations.

.PARAMETER Accessed
By default, both LastWriteTime and LastAccessTime are updated. Specify this switch to update only LastAccessTime.

.PARAMETER Modified
By default, both LastWriteTime and LastAccessTime are updated. Specify this switch to update only LastWriteTime.

.PARAMETER CreateDisabled
Prevents file creation if the file does not exist. Only updates timestamps for existing files.

.PARAMETER CreateFolders
If the parent folder does not exist, this switch creates it automatically.

.PARAMETER PassThru
If specified, outputs the file object(s) that were created or updated. This allows further processing in the PowerShell pipeline.

.NOTES
To create a "Touch" alias in every PowerShell session:
1) Copy this file to: ~\Documents\WindowsPowerShell\Scripts
2) Add this line to your profile.ps1: New-Alias -Name 'Touch' -Value 'Update-FileTime.ps1'

.EXAMPLE
Update-FileTime -Path "example.txt"
Creates 'example.txt' if it does not exist, or updates its timestamps to the current time.

.EXAMPLE
Update-FileTime -Path "example.txt" -TimeStamp "2025-08-13 12:00"
Sets the timestamps of 'example.txt' to the specified local date and time.

.EXAMPLE
Update-FileTime -Path "example.txt" -TimeStampUTC "2025-08-13T12:00:00Z"
Sets the timestamps of 'example.txt' to the specified UTC date and time.

.EXAMPLE
Update-FileTime -Path "example.txt" -ReferenceFile "ref.txt"
Sets the timestamps of 'example.txt' to match those of 'ref.txt'.

.EXAMPLE
Update-FileTime -Path "C:\NewFolder\file.txt" -CreateFolders
Creates the parent folder if it does not exist, then creates or updates 'file.txt'.
#>
[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'LocalTime')]
param (
    [Parameter(ValueFromPipeline, Position = 0)]
    [Alias('File', 'Files')]
    [array] $Path = $null, 

    [Parameter()]
    [Alias('R')]
    [string] $ReferenceFile = $null,

    [Parameter(ParameterSetName='LocalTime')]
    [Alias('Time', 'D')]
    [datetime] $TimeStamp = (Get-Date),

    [Parameter(ParameterSetName='UTCTime')]
    [datetime] $TimeStampUTC,

    [Parameter()]
    [Alias('A', 'LastAccessTime')]
    [switch] $Accessed,

    [Parameter()]
    [Alias('M', 'LastWriteTime')]
    [switch] $Modified,

    [Parameter()]
    [Alias('C', 'NC', 'NoCreate')]
    [switch] $CreateDisabled,

    [Parameter()]
    [switch] $CreateFolders,

    [Parameter()]
    [switch] $PassThru
)

function Update-FileTime
{
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'LocalTime')]
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        [Alias('File', 'Files')]
        [array] $Path = $null, 

        [Parameter()]
        [Alias('R')]
        [string] $ReferenceFile = $null,

        [Parameter(ParameterSetName='LocalTime')]
        [Alias('Time', 'D')]
        [datetime] $TimeStamp = (Get-Date),

        [Parameter(ParameterSetName='UTCTime')]
        [datetime] $TimeStampUTC,

        [Parameter()]
        [Alias('A', 'LastAccessTime')]
        [switch] $Accessed,

        [Parameter()]
        [Alias('M', 'LastWriteTime')]
        [switch] $Modified,

        [Parameter()]
        [Alias('C', 'NC', 'NoCreate')]
        [switch] $CreateDisabled,

        [Parameter()]
        [switch] $CreateFolders,

        [Parameter()]
        [switch] $PassThru
    )

    #region Initialize arguments
    # $Input is an automatic variable referencing pipeline input
    if ($Input)
    {
        $FileS = [array]$Input
    }
    else
    {
        $FileS = $Path
    }

    # If neither Accessed nor Modified is specified, update both by default
    if (!$PSBoundParameters.ContainsKey('Accessed') -and !$PSBoundParameters.ContainsKey('Modified'))
    {
        $Accessed = $Modified = $true
    }

    # Use UTC timestamp if specified
    if ($PSBoundParameters.ContainsKey('TimeStampUTC')) {
        $TimeStamp = $TimeStampUTC.ToLocalTime()
    }

    [datetime]$LastAccessTime = [datetime]$LastWriteTime = 0
    if ($ReferenceFile)
    {
        $PsFile = Resolve-Path -Path $ReferenceFile -ErrorAction Stop | Get-Item
        if ($Accessed)
        {
            $LastAccessTime = $PsFile.LastAccessTime
        }
        if ($Modified)
        {
            $LastWriteTime = $PsFile.LastWriteTime
        }
    }
    else 
    {
        if ($Accessed)
        {
            $LastAccessTime = $TimeStamp
        }
        if ($Modified)
        {
            $LastWriteTime = $TimeStamp
        }
    }
    if ($LastAccessTime -eq 0 -and $LastWriteTime -eq 0)
    {
        return # Nothing to do
    }
    #endregion Initialize arguments

    foreach ($File in $FileS) 
    {
        try 
        {
            # Skip directories
            if (Test-Path $File -PathType Container)
            {
                Write-Verbose "Skipping directory: $File"
                continue
            }

            # Validate or prepare the parent folder
            $Folder = Split-Path -Path $File -Parent
            if ($Folder -and !(Test-Path -Path $Folder))
            {
                if ($CreateFolders)
                {
                    Write-Verbose "Creating new directory: `"$Folder`""
                    $null = New-Item -ItemType Directory -Path $Folder
                }
                else 
                {
                    Write-Host "Skipped file. Use the -CreateFolders switch to create new parent folders: $File" -ForegroundColor 'Red'
                    continue
                }
            }

            # Update the file
            if (!(Test-Path $File)) 
            {
                Write-Verbose "Creating new file: `"$File`""
                $PsFile = New-Item -ItemType File -Path $File
                if ($PsFile)
                {
                    if ($LastAccessTime -ne 0)
                    {
                        $PsFile.LastAccessTime = $LastAccessTime
                    }
                    if ($LastWriteTime -ne 0)
                    {
                        $PsFile.LastWriteTime = $LastWriteTime
                    }
                    if ($PassThru)
                    {
                        Write-Output $PsFile
                    }
                }
            }
            else 
            {
                $Operation = "Update LastWriteTime to: $TimeStamp"
                if ($PSCmdlet.ShouldProcess($File, $Operation))
                {
                    Write-Verbose "$Operation on file: `"$File`""
                    $PsFile = Get-Item -Path $File
                    if ($PsFile)
                    {
                        if ($LastAccessTime -ne 0)
                        {
                            $PsFile.LastAccessTime = $LastAccessTime
                        }
                        if ($LastWriteTime -ne 0)
                        {
                            $PsFile.LastWriteTime = $LastWriteTime
                        }
                        if ($PassThru)
                        {
                            Write-Output $PsFile
                        }
                    }
                }
            }            
        }
        catch 
        {
            Write-Host "Error processing file: $File" -ForegroundColor 'Red'
            Write-Host $_.Exception.Message -ForegroundColor 'Red'
            continue
        }
    }
}


<# Uncomment this line to run a simple unit test
@('test1.txt', 'test1.txt') | Update-FileTime -PassThru
exit
#>

########### Wrapper Entry-Point to Function ###########
if ($Path)
{
    if ($Input)
    {
        $PSBoundParameters['Path'] = [array]$Input
    }
    Update-FileTime @PSBoundParameters
}
elseif ($MyInvocation.InvocationName -eq '.')
{
    # Script was dot-sourced; define 'Touch' alias
    if (!(Test-Path -Path Alias:Touch)) 
    {
        New-Alias -Name 'Touch' -Value 'Update-FileTime'
    }
}
