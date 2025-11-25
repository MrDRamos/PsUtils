
#region crypto utils

<#
.SYNOPSIS
Output a hexadecimal string
#>
function Convert-BytesToHex
{
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline)]
		[byte[]] $Bytes
	)

	# $Input is an automatic variable that references the pipeline value
    if ($Input)
    {
        $Bytes = $Input
    }
	if ($Bytes)
	{
		($Bytes | ForEach-Object { $_.ToString("X2") }) -join ""
	}	
}


function Get-RandomBytes
{
	[CmdletBinding()]
    [OutputType([byte[]])]
	param (
		[Parameter()]
		[int] $Length = 16		# 16 * 8 = 128 Bits
	)

	if ($Length -lt 1)
	{
		return [int[]]@()
	}
	$Result = New-Object Byte[] $Length
	[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($Result)
	return $Result
}


function Convert-PassPhraseToPBKDF2Key
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Scope='Function')]    
    [CmdletBinding(DefaultParameterSetName='ByPlainStr')]
    [OutputType([byte[]])]
	param (
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName ='BySecureStr')]
		[ValidateNotNullOrEmpty()]
		[SecureString] $PassPhrase,

		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName ='ByPlainStr')]
		[ValidateNotNullOrEmpty()]
		[String] $PassPhrasePlain,

		[Parameter()]
		[int] $KeyByteSize = 16, 		# AES-256 requires a 256-bit key

		[Parameter()]
		[int] $Iterations = 10000, 	    # Recommended: at least 1000 iterations

		[Parameter()]
		[byte[]] $Salt = $null          # Salt size must be 8 bytes or larger, Default= 00000000
	)

	if (!$Salt)
	{
		$Salt = New-Object Byte[] 8
		#[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($Salt)
	}

    if ($PassPhrase)
    {
        $PassPhrasePlain = (New-Object System.Net.NetworkCredential($null, $PassPhrase)).Password
    } 

	# Create a PBKDF2 instance
	$Pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes -ArgumentList $PassPhrasePlain, $Salt, $Iterations

	return $Pbkdf2.GetBytes($KeyByteSize)
}
<#### Unit Test
$Key = 'MyPassword' | Convert-PassPhraseToPBKDF2Key
$Key | Convert-BytesToHex
$Key = ConvertTo-SecureString -String 'MyPassword' -AsPlainText -Force | Convert-PassPhraseToPBKDF2Key
$Key | Convert-BytesToHex
exit
#>
#>


function New-AesConverter
{
    [CmdletBinding()]
    #[OutputType([System.Security.Cryptography.CapiSymmetricAlgorithm])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('EnCryptor', 'DeCryptor')]
        [string] $Type,

        [Parameter(Mandatory)]
        [Alias('Key')]
        [byte[]] $KeyBytes,

        [Parameter()]
        [string] $KeyB64String = $null,

        [Parameter()]
        [byte[]] $IVBytes = $null,

        [Parameter()]
        [string] $IVB64String = $null
    )


    if (![string]::IsNullOrEmpty($KeyB64String))
    {
        $KeyBytes = [System.Convert]::FromBase64String($KeyB64String)
    }

    if (![string]::IsNullOrEmpty($IVB64String))
    {
        $IVBytes = [System.Convert]::FromBase64String($IVB64String)
    }

    if ($Type -eq 'DeCryptor')
    {
        if (!$IVBytes)
        {
            Throw "The Initialization-Vector that was used for encryption was not specified"
        }
        if ($IVBytes.Length -ne 16)
        {
            Throw "The Initialization-Vector must have 16 bytes"
        }
    }
    else
    {
        if ($IVBytes)
        {
            if ($IVBytes.Length -ne 16)
            {
                Throw "The Initialization-Vector must have 16 bytes"
            }
        }
        else 
        {
            $IVBytes = Get-RandomBytes -Length 16
        }
    }

    $aes = $null
    try 
    {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        #$aes.BlockSize = 128
        #$aes.KeySize = $KeyBytes.Length * 8

        $aes.Key = $KeyBytes
        $aes.IV = $IVBytes
        if ($Type -eq 'DeCryptor')
        {
            return $aes.CreateDecryptor()
        }       
        return @($aes.CreateEncryptor(), $IVBytes)
    }
    finally
    {
        if ($aes)
        {
            $aes.Dispose()
        }
    }    
}


