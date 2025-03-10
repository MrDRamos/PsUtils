function Copy-FileToAzBlob
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Alias('FilePath')]
        [string] $Path = $null,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $StorageAccountName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ContainerName,

        [Parameter()]
        [string] $BlobPath = $null,

        [Parameter()]
        [string] $BlobName = $null,

        [Parameter()]
        [string] $SasToken = $null
    )

    if ([string]::IsNullOrEmpty($Path))
    {
        return
    }

    # Process input variables
    $LocalFilePath = Resolve-Path -Path $Path -ErrorAction Stop
    if (!(Test-Path -Path $LocalFilePath -PathType Leaf))
    {
        Throw "The path is not a file: $Path"
    }
    $FileContent = [System.IO.File]::ReadAllBytes($localFilePath)

    if ([string]::IsNullOrEmpty($BlobName))
    {
        $BlobName = Split-Path -Path $LocalFilePath -Leaf
    }
    if ([string]::IsNullOrEmpty($BlobDir))
    {
        $BlobPath = $BlobName
    }
    else 
    {
        $BlobPath = $BlobDir + '/' + $BlobName
    }
    $BlobPath = $BlobPath -replace '\\', '/'

    $SasTokenShow = $null
    if (![string]::IsNullOrEmpty($SasToken))
    {
        if ($SasToken[0] -ne '?')
        {
            $SasToken = '?' + $SasToken
        }
        $SasTokenShow = $SasToken -replace '&sig=.*', '&sig=<...>'
    }   
    $Uri = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$BlobPath"

    $Headers = @{
        "x-ms-blob-type" = "BlockBlob"
        "x-ms-date"      = (Get-Date).ToUniversalTime().ToString("R")
        "x-ms-version"   = "2015-02-21"
        "Content-Length" = $FileContent.Length
        "Content-Type"   = "application/octet-stream"
    }
    
    Write-Verbose "Uploading Azure-Blob: $LocalFilePath -> $uri$SasTokenShow"
    try 
    {
        $Response = Invoke-RestMethod -Uri "$Uri$SasToken" -Method Put -Headers $Headers -Body $FileContent
        if ($Response)
        {
            if ($DebugPreference)
            {
                Write-Host "`nRaw Response:`n" + $Response.RawContent
            }
            if ($Response.StatusCode -ne 200)
            {
                Throw "Web request error($($Response.StatusCode)) writing to Azure storage: $Uri`nRaw Response:`n$($Response.RawContent)"
            }    
        }
    }
    catch 
    {
        Throw "Web request error writing to Azure storage: $Uri`n$($_.Exception.Message)"
    }
}


<# Unit test
$ParamS = @{
    Path               = "C:\tmp\test.txt"
    StorageAccountName = "ion6edstorage"
    ContainerName      = "test"
    BlobPath           = 'logs'
    BlobName           = "mytest.log"
    SasToken           = "sp=racwdl&st=2025-01-10T15:33:13Z&se=2025-10-31T22:33:13Z&spr=https&sv=2022-11-02&sr=c&sig=pmXBndk0a%2BWVLp75OUmPpYWjwUdA2grgitSTivR7KSg%3D"
}
Copy-FileToAzBlob @ParamS -Verbose
#>
