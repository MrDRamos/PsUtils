# Example: Windows hard linked files
Set-Location -Path $Env:Temp
Remove-Item -Path ".\test*.txt"

# Create hard linked files
"File content: Hello World" | Out-File -FilePath ".\test.txt"
$null = New-Item -ItemType HardLink -Path ".\test.hardcopy.txt" -Target (Resolve-Path -Path ".\test.txt") -Verbose

# Show that the 2 directory entries are in fact the same hard disk file
Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime | Format-Table
Get-Content -Path ".\test.hardcopy.txt"

# There can be multiple hard links to the same underlying file
$null = New-Item -ItemType HardLink -Path ".\test.hardcopy2.txt" -Target (Resolve-Path -Path ".\test.txt") -Verbose
Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime | Format-Table
Compare-Object -ReferenceObject (Get-Content ".\test.txt") -DifferenceObject (Get-Content ".\test.hardcopy2.txt") | Write-Host -ForegroundColor Red

# The files stay linked event after one of them is moved
Move-Item -Path ".\test.hardcopy2.txt" -Destination ".\test.hardmove.txt" -Verbose
Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime | Format-Table
Compare-Object -ReferenceObject (Get-Content ".\test.txt") -DifferenceObject (Get-Content ".\test.hardmove.txt")  | Write-Host -ForegroundColor Red

# Deleting the original file does not delete the hardlinks
Remove-Item -Path ".\test.txt" -Verbose
Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime | Format-Table



# Editing one file -> Edits the hardlinked files
"Appended an extra line" | Out-File -FilePath ".\test.hardcopy.txt"  -Append  -Verbose
Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime | Format-Table
Compare-Object -ReferenceObject (Get-Content ".\test.hardcopy.txt") -DifferenceObject (Get-Content ".\test.hardmove.txt") | Write-Host -ForegroundColor Red

# Overwriting contents in one file -> Changes contents in the hardlinked files
"Replaced the entire content" | Set-Content -Path ".\test.hardcopy.txt" -Verbose
Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime | Format-Table
Compare-Object -ReferenceObject (Get-Content ".\test.hardcopy.txt") -DifferenceObject (Get-Content ".\test.hardmove.txt") | Write-Host -ForegroundColor Red

# Reseting one file -> Resets all the hardlinked files
$null = New-Item -ItemType File -Path ".\test.hardcopy.txt" -Force -Verbose
Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime | Format-Table



# Break the link
Remove-Item -Path ".\test.hardcopy.txt"
"New file content" | Set-Content -Path ".\test.hardcopy.txt" -Verbose
Get-Item test* | Select-Object Name, LinkType, Length, LastWriteTime | Format-Table

# The underlying file is removed after the last reference is removed
Remove-Item -Path ".\test*.txt"