function New-PassPhraseAesConverter
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Scope='Function')]    
	[CmdletBinding(DefaultParameterSetName='ByPlainStr')]
	param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('EnCryptor', 'DeCryptor')]
        [string] $Type,

		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName ='BySecureStr')]
		[ValidateNotNullOrEmpty()]
		[SecureString] $PassPhrase,

		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName ='ByPlainStr')]
		[ValidateNotNullOrEmpty()]
		[String] $PassPhrasePlain,

		[Parameter()]
		[int] $KeyByteSize = 16, 	    # AES-256 requires a 256-bit key

		[Parameter()]
		[int] $Iterations = 10000, 	    # Recommended: at least 10000 iterations

		[Parameter()]
		[byte[]] $Salt = $null,         # Salt size must be 8 bytes or larger, Default= 00000000

		[Parameter()]
		[byte[]] $IVBytes = $null
	)


    if ($PassPhrase)
    {
        $Key = Convert-PassPhraseToPBKDF2Key -PassPhrase $PassPhrase -KeyByteSize $KeyByteSize -Iterations $Iterations -Salt $Salt
    }
    else 
    {
        $Key = Convert-PassPhraseToPBKDF2Key -PassPhrasePlain $PassPhrasePlain -KeyByteSize $KeyByteSize -Iterations $Iterations -Salt $Salt
    }        
    return New-AesConverter -Type $Type -KeyBytes $Key -IVBytes $IVBytes
}
<##### Unit Test
$EnCryptor, $IVBytes = New-PassPhraseAesConverter -Type 'EnCryptor' -PassPhrasePlain 'TopSecret007' -ErrorAction Stop
$EnCryptor | Format-List
$EnCryptor.Dispose()

$DeCryptor = New-PassPhraseAesConverter -Type 'DeCryptor' -IVBytes $IVBytes -PassPhrasePlain 'TopSecret007' -ErrorAction Stop
$DeCryptor | Format-List
$DeCryptor.Dispose()
Exit
#>


<#
    Wrapper around the standard PowerShell encryption function: ConvertFrom-SecureString() which is an AES-256bit algorithm.
    We use an encryption key generated from a PassPhrase. 
    The user is prompted for a PassPhase if no PassPhrase argument was  provided.
    
	Set $UseDPAPI to bypass the PassPhase to key generation, i.e. we call ConvertFrom-SecureString() without a custom key.
    In this mode we encrypt using the windows Data Protection API (based on host & user password)
	Note: A secret encrypted with windows Data Protection API can only be decrypted by the same user
	      on the same host computer, and the user account password must not change.
    
    Note: We return $null if user cancelled operation by mot entering a PassPhrase
#>
function Encrypt-TextWithPassPhrase
{
 	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Scope='Function')]    
    [CmdletBinding(DefaultParameterSetName='AsText')]
    param (
        [Parameter(ValueFromPipeline, ParameterSetName= 'fromString')]
        [Alias('String')]
        [string] $PlainText = $null,

        [Parameter(ValueFromPipeline, ParameterSetName= 'fromSecureStr')]
        [SecureString] $SecureText = $null,

		[Parameter()]
		[SecureString] $PassPhrase = $null,		# Interactively prompt user when $null

		[Parameter()]
		[string] $PlainPassPhrase = $null,		# Interactively prompt user when $null

        [Parameter()]
        [string] $Prompt = 'Enter Password: ',

        [Parameter()]
        [ConsoleColor] $ForegroundColor = [ConsoleColor]::Gray,

		[Parameter()]
		[int] $Iterations = 10000,	# Recommended: at least 1000 iterations

		[Parameter()]
		[switch] $UseDPAPI			# Use windows Data Protection API (based on host & user password) instead of AES(PassPhrase), 
    )


	if ($PlainText)
	{
		$SecureText = ConvertTo-SecureString -String $PlainText -AsPlainText -Force
	}

	if ($UseDPAPI)
	{
		$CipherStr = ConvertFrom-SecureString -SecureString $SecureText	
	}
	else 
	{
        if (![string]::IsNullOrEmpty($PlainPassPhrase))
        {
            $PassPhrase = ConvertTo-SecureString -String $PlainPassPhrase -AsPlainText -Force
        }
		if (!$PassPhrase)
		{
            Write-Host $Prompt -ForegroundColor $ForegroundColor -NoNewline
			$PassPhrase = Read-host -AsSecureString
            if ([string]::IsNullOrWhiteSpace($PassPhrase))
            {
                return $null    # User cancelled operation
            }
		}
		$Key = Convert-PassPhraseToPBKDF2Key -PassPhrase $PassPhrase -Iterations $Iterations -KeyByteSize 32 # 16,24,32
		$CipherStr = ConvertFrom-SecureString -SecureString $SecureText -Key $Key
	}
	return $CipherStr 
}


<#
    Inverse to Encrypt-TextWithPassPhrase()
    Note: We return $null if user cancelled operation by mot entering a PassPhrase
