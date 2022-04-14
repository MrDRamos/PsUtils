<#
.SYNOPSIS
This function can clone a source directory structure similar to Copy-Item() but instead of copying the 
files it will make hard links to the source files. The destination folder will not consume additional
hard disk space for the files, only for the new directory entries. Using hard linked files has the 
advantage that deleting the original source file will not effect the hard linked copy. Contrast that 
to the action of deleting the original file pointed to by a symbolic directory or file link which will 
invalidate/break the symlink file in the destination directory.

.DESCRIPTION
A hard link is a directory entry for a file. Every file can be considered to have at least one hard link.
On NTFS volumes, each file can have multiple hard links, so a single file can appear in many directories 
(or even in the same directory with different names). Because all of the links reference the same file, 
programs can open any of the links and modify the file. A file is deleted from the file system only after 
all links to it have been deleted. After you create a hard link, programs can use it like any other file name.

NOTE:
Winsows hard links only work for files in the same logical disk volume, i.e the same NTFS file system.

NOTE:
The file to link to must have write permissions or else the link attempt will fail with an exception

NOTE:
Hard link ACL's & attributes are properties of the actual file system entry, which is the same for all 
linked references. That means if you change the permissions/owner/attributes on one hard link, you will 
immediately see the changes on all the other hard links.

NOTE:
The windows FileSystem utility: fsutil.exe can be used to manage hard linked files:
https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-hardlink



.EXAMPLE
Make hard linked copies of all the files in C:\tmp into the new folder C:\tmp_test
Copy-FilesAsHardlinks -SourceDir 'C:\tmp'   -DestinationDir 'C:\tmp_test'
Copy-FilesAsHardlinks -SourceDir 'C:\tmp\*' -DestinationDir 'C:\tmp_test'

.EXAMPLE
Copy the subdirectory structure from C:\tmp to C:\tmp_test and recursively make 
hard link copies of the source files into the respective destination directories.
Copy-FilesAsHardlinks -SourceDir 'C:\tmp' -DestinationDir 'C:\tmp_test' -Recurse

.EXAMPLE
Copy the subdirectory structure from C:\tmp to C:\tmp_test and recursively make 
hard link copies of the '*.txt' source files into the respective destination directories.
Copy-FilesAsHardlinks -SourceDir 'C:\tmp' -Include '*.txt' -DestinationDir 'C:\tmp_test' -Recurse

.EXAMPLE
Test what what hard links would be created with -Whatif
Copy-FilesAsHardlinks -SourceDir 'C:\tmp\*.txt' -DestinationDir 'C:\tmp_test' -Whatif

.EXAMPLE
Make hard linked copies of the *.txt files in C:\tmp to the new folder C:\tmp_test
Copy-FilesAsHardlinks -SourceDir 'C:\tmp\*.txt'            -DestinationDir 'C:\tmp_test'
Copy-FilesAsHardlinks -SourceDir 'C:\tmp' -Include '*.txt' -DestinationDir 'C:\tmp_test'



.PARAMETER SourceDir
A directory path to the folder containing the orignal files which are the target of the new hard link.
Or a file path with a wildcard pattern specifying one or more source files to link, e.g. C:\tmp\*.txt

.PARAMETER DestinationDir
The directory in which the new hard link file entries will be made. 
The destination directory is created if it does not exist, (like Copy-Item)

.PARAMETER Include
An optional file filter to use (like Copy-Item) example: @('*.dll' , '*.exe')
This parameter is ignored if the SourceDir specifies one or more files e.g. C:\tmp\*.txt

.PARAMETER Exclude
An optional file exlusion filter to use (like Copy-Item) example: example: @('*.config' , '*.ini')

.PARAMETER Recurse
Recursively hard link all the files in subfolders
This parameter is ignored if the SourceDir specifies one or more files e.g. C:\tmp\*.txt

.PARAMETER Force
Overwrite any pre-existing files in the destination directory with the new hard link.

