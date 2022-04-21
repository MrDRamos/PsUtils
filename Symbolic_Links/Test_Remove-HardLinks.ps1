####  Unit test ####

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. $PSScriptRoot\Copy-HardLinks.ps1
. $PSScriptRoot\Remove-Hardlinks.ps1

$TestFolder = "HardLink_Test"
$TestDir = "$ENV:TMP\$TestFolder"
$TestSrc = "$TestDir\src"
Remove-Item -Path "$TestDir\*" -Recurse -Force -ErrorAction Ignore 

function New_LinkedFiles
{
    "$TestDir\testL.txt", "$TestDir\order\testL.txt", "$TestDir\test.txt" | Remove-Item -ErrorAction Ignore
    "test" > "$TestDir\test.txt"
    New-Item -ItemType HardLink  -Path "$TestDir\testL.txt" -Target "$TestDir\test.txt"
    New-Item -ItemType Directory -Path "$TestDir\order" -ErrorAction Ignore
    New-Item -ItemType HardLink  -Path "$TestDir\order\testL.txt" -Target "$TestDir\test.txt"
}

# TEST: Depenency on order
$null = New_LinkedFiles
Remove-HardLinks "$TestDir\testL.txt", "$TestDir\order\testL.txt", "$TestDir\test.txt"
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


function New_DirTree($Root = $TestSrc)
{
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

# TEST: Simple Remove-Item with no links
$DstDir = "$TestDir\src"
$null = New_DirTree $DstDir

Remove-HardLinks -Path $DstDir -Recurse
[array]$FileS = Get-ChildItem -File -Path $DstDir -Recurse
if ($FileS)
{
    "Simple Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "Simple Success: Removed all files in: $DstDir" | Write-Host -ForegroundColor Green
}


# TEST: Only folders, no files
function New_Folders
{
    $null = New_DirTree
    Get-ChildItem $TestSrc -File -Recurse | Remove-Item
}

$null = New_Folders
$DstDir = "$TestDir\src"
Remove-Hardlinks "$DstDir\sub2\sub3", "$DstDir\sub*", $DstDir
[array]$FileS = Get-ChildItem -Path $DstDir -Recurse
if ($FileS)
{
    "Empty-Folders Error: Failed to remove $($FileS.Count) folders:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "Empty-Folders Success: Removed all folders in: $DstDir" | Write-Host -ForegroundColor Green
}

$null = New_Folders
$DstDir = $TestSrc
Remove-Hardlinks $TestSrc -Recurse
[array]$FileS = Get-ChildItem -File -Path $DstDir -Recurse
if ($FileS)
{
    "Empty-Folders Recurse Error: Failed to remove $($FileS.Count) folders:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "Empty-Folders Recurse Success: Removed all folders in: $DstDir" | Write-Host -ForegroundColor Green
}


# TEST: Remove links
$null = New_DirTree
$DstDir = "$TestDir\Copy"
Copy-HardLinks -Path $TestDir -Destination $DstDir
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

# TEST: Pipeline to Remove-HardLinks
$DstDir = "$TestDir\Pipe"
$null = "$DstDir\Sub1", "$DstDir\Sub2" | ForEach-Object { New-Item -Path $_ -ItemType Directory }
$null = New_DirTree
[array]$LnkItemS = "$TestDir\Src\Sub1", "$TestDir\Src\Sub2" | Copy-HardLinks -Destination $DstDir -PassThru -Force

"$DstDir\Sub1", "$DstDir\Sub2" | Remove-HardLinks -Recurse -ErrorAction 'Inquire'
[array]$FileS = Get-ChildItem -File -Path $DstDir -Recurse
if ($FileS)
{
    "Pipe Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "Pipe Success: Removed all files in: $DstDir" | Write-Host -ForegroundColor Green
}
Remove-Item -Path "$TestDir\*" -Recurse -Force -ErrorAction Ignore 
