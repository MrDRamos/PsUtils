<#
.SYNOPSIS
The Registry hirachy structure is simular to directories & files.
Registry keys are like directories in that they can contain child keys.
A Registry keys can also contain named properties which are the analog 
to files. Each property can only store a single value. The most common
value types are DWORD(=int32() and String. see:
https://docs.microsoft.com/en-us/windows/win32/sysinfo/registry-value-types
One difference in the analogy is that a registry key can have an un-named
default property value.

Read-RegValue()
    This function retieves the value of a Registry key for the specified 
    PropertyName. It contains logic to workaround inconsistancies of the 
    native powershell Get-Item and Get-ItemProperty implementations.

Write-RegValue()
    This function overwrites the value of a Registry key for the specified 
    PropertyName. It contains logic to workaround inconsistancies of the 
    native powershell Set-ItemProperty implementation.

Get-RegPropertieS()
    Returns all the properties of a Registry key as Name/Value pairs as a 
    [Hashtable]

Search-RegPropValue()
    Inspects the specified registry key and all its child keys recursively.
    Returns a list of Registry key properties having a value matching the 
    ValueRegx regular expression.

Search-RegPropName()  
    Inspects the specified registry key and all its child keys recursively.
    Returns a list of Registry key properties having a name matching the 
    ValueRegx regular expression.

Get-RegKey()
    Ever wanted Get-Item() to accept a -Recurse switch when processing
    registry keys? Thats what this function does.
    First we return the Registry Key object returned by calling Get-Item().
    Then if the -Recurse switch is specified we additionally return the
    list of all the child keys by calling Get-ChildItem() -Recurse.

#>


<#
.SYNOPSIS
This function retieves the value of a Registry key for the specified 
PropertyName. It contains logic to workaround inconsistancies of the 
native powershell Get-Item and Get-ItemProperty implementations.

.PARAMETER Key
Various forms and types of key are accepted:
A qualified string path e.g: "HKLM:\SOFTWARE\Intel" or "Registry::HKCU\Software\Intel"
A incompletely qualified string path e.g: "HKEY_LOCAL_MACHINE\SOFTWARE\Intel"
  is interpreted as "Registy::HKEY_LOCAL_MACHINE\SOFTWARE\Intel"
A Key object returned by call to Get-Item

.PARAMETER Name
Specifies the name of the key property to retrieve.
Note: Every key has a default un-named property. Specify "", $null or
(default) to retrieve this default value.
#>
function Read-RegValue
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("Path")]
        $Key, 

        [Parameter()]
        [string] $Name = ""
    )
    
    if ($key -is [Microsoft.Win32.RegistryKey])
    {
        if ($Name -eq "(default)")
        {
            $Value = $key.GetValue("")
        }
        else 
        {
            $Value = $key.GetValue($Name)
        }
    }
    else 
    {        
        if (!(Split-Path -Path $Key -Qualifier -ErrorAction SilentlyContinue))
        {
            $Key = "Registry::$Key"
        }
        if ($Name)
        {
            $Value = (Get-ItemProperty -Path $Key -Name $Name).$Name
        }
        else 
        {
            $Value = (Get-Item -Path $Key).GetValue($null)
        }            
    }
    return $Value
}


<#
.SYNOPSIS
This function overwrites the value of a Registry key for the specified 
PropertyName. It contains logic to workaround inconsistancies of the 
native powershell Set-ItemProperty implementation.

.PARAMETER Key
Various forms and types of key are accepted:
A qualified string path e.g: "HKLM:\SOFTWARE\Intel" or "Registry::HKCU\Software\Intel"
A incompletely qualified string path e.g: "HKEY_LOCAL_MACHINE\SOFTWARE\Intel"
  is interpreted as "Registy::HKEY_LOCAL_MACHINE\SOFTWARE\Intel"
A Key object returned by call to Get-Item

.PARAMETER Name
Specifies the name of the key property to modify.
Note: Every key has a default un-named property. Specify "", $null or
(default) to modify this default value.