.PARAMETER Force
Returns the created destiation files. By default, this cmdlet doesn't generate any output
#>
function Copy-FilesAsHardlinks
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $SourceDir,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationDir,

        [Parameter()]
        [string[]] $Include = $null,

        [Parameter()]
        [string[]] $Exclude = $null,

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $PassThru
    )   

    # Validate input params
    if ((Split-Path -Path $SourceDir -Leaf) -eq '*')
    {
        $SourceDir = Split-Path -Path $SourceDir -Parent
    }
    if (Test-Path -Path $SourceDir -PathType Container)
    {
        $SourceDir = (Resolve-Path -Path $SourceDir).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    }
    else 
    {       
        $Recurse = $false # Only copy the selected file(s) in the root folder
        $SrcPath = Resolve-Path -Path $SourceDir | Where-Object { Test-Path -Path $_ -PathType Leaf }
        if (!$SrcPath)
        {
            if ($ErrorActionPreference -notin @("Ignore", "SilentlyContinue"))
            {
                throw [System.ArgumentException]"Cannot find path $SourceDir because it does not exist"
            }
            return
        }
        $Include = $SrcPath | Split-Path -Leaf
        $SourceDir = Split-Path -Path $SourceDir -Parent            
    }

    $SourceDirLen = $SourceDir.Length
    [array]$SrcDirS = Get-Item -Path $SourceDir
    if ($Recurse)
    {
        $SrcDirS += Get-ChildItem -Recurse -Path $SourceDir -Directory
    }

    foreach ($SrcDir in $SrcDirS.FullName)
    {
        $DstDir = $DestinationDir + $SrcDir.Substring($SourceDirLen)
        $SrcPath = $SrcDir + [System.IO.Path]::DirectorySeparatorChar + '*'
        $SrcFileS = Get-ChildItem -Path $SrcPath -Include $Include -Exclude $Exclude -File -Force #include hidden files
        if ($SrcFileS)
        {
            if (!(Test-Path -Path $DstDir))
            {
                $null = New-Item -ItemType Directory -Path $DstDir
            }
            foreach ($SrcFile in $SrcFileS) 
            {
                $NewLink = New-Item -ItemType HardLink -Path $DstDir -Name $SrcFile.Name -Target $SrcFile.FullName -Force:$Force
                if ($PassThru)
                {
                    Write-Output $NewLink # Send it out the pipeline
                }
            }
        }
        elseif ($Recurse) 
        {
            if (!(Test-Path -Path $DstDir))
            {
                $null = New-Item -ItemType Directory -Path $DstDir
            }
        }
    }
}




<####  Unit test ####

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Exclude = $Include = $null
$TestOutDir = "$ENV:TMP\HardLink_Test"
$TestBigDir = $false
#$TestBigDir = $true
if ($TestBigDir)
{
    $SrcDir = "$ENV:USERPROFILE\.vscode"   # Has 10K+ files in 2K+ SubDirectories
    $DstDir = "$TestOutDir\.vscode"
    $Exclude = @('*.dll', '*.exe', '*.pdb')  # Exclude files loaded by vscode runtime so that we can remove the hardlinks when running this test from within VsCode
}
else 
{
    $SrcDir = "$ENV:LOCALAPPDATA\Microsoft\Media Player"    # Has only a few files folders
    $DstDir = "$TestOutDir\Media Player"
}


# Test bad file-path with SilentlyContinue
Copy-FilesAsHardlinks -SourceDir 'C:\tmp\*.FooBar' -DestinationDir $TestOutDir -ErrorAction SilentlyContinue


[array]$DstFileS = Copy-FilesAsHardlinks -PassThru -SourceDir $SrcDir -DestinationDir $DstDir `
                                         -Exclude $Exclude -Recurse -Force -ErrorAction 'Stop' #| Tee-Object -FilePath "$TestOutDir\test.log"
# Validate the files
[array]$SrcFileS = Get-ChildItem -Path "$SrcDir\*" -Include $Include -Exclude $Exclude -File -Recurse -Force
if ($DstFileS.Count -ne $SrcFileS.Count)
{
    "Error: Files in SourceDir=$($SrcFileS.Count) DestinationDir=$($DstFileS.Count)" | Write-Host -ForegroundColor Red
}
else 
{
    "Success: Copied $($DstFileS.Count) files" | Write-Host -ForegroundColor Green
}

# Validate the dirs
[array]$SrcDirS = Get-ChildItem -Path $SrcDir -Directory -Recurse -Force
[array]$DstDirS = Get-ChildItem -Path $DstDir -Directory -Recurse -Force
if ($DstDirS.Count -ne $SrcDirS.Count)
{
    "Error: Subdirectories in SourceDir=$($SrcDirS.Count) DestinationDir=$($DstDirS.Count)" | Write-Host -ForegroundColor Red
}
else 
{
    "Success: Copied $($DstDirS.Count) Subdirectories" | Write-Host -ForegroundColor Green
}

# Cleanup
Write-Host "Remove-Item -Force -Recurse -Path '$TestOutDir'" -ForegroundColor Cyan

#>
