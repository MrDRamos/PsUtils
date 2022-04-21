####  Unit test ####

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. $PSScriptRoot\Copy-HardLinks.ps1
. $PSScriptRoot\Remove-Hardlinks.ps1
. $PSScriptRoot\Get-HardLinks.ps1

$TestFolder = "HardLink_Test"
$TestDir = "$ENV:TMP\$TestFolder"
$TestSrc = "$TestDir\src"
Remove-Item -Path "$TestDir\*" -Recurse -Force -ErrorAction Ignore 

function New_DirTree($Root = $TestSrc)
{
    Remove-Item -Path $Root -Recurse -ErrorAction Ignore
    New-Item -ItemType Directory -Force -Path $Root
    New-Item -ItemType File -Force -Path "$Root\f1.txt"
    New-Item -ItemType File -Force -Path "$Root\f2.txt"
    New-Item -ItemType File -Force -Path "$Root\f1.log"
    New-Item -ItemType File -Force -Path "$Root\f2.log"
    New-Item -ItemType File -Force -Path "$Root\f3"
    New-Item -ItemType File -Force -Path "$Root\sub3.txt"
    New-Item -ItemType Directory -Force -Path "$Root\sub1"
    New-Item -ItemType Directory -Force -Path "$Root\sub2"
    New-Item -ItemType File -Force -Path "$Root\sub2\f21.txt"
    New-Item -ItemType File -Force -Path "$Root\sub2\f22.txt"
    New-Item -ItemType File -Force -Path "$Root\sub2\f12.log"
    New-Item -ItemType File -Force -Path "$Root\sub2\f22.log"
    New-Item -ItemType File -Force -Path "$Root\sub2\f23"
    New-Item -ItemType Directory -Force -Path "$Root\sub2\sub3"
}

function New_LinkedFiles
{
    "$TestDir\testL.txt", "$TestDir\order\testL.txt", "$TestDir\test.txt" | Remove-Item -ErrorAction Ignore
    "test" > "$TestDir\test.txt"
    New-Item -ItemType HardLink  -Path "$TestDir\testL.txt" -Target "$TestDir\test.txt"
    New-Item -ItemType Directory -Path "$TestDir\order" -ErrorAction Ignore
    New-Item -ItemType HardLink  -Path "$TestDir\order\testL.txt" -Target "$TestDir\test.txt"
}


# TEST: Pipeline with File objects
$null = New_LinkedFiles
$FileS = Get-HardLinks -Path $TestDir -Recurse
$FileS | Remove-HardLinks

# TEST: Pipeline with File names
$null = New_LinkedFiles
$FileS = Get-HardLinks -Path $TestDir -Recurse
$FileS.FullName | Remove-HardLinks

# TEST: Implicit Name to File object conversion
$null = New_LinkedFiles
$FileS = Get-HardLinks -Path $TestDir -Recurse
Remove-HardLinks -File $FileS.FullName

# TEST: Depenency on order
$null = New_LinkedFiles
"$TestDir\testL.txt", "$TestDir\order\testL.txt", "$TestDir\test.txt" | Remove-HardLinks
[array]$FileS = Get-ChildItem -File -Path $TestDir -Recurse
if ($FileS)
{
    "Order1 Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "Order1 Success: Removed all files in: $TestDir" | Write-Host -ForegroundColor Green
}

$null = New_LinkedFiles
"$TestDir\testL.txt", "$TestDir\order\testL.txt", "$TestDir\test.txt" | Remove-HardLinks
if ($FileS)
{
    "Order2 Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "Order2 Success: Removed all files in: $TestDir" | Write-Host -ForegroundColor Green
}

$null = New_LinkedFiles
Remove-HardLinks "$TestDir\testL.txt", "$TestDir\order\testL.txt", "$TestDir\test.txt"
if ($FileS)
{
    "Order3 Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "Order3 Success: Removed all files in: $TestDir" | Write-Host -ForegroundColor Green
}


# TEST: Principal use case: Delete everythng, no links
$DstDir = "$TestDir\src"
$null = New_DirTree $DstDir

Remove-HardLinks -Path $DstDir -Recurse
[array]$FileS = Get-ChildItem -File -Path $DstDir -Recurse
$FileS += Get-Item $DstDir -ErrorAction Ignore
if ($FileS)
{
    "All,-Links Error: Failed to remove $($FileS.Count) items:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "All,-Links Success: Removed all items in: $DstDir" | Write-Host -ForegroundColor Green
}


# TEST: Only folders, no files
function New_Folders
{
    $null = New_DirTree
    Get-ChildItem $TestSrc -File -Recurse | Remove-Item
}

Remove-Item -Recurse "$TestDir\*" -ErrorAction Ignore
$DstDir = "$TestDir\OneDir"
$null = New-Item -ItemType Directory -path $DstDir
"some data" | Set-Content -Path "$DstDir\test.txt"
Remove-Hardlinks -Path "$DstDir\*"
[array]$FileS = Get-ChildItem -Path $DstDir
if ($FileS -and (Test-Path $DstDir))
{
    "AllFiles,-Recurse Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "AllFiles,-Recurse Success: Removed all files in: $DstDir" | Write-Host -ForegroundColor Green
}

Remove-Hardlinks -Path $DstDir
if (Test-Path $DstDir)
{
    "1EmptyDir Error: Failed to remove $($FileS.Count) folders:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "1EmptyDir Success: Removed all folders in: $DstDir" | Write-Host -ForegroundColor Green
}

$null = New_Folders
$DstDir = "$TestDir\src"
#Note: Order matters! 
#Remove-Item     -Path "$DstDir\sub2\sub3", "$DstDir\sub*", $DstDir
Remove-Hardlinks -Path "$DstDir\sub2\sub3", "$DstDir\sub*", $DstDir
#Remove-Item     -Path $DstDir, "$DstDir\sub2\sub3", "$DstDir\sub*"
#Remove-Hardlinks -Path$DstDir, "$DstDir\sub2\sub3", "$DstDir\sub*"
[array]$FileS = Get-ChildItem -Path $DstDir -Recurse
$FileS += Get-Item $DstDir -ErrorAction Ignore
if ($FileS)
{
    "EmptyDirS,-Recurse Error: Failed to remove $($FileS.Count) folders:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "EmptyDirS,-Recurse Success: Removed all folders in: $DstDir" | Write-Host -ForegroundColor Green
}

$null = New_Folders
$DstDir = $TestSrc
Remove-Hardlinks -Path $TestSrc -Recurse
[array]$FileS = Get-ChildItem -File -Path $DstDir -Recurse
$FileS += Get-Item $DstDir -ErrorAction Ignore
if ($FileS)
{
    "EmptyDirS,+Recurse Error: Failed to remove $($FileS.Count) folders:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "EmptyDirS,+Recurse Success: Removed all folders in: $DstDir" | Write-Host -ForegroundColor Green
}


# TEST: Remove links
$null = New_DirTree
$DstDir = "$TestDir\Copy"
Copy-HardLinks -Path $TestDir -Destination $DstDir -Recurse
Remove-Hardlinks -Path $DstDir -Recurse
[array]$FileS = Get-ChildItem -File -Path $DstDir -Recurse
if ($FileS)
{
    "Links Error: Failed to remove $($FileS.Count) folders:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "Links Success: Removed all folders in: $DstDir" | Write-Host -ForegroundColor Green
}
Remove-Item -Path "$TestDir\*" -Recurse -Force -ErrorAction Ignore 

