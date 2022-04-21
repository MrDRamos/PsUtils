####  Unit test ####

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. $PSScriptRoot\Copy-HardLinks.ps1
. $PSScriptRoot\Remove-Hardlinks.ps1

$TestFolder = "HardLink_Test"
$TestDir = "$ENV:TMP\$TestFolder"
$TestSrc = "$TestDir\src"

function New_DirTree($TestDir)
{
    New-Item -ItemType Directory -Force -Path "$TestDir\src"
    New-Item -ItemType File -Force -Path "$TestSrc\f1.txt"
    New-Item -ItemType File -Force -Path "$TestSrc\f2.txt"
    New-Item -ItemType File -Force -Path "$TestSrc\f1.log"
    New-Item -ItemType File -Force -Path "$TestSrc\f2.log"
    New-Item -ItemType File -Force -Path "$TestSrc\f3"
    New-Item -ItemType Directory -Force -Path "$TestSrc\sub1"
    New-Item -ItemType Directory -Force -Path "$TestSrc\sub2"
    New-Item -ItemType File -Force -Path "$TestSrc\sub2\f21.txt"
    New-Item -ItemType File -Force -Path "$TestSrc\sub2\f22.txt"
    New-Item -ItemType File -Force -Path "$TestSrc\sub2\f12.log"
    New-Item -ItemType File -Force -Path "$TestSrc\sub2\f22.log"
    New-Item -ItemType File -Force -Path "$TestSrc\sub2\f23"
    New-Item -ItemType Directory -Force -Path "$TestSrc\sub2\sub3"
}

function Compare_CopyVsLink($TstName, $Path, $Filter = $null, [switch]$Recurse, [switch]$DestExists)
{
    Write-Host "$TstName, Copy-Item vs HardLink: -Path $Path -Recurse:$Recurse -Filter $Filter"    

    # Test recursive removal
    Remove-Hardlinks -Path "$TestDir\Link" -Recurse -ErrorAction 'Inquire'
    [array]$FileS = Get-ChildItem -File -Path "$TestDir\Link" -Recurse
    if ($FileS)
    {
        "$TstName Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red
        Remove-Item -Path "$TestDir\Link" -Recurse -Force -ErrorAction Ignore
    }

    # Prep Copy dir:
    Remove-Item -Path "$TestDir\Copy" -Recurse -Force -ErrorAction Ignore
    if ($DestExists)
    {
        $null = New-Item -ItemType Directory -Path "$TestDir\Copy"
    }

    # Copy links into 'Copy' dir so that returned file names in LnkItemS will match in MissingNameS test bellow
    [array]$LnkItemS = Copy-HardLinks -Path $Path -Filter $Filter -Destination "$TestDir\Copy" -Recurse:$Recurse -PassThru -Force
    Move-Item -Path "$TestDir\Copy" -Destination "$TestDir\Link"

    if ($DestExists)
    {
        $null = New-Item -ItemType Directory -Path "$TestDir\Copy"
    }
    if (Test-Path -Path $Path -PathType Leaf)
    {
        $null = New-Item -ItemType Directory -Path "$TestDir\Copy" -Force
    }

    # Workaround Copy-Item bug not accepting -Recurse:$false argument
    if ($Recurse)
    {
        [array]$CpyItemS = Copy-Item -Path $Path -Filter $Filter -Destination "$TestDir\Copy" -PassThru -Force -Recurse:$Recurse
    }
    else 
    {
        [array]$CpyItemS = Copy-Item -Path $Path -Filter $Filter -Destination "$TestDir\Copy" -PassThru -Force
    }

    $CpyNameS = $CpyItemS.FullName
    $LnkNameS = $LnkItemS.FullName
    $MissingNameS = $CpyNameS | Where-Object { $_ -notin $LnkNameS }
    $ExtraNameS = $LnkNameS | Where-Object { $_ -notin $CpyNameS }
    if ($ExtraNameS -or $MissingNameS)
    {
        if ($MissingNameS)
        {
            "$TstName Error: Diff Copy-Item() missing:`n$($MissingNameS -join "`n")" | Write-Host -ForegroundColor Red  
        }
        if ($ExtraNameS)
        {
            "$TstName Error: Diff Copy-Item() extra:`n$($ExtraNameS -join "`n")" | Write-Host -ForegroundColor Red  
        }
    }
    else 
    {
        "$TstName Success" | Write-Host -ForegroundColor Green
    }
}



if (Test-Path -Path $TestDir)
{
    Remove-Item -Path "$TestDir\*" -Recurse -ErrorAction Stop
}
$null = New_DirTree $TestDir

# Primary use case:
Compare_CopyVsLink -TstName "Recurse" -Path "$TestSrc\*" -Recurse

# Test bad file-path with SilentlyContinue
Copy-HardLinks -Path '$TestSrc\*.FooBar' -Destination $TestDir -ErrorAction SilentlyContinue