#>
function Decrypt-TextWithPassPhrase
{
    [CmdletBinding()]
    param (
		[Parameter(ValueFromPipeline)]		
		[string] $CipherStr = $null,
		
		[Parameter()]
		[SecureString] $PassPhrase = $null,		# Interactively prompt user when $null

        [Parameter()]
        [string] $Prompt = 'Enter Password: ',

        [Parameter()]
        [ConsoleColor] $ForegroundColor = [ConsoleColor]::Gray,

		[Parameter()]
		[int] $Iterations = 10000,	# use 10000 iterations for PBKDF2

		[Parameter()]
		[switch] $UseDPAPI,			# Use windows Data Protection API (based on host & user password) instead of AES(PassPhrase), 

		[Parameter()]
		[switch] $ToPlainText		# Default output type is a SecureString
    )

	if ([string]::IsNullOrEmpty($CipherStr))
	{
		# Workaround empty or null SecureString conversion
		$SecureText = New-Object System.Security.SecureString
	}
	elseif ($UseDPAPI)
	{
		$SecureText = ConvertTo-SecureString -String $CipherStr -AsPlainText -Force
	}
	else 
	{
		if (!$PassPhrase)
		{
            Write-Host $Prompt -ForegroundColor $ForegroundColor -NoNewline
            $PassPhrase = Read-Host -AsSecureString
            if ($PassPhrase.Length -eq 0)
            {
                return $null    # User cancelled operation
            }
		}
		$Key = Convert-PassPhraseToPBKDF2Key -PassPhrase $PassPhrase -Iterations $Iterations -KeyByteSize 32 # 16,24,32
		$SecureText = ConvertTo-SecureString -String $CipherStr -Key $Key
	}

	if ($ToPlainText)
	{
		return (New-Object System.Net.NetworkCredential($null, $SecureText)).Password
	}
	return $SecureText
}
<##### Unit Test
$SecureFile = '.\MyEncrytpedSecret.txt'
'Hello Secret' | Encrypt-TextWithPassPhrase | Set-Content -Path $SecureFile -Encoding UTF8
Get-Content -Path $SecureFile -Encoding UTF8 | Decrypt-TextWithPassPhrase -ToPlainText
#>


function Encrypt-Secret
{
    [CmdletBinding()]
    [OutputType([byte[]],[string])]
    param (
        [Parameter(Mandatory)]
        $EnCryptor,             #[System.Security.Cryptography.CapiSymmetricAlgorithm]

        [Parameter(ValueFromPipeline, ParameterSetName= 'fromBytes')]
        [byte[]] $ByteS = $null,

        [Parameter(ValueFromPipeline, ParameterSetName= 'fromString')]
        [Alias('String')]
        [string] $PlainText = $null,

        [Parameter(ValueFromPipeline, ParameterSetName= 'fromSecureStr')]
        [SecureString] $SecureString = $null,

        [Parameter()]
        [byte[]] $IVPrefix = $null,

        [Parameter()]
        [string] $IVPrefixB64String = $null,

        [Parameter()]
        [switch] $AsBytes       # Base64String is default output type
    )


    if ($SecureString)
    {
        $PlainText = (New-Object System.Net.NetworkCredential($null, $SecureString)).Password
    }
    if ($PlainText)
    {
        $ByteS = [System.Text.Encoding]::Unicode.GetBytes($PlainText)
    }
    $CipherByteS = $EnCryptor.TransformFinalBlock($ByteS, 0, $ByteS.Length)

    if (![string]::IsNullOrEmpty($IVPrefixB64String))
    {
        $IVPrefix = [System.Convert]::FromBase64String($IVPrefixB64String)
    }
    if ($IVPrefix)
    {
        $CipherByteS = $IVPrefix + $CipherByteS
    }

    if ($AsBytes)
    {
        return $CipherByteS
    }
    return [Convert]::ToBase64String($CipherByteS)        
}


