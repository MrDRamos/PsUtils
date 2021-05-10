<#
.SYNOPSIS
Returns 2 integers(n,d) who's ratio R=n/d is close to the input value $X
The function traverses a Stern–Brocot tree to find the 2 factors 
of a Rational number $R such that |R-X| < $MaxError.

.PARAMETER X
The target value to aproxiamate

.PARAMETER MaxError
The desired precision. Default = 1e-6

.EXAMPLE
.\Get-RationalFactors.ps1 -x 3.14 -MaxError 1E-2
22
7

.EXAMPLE
Get-RationalFactors -x 3.14159265359 -MaxError 1E-6 -Verbose
...
VERBOSE: 3.14159292035398    2.667640e-007
355
113

.EXAMPLE
.\Get-RationalFactors.ps1 -x ([math]::e) -MaxError 1E-6
2721
1001
#>
[CmdletBinding()]
param (
    [double]$X,

    [double]$MaxError = 1e-6
)


function Get-RationalFactors
{
    [CmdletBinding()]
    param (
        [double]$X,

        [double]$MaxError = 1e-6
    )

    if ($MaxError -le 0)
    {
      throw [System.ArgumentException]"Get-RationalFactors: MaxError argument must be greater than 0"
    }
    [bool]$Neg = $X -lt 0
    if ($Neg)
    {
        $X = -$X
    }

    # Init Lower ratio
    [int]$Lx = 1    # Numerator
    [int]$Ly = 0    # Denominator

    # Init Higher ratio
    [int]$Hx = 0    # Numerator
    [int]$Hy = 1    # Denominator

    # Compute the Mediant in vector space (x=Numerator, y=Denominator)
    [int]$Mx = $Hx + $Lx
    [int]$My = $Hy + $Ly

    # Compute the Error = ComputetValue - TargetValue
    [double]$Tan = $My / $Mx
    $Err = $Tan - $X
    Write-Verbose ("{0,-18}  {1,-18:e}" -f $Tan, $Err)

    while ($MaxError -lt [math]::Abs($Err)) 
    {
        if (0 -lt $Err)
        {
            $Hy = $My
            $Hx = $Mx
        }
        else 
        {
            $Ly = $My
            $Lx = $Mx  
        }

        # Compute the Mediant
        [int]$Mx = $Hx + $Lx
        [int]$My = $Hy + $Ly

        # Compute the error 
        [double]$Tan = $My / $Mx
        $Err = $Tan - $X
        Write-Verbose ("{0,-18}  {1,-18:e}" -f $Tan, $Err)        
    }

    if ($Neg)
    {
        return @(-$My, $Mx)  
    }            
    return @($My, $Mx)
}

Get-RationalFactors -X $X -MaxError $MaxError
