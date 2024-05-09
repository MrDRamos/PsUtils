<#
.SYNOPSIS
Converts an image file into an icon (*.ico) file.
The windows GDI+ supports the following file formats: BMP, GIF, EXIF, JPG, PNG, and TIFF.
https://learn.microsoft.com/en-us/dotnet/api/system.drawing.bitmap?view=net-8.0#remarks

.PARAMETER Path
Specifies the path to the input image file.

.PARAMETER Destination
Specifies the destination icon file if provided.
If a folder is specified instead of a file then the the input image filename specified by the Path parameter is used.
The default Destination is the users temp folder/

.PARAMETER Force
The default is to not overwrite an existing output icon file.
Specify -Force to overwrite the existing output icon file.

.PARAMETER PassThru
Returns the file path of the output icon file if set true,
Pops up the output icon file in the file explorer otherwise

.EXAMPLE
ConvertTo-Icon -Path $ENV:windir\ImmersiveControlPanel\images\Logo.png
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, ValueFromPipeline)]
    $Path,

    [Parameter()]
    $Destination = $env:temp,

    [Parameter()]
    [switch] $Force,

    [Parameter()]
    [switch] $PassThru
)


<#
.SYNOPSIS
Converts an image file into an icon (*.ico) file.
The windows GDI+ supports the following file formats: BMP, GIF, EXIF, JPG, PNG, and TIFF.
https://learn.microsoft.com/en-us/dotnet/api/system.drawing.bitmap?view=net-8.0#remarks

.PARAMETER Path
Specifies the path to the input image file.

.PARAMETER Destination
Specifies the destination icon file if provided.
If a folder is specified instead of a file then the the input image filename specified by the Path parameter is used.
The default Destination is the users temp folder/

.PARAMETER Force
The default is to not overwrite an existing output icon file.
Specify -Force to overwrite the existing output icon file.

.PARAMETER PassThru
Returns the file path of the output icon file if set true,
Pops up the output icon file in the file explorer otherwise

.EXAMPLE
ConvertTo-Icon -Path $ENV:windir\ImmersiveControlPanel\images\Logo.png
#>
function ConvertTo-Icon 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline)]
        $Path,

        [Parameter()]
        $Destination = $env:temp,

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $PassThru
    )

    if (!($Path -and (Test-Path $Path)))
    {
        Write-Warning "$Path does not exist"
        return
    }

    Add-Type -AssemblyName System.Drawing
    $Destination = $Destination.Trim()
    if ($Destination -notmatch '\.ico$')
    {
        $FileName = [IO.PATH]::GetFileNameWithoutExtension($Path) 
        $Destination += "\${FileName}.ico"
    }

    if (Test-Path $Destination)
    {
        if (!$Force)
        {
            Write-Host "Error: Specify -Force to overwrite the existing file: $Destination" -ForegroundColor Red
            return
        }
        Remove-Item $Destination
    }

    $img = [System.Drawing.Bitmap]::FromFile($Path)
    $img.Save($Destination,  [System.Drawing.Imaging.ImageFormat]::Icon)
    $img.Dispose()

    if ($PassThru)
    {
        return $Destination
    }
    & Explorer.exe "/SELECT,$Destination"
}

ConvertTo-Icon @PSBoundParameters