.PARAMETER Value
The new  data value to write. 
Two data types have been tested: [string] and [int]
An [int] value is mapped to a registry DWORD type.

.PARAMETER Force
Use the Force switch to create a new Key(and sub keys) if it does not exist yet.
#>
function Write-RegValue
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("Path")]
        $Key, 

        [Parameter()]
        [string] $Name = "",

        [Parameter()]
        [string] $Value,

        [Parameter()]
        [switch] $Force
    )

    if (!$Name)
    {
        $Name = "(default)"
    }

    if ($key -is [Microsoft.Win32.RegistryKey])
    {
        $KeyPath = $Key.PsPath
    }
    else 
    {
        if (Split-Path -Path $Key -Qualifier -ErrorAction SilentlyContinue)
        {
            $KeyPath = $Key
        }
        else
        {
            $KeyPath = "Registry::$Key"
        }
    }

    $RegKey = Get-Item -Path $KeyPath -ErrorAction Ignore
    if ($RegKey)
    {
        Set-ItemProperty -Path $KeyPath -Name $Name -Value $Value
    }
    else
    {
        if ($Force)
        {
            $null = New-Item -Path $KeyPath -Force:$Force
        }
        $null = New-ItemProperty -Path $KeyPath -Name $Name -Value $Value
    }
}


<#
.SYNOPSIS
Returns all the properties of a Registry key as Name/Value pairs as a 
[Hashtable]
#>
function Get-RegPropertieS
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("Path")]
        $Key
    )

    $PropertieS = [ordered] @{}
    if ($key -is [Microsoft.Win32.RegistryKey])
    {
        foreach ($PropName in $Key.Property)
        {
            if ($PropName -eq "(default)")
            {
                $Value = $key.GetValue("")
            }
            else 
            {
                $Value = $key.GetValue($PropName)
            }
            $PropertieS.Add($PropName, $Value)
        }    
    }
    else 
    {
        if (!(Split-Path -Path $Key -Qualifier -ErrorAction SilentlyContinue))
        {
            $Key = "Registry::$Key"
        }
        foreach ($PropName in (Get-Item -Path $Key).Property)
        {
            $Value = (Get-ItemProperty -Path $Key -Name $PropName).$PropName
            $PropertieS.Add($PropName, $Value)
        }
    }
    return $PropertieS
}


<#
.SYNOPSIS
Inspects the specified registry key and all its child keys recursively.
Returns a list of Registry key properties having a value matching the 
ValueRegx regular expression.
The returns list of objects have the following properties
    Key     RegistryKey object
    Name    The property name
    Value   The data value that matched the regular expression
#>
function Search-RegPropValue
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("Path")]
        $Key, 

        [Parameter()]
        [string] $ValueRegx,

        [Parameter()]
        [switch] $Recurse
    )

    [array] $RegValMatcheS = $null
    [array] $ChildKeyS = $null
    if ($Key -is [Microsoft.Win32.RegistryKey])
    {
        $ChildKeyS += $Key
    }
    else 
    {
        if (!(Split-Path -Path $Key -Qualifier -ErrorAction SilentlyContinue))
        {
            $Key = "Registry::$Key"
        }
        $ChildKeyS += Get-Item -Path $Key
    }

    $ChildKeyS += Get-ChildItem -Path $Key -Recurse:$Recurse
    foreach ($ChildKey in $ChildKeyS)
    {
        $PropertieS = Get-RegPropertieS -Key $ChildKey
        foreach ($Prop in $PropertieS.GetEnumerator())
        {
            if ($Prop.Value -match $ValueRegx)
            {
                $RegMatch = [PSCustomObject]@{
                    Key = $ChildKey
                    Name = $Prop.Key
                    Value = $Prop.Value
                }
                $RegValMatcheS += $RegMatch
            }
        }
    }
    return $RegValMatcheS    
}


