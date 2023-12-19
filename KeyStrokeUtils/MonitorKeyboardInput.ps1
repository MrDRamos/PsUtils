Write-Host 'Press <ESC> key to exit ...' -NoNewline
for ($i = 0; $i -lt 1000; $i++) 
{
    Write-Host '.' -NoNewline
    if ([System.Console]::KeyAvailable)
    {
        #$InpKey = [system.console]::ReadKey().Key # always echo's key to console
        $InpKey = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode;
        if ($InpKey -eq [system.consolekey]::Escape)
        {
            Write-Host "Exiting loop"
            return
        }
    }
    Start-Sleep -Milliseconds 500
}