function Decrypt-Secret
{
    [CmdletBinding(DefaultParameterSetName='FromB64String')]
    [OutputType([SecureString],[string],[byte[]])]
    param (
        [Parameter(Mandatory)]
        $DeCryptor,             #[System.Security.Cryptography.CapiSymmetricAlgorithm]

        [Parameter(ParameterSetName="FromBytes")]
        [byte[]] $CipherByteS,

        [Parameter(ParameterSetName="FromB64String")]
        [string] $B64String,

        [Parameter()]
        [switch] $IncludesIV,

        [Parameter()]
        [ValidateSet(,'Base64String','SecureString', 'String','Bytes')]
        [string] $OutputType = 'Base64String'       
    )

    if (![string]::IsNullOrEmpty($B64String))
    {
        $CipherByteS = [System.Convert]::FromBase64String($B64String)
    }
    if (!$CipherByteS -or $CipherByteS.Length -eq 0)
    {
        return $null
    }

    if ($IncludesIV)
    {
        $DataByteS = $DeCryptor.TransformFinalBlock($CipherByteS, 16, $CipherByteS.Length - 16);
    }
    else 
    {
        $DataByteS = $DeCryptor.TransformFinalBlock($CipherByteS, 0, $CipherByteS.Length);
    }
     
    switch ($OutputType) 
    {
        'Base64String' {
            return [Convert]::ToBase64String($DataByteS)
        }
        'String' { 
            return [System.Text.Encoding]::Unicode.GetString($DataByteS) 
        }
        'SecureString' {
            return ConvertTo-SecureString -AsPlainText -Force -String ([System.Text.Encoding]::Unicode.GetString($DataByteS))
        }
        'Bytes' {
            return $DataByteS
        }
        Default {
            return $DataByteS
        }
    }
}
<##### Unit Test
$EnCryptor, $IVBytes = New-PassPhraseAesConverter -Type 'EnCryptor' -PassPhrasePlain '123' -ErrorAction Stop
$CipherStr = 'Hello World' | Encrypt-Secret -EnCryptor $EnCryptor #-IVPrefix $IVBytes
$EnCryptor.Dispose()

$DeCryptor = New-PassPhraseAesConverter -Type 'DeCryptor' -PassPhrasePlain '123' -IVBytes $IVBytes -ErrorAction Stop
$B64Str = Decrypt-Secret -DeCryptor $DeCryptor -B64String $CipherStr -OutputType Base64String
$PlainText = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($B64Str)) 
$PlainText

$DeCryptor = New-PassPhraseAesConverter -Type 'DeCryptor' -PassPhrasePlain '123' -IVBytes $IVBytes -ErrorAction Stop
$SecStr = Decrypt-Secret -DeCryptor $DeCryptor -B64String $CipherStr -OutputType SecureString
$PlainText = (New-Object System.Net.NetworkCredential($null, $SecStr)).Password
$PlainText

$DeCryptor = New-PassPhraseAesConverter -Type 'DeCryptor' -PassPhrasePlain '123' -IVBytes $IVBytes -ErrorAction Stop
$ByteS  = Decrypt-Secret -DeCryptor $DeCryptor -B64String $CipherStr -OutputType Bytes
$PlainText = [System.Text.Encoding]::Unicode.GetString($Bytes) 
$PlainText

$DeCryptor = New-PassPhraseAesConverter -Type 'DeCryptor' -PassPhrasePlain '123' -IVBytes $IVBytes -ErrorAction Stop
$PlainText = Decrypt-Secret -DeCryptor $DeCryptor -B64String $CipherStr -OutputType String
$PlainText

$DeCryptor.Dispose()
exit
#>


<#
.SYNOPSIS
  Returns the RSACryptoServiceProvider associated with a certificate.
  The cryptographic service provider has asymmetric encryption and decryption methods i.e. Encrypt(), Decrypt()
#>
function Get-CertCryptoProvider
{
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.RSACryptoServiceProvider])]
    param (
        [Parameter()]
        [String] $Thumbprint = $null,   # Equivalent to filename

        [Parameter()]
        [String] $Path = $null          # Speeds retrieval. e.g. 'Cert:\LocalMachine\My'
    )


    [array]$CertS = $null
    if ([string]::IsNullOrWhiteSpace($Path))
    {
        if ($Thumbprint)
        {
            $CertS = Get-ChildItem -Path 'Cert:\' -Recurse | Where-Object { $_.Thumbprint -eq $Thumbprint }
        }
    }
    else 
    {
        if ($Thumbprint)
        {
            $CertS = Get-ChildItem -Path $Path -Recurse | Where-Object { $_.Thumbprint -eq $Thumbprint }
        }
        else 
        {
            $CertS = Get-ChildItem -Path $Path
        }
    }

    if (!$CertS)
    {
        Throw 'Could not find the CrytpoServiceProvider-Certificate'
    }
    elseif ($CertS.Count -gt 1)
    {
        Throw 'Could not find unique CrytpoServiceProvider-Certificate'
    }

    return [System.Security.Cryptography.RSACryptoServiceProvider]$CertS[0].PrivateKey
}
<##### Unit Test
$CryptoProvider = Get-CertCryptoProvider -Path 'Cert:\LocalMachine\my\c82c81ba1eeb1a3c901940ba5bb492920346592b'
$CryptoProvider = Get-CertCryptoProvider -Path 'Cert:\LocalMachine\my' -Thumbprint 'c82c81ba1eeb1a3c901940ba5bb492920346592b'
#>

#endregion crypto utils