<#
.SYNOPSIS
Inspects the specified registry key and all its child keys recursively.
Returns a list of Registry key properties having a name matching the 
ValueRegx regular expression.
The returned list of objects have the following properties
    Key     RegistryKey object
    Name    The property name that matched the regular expression
    Value   The data value
#>
function Search-RegPropName
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("Path")]
        $Key, 

        [Parameter()]
        [string] $NameRegx,

        [Parameter()]
        [switch] $Recurse
    )

    [array] $RegValMatcheS = $null
    [array] $ChildKeyS = $null
    if ($Key -is [Microsoft.Win32.RegistryKey])
    {
        $ChildKeyS += $Key
    }
    else 
    {
        if (!(Split-Path -Path $Key -Qualifier -ErrorAction SilentlyContinue))
        {
            $Key = "Registry::$Key"
        }
        $ChildKeyS += Get-Item -Path $Key
    }

    $ChildKeyS += Get-ChildItem -Path $Key -Recurse:$Recurse
    foreach ($ChildKey in $ChildKeyS)
    {
        $PropertieS = Get-RegPropertieS -Key $ChildKey
        foreach ($Prop in $PropertieS.GetEnumerator())
        {
            if ($Prop.Key -match $NameRegx)
            {
                $RegMatch = [PSCustomObject]@{
                    Key = $ChildKey
                    Name = $Prop.Key
                    Value = $Prop.Value
                }
                $RegValMatcheS += $RegMatch
            }
        }
    }
    return $RegValMatcheS    
}


<#
.SYNOPSIS
Ever wanted Get-Item() to accept a -Recurse switch when processing
registry keys? Thats what this function does.
First we return the Registry Key object returned by calling Get-Item().
Then if the -Recurse switch is specified we additionally return the
list of all the child keys by calling Get-ChildItem() -Recurse.

.PARAMETER Path
One or more parent Registry paths, also accepted via pipeline input.
Various forms and types of registry key-paths are accepted:
A qualified string path e.g: "HKLM:\SOFTWARE\Intel" or "Registry::HKCU\Software\Intel"
A incompletely qualified string path e.g: "HKEY_LOCAL_MACHINE\SOFTWARE\Intel"
  is interpreted as "Registy::HKEY_LOCAL_MACHINE\SOFTWARE\Intel"
We return a RegistryKey for each parent path by calling Get-Item. 

.PARAMETER Recurse
If specified then we call Get-ChildItem -Recurse to return the list
of all the child keys. If multiple parent paths are specified then
we call Get-ChildItem for each of them.

.PARAMETER Depth
Determines the number of child key levels to include in the recursion

.EXAMPLE
List all 'Edge' keys recursively, and output their property names & values:
Get-RegKey -Path "HKCU:\Software\Microsoft\Edge" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Output $_.Name
    foreach ($Name in $_.GetValueNames()) 
    {
        Write-Output "    $Name = $($_.GetValue($Name))"
    }
}
#>
function Get-RegKey
{
    [OutputType([Microsoft.Win32.RegistryKey],[array])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias("Key")]
        $Path, 

        [Parameter(Position = 1)]
        [switch] $Recurse,

        [Parameter(Position = 2)]
        [int] $Depth = -1
    )

    foreach ($PathI in $Path)
    {
        if ($PathI -is [Microsoft.Win32.RegistryKey])
        {
            $Key = $PathI
        }
        else
        {
            if (!(Split-Path -Path $PathI -Qualifier -ErrorAction SilentlyContinue))
            {
                $PathI = "Registry::$PathI"
            }
            $Key = Get-Item -Path $PathI -ErrorAction SilentlyContinue
        }

        if ($Key)
        {
            Write-Output $Key
            if ($Recurse)
            {
                if ($Depth -ge 0)
                {
                    Get-ChildItem -Path $Key.PsPath -Recurse -Depth $Depth
                }
                else 
                {
                    Get-ChildItem -Path $Key.PsPath -Recurse
                }
            }
        }
    }
}
