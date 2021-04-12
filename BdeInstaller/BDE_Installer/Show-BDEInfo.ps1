$ErrorActionPreference = "Stop"

# Include powrshell library with DBE functions
. "$PSScriptRoot\libs\BdeUtils.ps1"

Get-BdeInfo | Format-List