# Test pipeline to Copy-HardLinks
$DstDir = "$TestDir\Pipe"
$null = "$DstDir\Sub1", "$DstDir\Sub2" | ForEach-Object { New-Item -Path $_ -ItemType Directory }
[array]$LnkItemS = "$TestSrc\Sub1", "$TestSrc\Sub2" | Copy-HardLinks -Destination $DstDir -PassThru -Force
[array]$SrcFileS = "$TestSrc\Sub1", "$TestSrc\Sub2" | Get-ChildItem -Recurse -Force
if ($LnkItemS.Count -ne $SrcFileS.Count)
{
    "Pipe Error: Items in Path=$($SrcFileS.Count) Destination=$($LnkItemS.Count)" | Write-Host -ForegroundColor Red
}
else 
{
    "Pipe Success: Copied $($LnkItemS.Count) items" | Write-Host -ForegroundColor Green
}

# Test pipeline to Remove-HardLinks
"$DstDir\Sub1", "$DstDir\Sub2" | Remove-HardLinks -Recurse -ErrorAction 'Inquire'
[array]$FileS = Get-ChildItem -File -Path $DstDir -Recurse
if ($FileS)
{
    "Pipe Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
}
else 
{
    "Pipe Success: Removed all files in: $TestFolder\Pipe" | Write-Host -ForegroundColor Green
}
Remove-Item -Path $DstDir -Recurse -Force -ErrorAction Ignore # Remove top level Pipe folder


# Corner cases
Compare_CopyVsLink -TstName "Filter= *.txt" -Path "$TestSrc\*"  -Filter "*.txt" 
Compare_CopyVsLink -TstName "Filter"        -Path "$TestSrc\*"
Compare_CopyVsLink -TstName "No* "          -Path "$TestSrc"    -Recurse
Compare_CopyVsLink -TstName "No* Exists"    -Path "$TestSrc"    -Recurse    -DestExists
Compare_CopyVsLink -TstName "DestExists *"  -Path "$TestSrc\*"              -DestExists


#Stupid Copy-Item edge cases that fail because Path has no pattern and no -Recurse => They want to just copy an empty folder"
$TestEdgeCases = $false
#$TestEdgeCases = $true
if ($TestEdgeCases)
{
    "Start - Copy-Item edge cases that should fail ..." | Write-Host -ForegroundColor Magenta
    Compare_CopyVsLink -TstName "DestExists" -Path "$TestSrc" -DestExists 
    Compare_CopyVsLink -TstName "No* Filter" -Path "$TestSrc" -Filter "*"
    "Done - Copy-Item edge cases that should have failed." | Write-Host -ForegroundColor Magenta
}


$TestBigDir = $false
$TestBigDir = $true
if ($TestBigDir)
{
    $SrcDir = "$ENV:USERPROFILE\.vscode"   # Has 10K+ files in 2K+ SubDirectories and same internally hard linked files !
    $DstDir = "$TestDir"
    $Include = $null
    $Exclude = $null
    #$Exclude = @('*.dll', '*.exe', '*.pdb')  # Exclude files loaded by vscode runtime so that we can remove the hard links with Remove-Item -Recurse

    Write-Host "Start .vscode test: Copy-HardLinks"
    $Perf = Measure-Command {    
        [array]$CpyItemS = Copy-HardLinks -PassThru -Path "$SrcDir*" -Destination $DstDir `
            -Exclude $Exclude -Recurse -Force -ErrorAction 'Stop' #| Tee-Object -FilePath "$TestDir\test.log"
    }

    # Validate the files
    [array]$SrcFileS = Get-ChildItem -Path "$SrcDir\*" -Include $Include -Exclude $Exclude -File -Recurse -Force
    [array]$DstFileS = $CpyItemS | Where-Object { !$_.PSIsContainer }
    if ($DstFileS.Count -ne $SrcFileS.Count)
    {
        ".vscode Error: Files in Path=$($SrcFileS.Count) Destination=$($DstFileS.Count)" | Write-Host -ForegroundColor Red
    }
    else 
    {
        ".vscode Success Time: $([int]$Perf.TotalSeconds), Copied $($DstFileS.Count) files" | Write-Host -ForegroundColor Green
    }

    # Validate the dirs
    [array]$SrcDirS = Get-ChildItem -Path $SrcDir -Directory -Recurse -Force
    [array]$DstDirS = Get-ChildItem -Path "$DstDir\.vscode" -Directory -Recurse -Force
    [array]$DstDirS2 = $CpyItemS | Where-Object { $_.PSIsContainer }
    if ($DstDirS.Count -ne $SrcDirS.Count)
    {
        ".vscode Error: Subdirectories in Path=$($SrcDirS.Count) Destination=$($DstDirS.Count)" | Write-Host -ForegroundColor Red
    }
    else 
    {
        ".vscode Success: Copied $($DstDirS.Count) Subdirectories" | Write-Host -ForegroundColor Green
    }

    # Test removal of locked files
    Write-Host "Removing .vscode test: Remove-Hardlinks"
    $Perf = Measure-Command { Remove-Hardlinks -Path "$DstDir\.vscode" -Recurse -ErrorAction 'Inquire' }
    [array]$FileS = Get-ChildItem -File -Path "$DstDir\.vscode" -Recurse
    if ($FileS)
    {
        ".vscode Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
        Remove-Item -Path $DstDir -Recurse -ErrorAction Ignore -Force
    }
    else 
    {
        ".vscode Success Time: $([int]$Perf.TotalSeconds), Removed linked files in: $TestFolder\.vscode" | Write-Host -ForegroundColor Green
    }
}


# Cleanup
Write-Host "Remove-Item -Force -Recurse -Path '$TestDir'" -ForegroundColor Cyan
