
$MyDefaultTokenFilename = "$env:TMP\MyAzureToken.json"



<#
.SYNOPSIS
Returns an Azure access token, needed for makeing calls to Azure Rest API's
The $Return.AccessToken field contains the bearer token needed for Rest calls.

.PARAMETER AzTenantId
The default (if left blank) is taken from the currenly logged in AzureContext, 

.PARAMETER AzToken
The passed in token is checked to ensure that is has not expired yet.
The function simply returns back the original token if its still valid.
A new refreshed token is returned if the old one has (or is about to) expire
within 30 minutes.
#>
Function Get-MyAzureContextToken
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ParameterSetName = "byTenantId")]
        [string] $AzTenantId = $null,

        [Parameter(Mandatory, ParameterSetName = "byToken")]
        [object] $AzToken
    )

    if ($AzToken)
    {
        $Timeout = New-TimeSpan -End $AzToken.ExpiresOn.DateTime
        if ($Timeout.TotalMinutes -gt 30)
        {
            # The Aztoken is still good...
            return $AzToken
        }
        $AzTenantId = $AzToken.TenantId
    }
    else 
    {
        if (!$AzTenantId)
        {
            if ($PSVersionTable.PSEdition -eq "core")
            {
                $AzContext = Get-AzContext
            }
            else 
            {
                $AzContext = Get-AzureRmContext
            }
            if ($AzContext -and $AzContext.Subscription)
            {
                $AzTenantId = $AzContext.Tenant.Id
            }
            else 
            {
                Write-Error "Get-MyAzureContextToken: Failed because this session is not logged into Azure."
                return $null
            }
        }
    }

    $AzureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (!$AzureRmProfile.Accounts.Count)
    {
        Write-Error "Get-MyAzureContextToken: Failed because this session is not logged into Azure."
        return $null
    }
    $ProfileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($AzureRmProfile)
    $AzToken = $ProfileClient.AcquireAccessToken($AzTenantId)

    return $AzToken
}



function Save-MyAzureContextToken
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [object] $AzToken = $null,

        [ValidateNotNullOrEmpty()]
        [object] $Filename = $MyDefaultTokenFilename
    )

    if (!$AzToken)
    {
        $AzToken = Get-MyAzureContextToken
    }

    if (Test-Path $Filename)
    {
        Remove-Item -Path $Filename -Force -ErrorAction Ignore
    }
    if ($AzToken)
    {
        $AzToken | ConvertTo-Json | Set-Content -Path $Filename -Encoding UTF8
    }
}



function Read-MyAzureContextToken
{
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [object] $Filename = $MyDefaultTokenFilename
    )

    if (Test-Path $Filename)
    {
        try 
        {
            $AzToken = Get-Content -Path $Filename -Encoding UTF8 | ConvertFrom-Json -ErrorAction Ignore
        }
        catch 
        {
            Write-Error "Read-MyAzureContextToken: Failed to parse token file."
        }
    }
    else 
    {
        Write-Error "Read-MyAzureContextToken: Token file not found $Filename"
    }
    return $AzToken
}



function Restore-MyAzureSession
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [object] $AzToken = $null,

        [ValidateNotNullOrEmpty()]
        [object] $Filename = $MyDefaultTokenFilename
    )

    if (!$AzToken)
    {
        $AzToken = Read-MyAzureContextToken -Filename $Filename -ErrorAction SilentlyContinue
    }

    $AzContext = $null
    if ($AzToken)
    {
        if ($PSVersionTable.PSEdition -eq "core")
        {
            $AzProfile = Connect-AzAccount -AccessToken $AzToken.AccessToken -AccountId $AzToken.UserId -TenantId $AzToken.TenantId
        }
        else 
        {
            $AzProfile = Connect-AzureRmAccount -AccessToken $AzToken.AccessToken -AccountId $AzToken.UserId -TenantId $AzToken.TenantId
        }
        if ($AzProfile)
        {
            $AzContext = $AzProfile.Context
        }
        if (!$AzContext -or !$AzContext.Subscription)
        {
            Write-Error "Restore-MyAzureSession: The cached token is invalid." 
        }
    }
    return $AzContext
}



function Connect-MyAzureSession
{
    [CmdletBinding()]
    Param([switch] $Force)

    $AzContext = $null
    if (!$Force)
    {
        $AzContext = Restore-MyAzureSession -ErrorAction SilentlyContinue
    }
    
    if (!$AzContext)
    {
        if ($PSVersionTable.PSEdition -eq "core")
        {
            $AzProfile = Connect-AzAccount
        }
        else 
        {
            $AzProfile = Connect-AzureRmAccount
        }
        if ($AzProfile -and $AzProfile.Context)
        {
            $AzContext = $AzProfile.Context
        }
        Save-MyAzureContextToken
    }
    return $AzContext
}

