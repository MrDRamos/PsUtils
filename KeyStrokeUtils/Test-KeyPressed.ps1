
<#
.Example
Test-KeyPressed -Keys @([system.consolekey]::Escape, [system.consolekey]::Enter)
#>
function Test-KeyPressed([array]$KeyS = @([system.consolekey]::Escape), [switch] $AnyKey)
{
    $Retval = $false
    if ($Host.Name -match 'ISE Host')
    {
        $KeyAvailable = $Host.UI.RawUI.KeyAvailable
    }
    else
    {
        $KeyAvailable = [System.Console]::KeyAvailable
    }
    if ($KeyAvailable)
    {
        $InpKey = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode;        
        if ($AnyKey -or $KeyS -ccontains $InpKey)
        {
            $Retval = $true
        }
    }
    return $Retval
}
