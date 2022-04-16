<#
.SYNOPSIS
 A hard link is a directory entry for a file. Every file can be considered to have at least one hard link.
 On NTFS volumes, each file can have multiple hard links, so a single file can appear in many directories 
 (or even in the same directory with different names). Because all of the links reference the same file, 
 programs can open any of the links and modify the file. A file is deleted from the file system only after 
 all links to it have been deleted. After you create a hard link, programs can use it like any other file name.

.NOTES
Winsows hard links only work for files in the same logical disk volume, i.e the same file system.

.NOTES
The file to link to must have write permissions or else the link attempt will fail with an exception

.NOTES
Hard link ACL's & attributes are properties of the actual file system entry, which is the same for all 
linked references. That means if you change the permissions/owner/attributes on one hard link, you will 
immediately see the changes on all the other hard links.

.NOTES
Thw native windows command line tool to create symbolic links is mklink, e.g. as Administrator run:
& $ENV:ComSpec /C mklink /H <Path> <Target>
The windows FileSystem utility: fsutil.exe can be used to manage hard linked files:
https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-hardlink
#>

$ErrorActionPreference ='stop'
Set-Location -Path $Env:Temp
Remove-Item -Path ".\test*.txt"

# Create hard linked files
"File content: Hello World" | Out-File -FilePath ".\test.txt"
$null = New-Item -ItemType HardLink -Path ".\test.hardcopy.txt" -Target (Resolve-Path -Path ".\test.txt") -Verbose

# Show that the 2 directory entries are in fact the same hard disk file
Get-Content -Path ".\test.hardcopy.txt"
& fsutil.exe hardlink list ".\test.hardcopy.txt"
(Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime, Target | Format-Table | Out-String).TrimStart()

# There can be multiple hard links to the same underlying file
$null = New-Item -ItemType HardLink -Path ".\test.hardcopy2.txt" -Target (Resolve-Path -Path ".\test.txt") -Verbose
& fsutil.exe hardlink list ".\test.hardcopy.txt"
(Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime, Target | Format-Table | Out-String).TrimStart()
Compare-Object -ReferenceObject (Get-Content ".\test.txt") -DifferenceObject (Get-Content ".\test.hardcopy2.txt") | Write-Host -ForegroundColor Red

# The files stay linked even after one of them is moved
Move-Item -Path ".\test.hardcopy2.txt" -Destination ".\test.hardmove.txt" -Verbose
(Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime, Target | Format-Table | Out-String).TrimStart()
Compare-Object -ReferenceObject (Get-Content ".\test.txt") -DifferenceObject (Get-Content ".\test.hardmove.txt") | Write-Host -ForegroundColor Red

# Deleting the original file does not delete the hardlinks
# Remove-Item -Path ".\test.txt" -Verbose       # Fails if one of the hardlinks has a lock on the file
# Alternative to Remove-Item: Move the file to one of its shared hardliks, works even if one of the hardlinks has a lock on the file
Move-Item -Path ".\test.txt" -Destination ".\test.hardcopy.txt"
(Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime, Target | Format-Table | Out-String).TrimStart()



# Editing one file -> Edits the hardlinked files
"Appended an extra line" | Out-File -FilePath ".\test.hardcopy.txt"  -Append  -Verbose
(Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime, LastAccessTime | Format-Table | Out-String).TrimStart()
Compare-Object -ReferenceObject (Get-Content ".\test.hardcopy.txt") -DifferenceObject (Get-Content ".\test.hardmove.txt") | Write-Host -ForegroundColor Red

# Overwriting contents in one file -> Changes contents in the hardlinked files
"Replaced the entire content" | Set-Content -Path ".\test.hardcopy.txt" -Verbose
(Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime, LastAccessTime | Format-Table | Out-String).TrimStart()
Compare-Object -ReferenceObject (Get-Content ".\test.hardcopy.txt") -DifferenceObject (Get-Content ".\test.hardmove.txt") | Write-Host -ForegroundColor Red

# Reseting one file -> Resets all the hardlinked files
$null = New-Item -ItemType File -Path ".\test.hardcopy.txt" -Force -Verbose
(Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime, LastAccessTime | Format-Table | Out-String).TrimStart()



# Break the link
Remove-Item -Path ".\test.hardcopy.txt"
"New file content" | Set-Content -Path ".\test.hardcopy.txt" -Verbose
(Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime, Target | Format-Table | Out-String).TrimStart()

# The underlying file is removed after the last reference is removed
Remove-Item -Path ".\test*.txt"
