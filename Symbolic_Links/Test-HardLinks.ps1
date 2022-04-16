####  Unit test ####

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. $PSScriptRoot\Copy-FilesAsHardlinks.ps1
. $PSScriptRoot\Remove-Hardlinks.ps1

$TestDir = "$ENV:TMP\HardLink_Test"
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
    # Test recursive removal
    Remove-Hardlinks -Path "$TestDir\Link" -FindTargetDir -AllFiles -ErrorAction 'Inquire'
    [array]$FileS = Get-ChildItem -File -Path "$TestDir\Link" -Recurse
    if ($FileS)
    {
        "$TstName Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
    }
    Remove-Item -Path "$TestDir\Link", "$TestDir\Copy" -Recurse -ErrorAction Ignore # Remove remainig direcotories

    if ($DestExists)
    {
        $null = New-Item -ItemType Directory -Path "$TestDir\Copy"
    }
    [array]$LnkItemS = Copy-FilesAsHardlinks -Path $Path -Filter $Filter -Destination "$TestDir\Copy" -Recurse:$Recurse -PassThru -Force
    Move-Item -Path "$TestDir\Copy" -Destination "$TestDir\Link"

    if ($DestExists)
    {
        $null = New-Item -ItemType Directory -Path "$TestDir\Copy"
    }
    if (Test-Path -Path $Path -PathType Leaf)
    {
        $null = New-Item -ItemType Directory -Path "$TestDir\Copy" -Force
    }
    Write-Host "Copy-Item -Destination <Copy> -Path $Path -Recurse:$Recurse -Filter $Filter"    
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

Remove-Item -Path $TestDir\* -Recurse -ErrorAction Ignore
$null = New_DirTree $TestDir

Compare_CopyVsLink -TstName "Recurse"       -Path "$TestSrc\*"  -Recurse
Compare_CopyVsLink -TstName "Filter= *.txt" -Path "$TestSrc\*"  -Filter "*.txt" 
Compare_CopyVsLink -TstName "Filter"        -Path "$TestSrc\*"
Compare_CopyVsLink -TstName "No* "          -Path "$TestSrc"    -Recurse
Compare_CopyVsLink -TstName "No* Exists"    -Path "$TestSrc"    -Recurse    -DestExists
Compare_CopyVsLink -TstName "DestExists *"  -Path "$TestSrc\*"              -DestExists
# Stupid Copy-Item edge cases that fail because Path has no pattern and no -Recurse => They want to just copy an empty folder
Compare_CopyVsLink -TstName "DestExists"    -Path "$TestSrc"                -DestExists 
Compare_CopyVsLink -TstName "No* Filter"    -Path "$TestSrc"    -Filter "*"

# Test bad file-path with SilentlyContinue
Copy-FilesAsHardlinks -Path '$TestSrc\*.FooBar' -Destination $TestDir -ErrorAction SilentlyContinue


# Test pipeline
$null = "$TestDir\Pipe\Sub1", "$TestDir\Pipe\Sub2" | ForEach-Object { New-Item -Path $_ -ItemType Directory }
[array]$LnkItemS = "$TestSrc\Sub1", "$TestSrc\Sub2" | Copy-FilesAsHardlinks -Destination "$TestDir\Pipe" -PassThru -Force
[array]$SrcFileS = "$TestSrc\Sub1", "$TestSrc\Sub2" | Get-ChildItem -Recurse -Force
if ($LnkItemS.Count -ne $SrcFileS.Count)
{
    "Pipe Error: Itemss in Path=$($SrcFileS.Count) Destination=$($LnkItemS.Count)" | Write-Host -ForegroundColor Red
}
else 
{
    "Pipe Success: Copied $($LnkItemS.Count) items" | Write-Host -ForegroundColor Green
}


$TestBigDir = $false
$TestBigDir = $true
if ($TestBigDir)
{
    $SrcDir = "$ENV:USERPROFILE\.vscode"   # Has 10K+ files in 2K+ SubDirectories
    $DstDir = "$TestDir"
    $Exclude = $null
    #$Exclude = @('*.dll', '*.exe', '*.pdb')  # Exclude files loaded by vscode runtime so that we can remove the hardlinks when running this test from within VsCode
    $Include = $null

    [array]$CpyItemS = Copy-FilesAsHardlinks -PassThru -Path "$SrcDir*" -Destination $DstDir `
        -Exclude $Exclude -Recurse -Force -ErrorAction 'Stop' #| Tee-Object -FilePath "$TestDir\test.log"

    # Validate the files
    [array]$SrcFileS = Get-ChildItem -Path "$SrcDir\*" -Include $Include -Exclude $Exclude -File -Recurse -Force
    [array]$DstFileS = $CpyItemS | Where-Object { !$_.PSIsContainer }
    if ($DstFileS.Count -ne $SrcFileS.Count)
    {
        "Error: Files in Path=$($SrcFileS.Count) Destination=$($DstFileS.Count)" | Write-Host -ForegroundColor Red
    }
    else 
    {
        "Success: Copied $($DstFileS.Count) files" | Write-Host -ForegroundColor Green
    }

    # Validate the dirs
    [array]$SrcDirS = Get-ChildItem -Path $SrcDir -Directory -Recurse -Force
    [array]$DstDirS = Get-ChildItem -Path "$DstDir\.vscode" -Directory -Recurse -Force
    [array]$DstDirS2 = $CpyItemS | Where-Object { $_.PSIsContainer }
    if ($DstDirS.Count -ne $SrcDirS.Count)
    {
        "Error: Subdirectories in Path=$($SrcDirS.Count) Destination=$($DstDirS.Count)" | Write-Host -ForegroundColor Red
    }
    else 
    {
        "Success: Copied $($DstDirS.Count) Subdirectories" | Write-Host -ForegroundColor Green
    }

    # Test recursive removal of locked files
    Remove-Hardlinks -Path "$DstDir\.vscode" -FindTargetDir -AllFiles -ErrorAction 'Inquire'
    [array]$FileS = Get-ChildItem -File -Path "$DstDir\.vscode" -Recurse
    if ($FileS)
    {
        "Error: Failed to remove $($FileS.Count) files:`n$($FileS.FullName -join "`n")" | Write-Host -ForegroundColor Red          
    }
    Remove-Item -Path $DstDir -Recurse -ErrorAction Ignore # Remove remainig direcotories
}


# Cleanup
Write-Host "Remove-Item -Force -Recurse -Path '$TestDir'" -ForegroundColor Cyan
