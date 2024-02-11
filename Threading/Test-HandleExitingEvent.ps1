

# Example: Test-KeyPressed -Keys @([system.consolekey]::Z, [system.consolekey]::Enter)
function Test-KeyPressed([array]$KeyS = @([system.consolekey]::Escape), [switch] $AnyKey)
{
    $Retval = $false
    if ([System.Console]::KeyAvailable)
    {
        $InpKey = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode;        
        if ($AnyKey -or $KeyS -ccontains $InpKey)
        {
            $Retval = $true
        }
    }
    return $Retval
}


function Write-Log($Message, [switch]$NoNewline, $ForegroundColor = 'Gray')
{
    $Message | Add-Content -Path "Test-HandleExitingEvent.log" -NoNewline:$NoNewline
    Write-Host $Message -NoNewline:$NoNewline -ForegroundColor:$ForegroundColor
}


$FinalizeFlag = 0   # Is set to 1 by first caller to OnAbortScript()
function Global:OnAbortScript([string] $Reason = '')
{
    Write-Log "In OnAbortScript() because: $Reason" -ForegroundColor Red
    # Avoid race conditions when calling this function
    if ([Threading.Interlocked]::CompareExchange([ref]$FinalizeFlag, -1<#NewVal#>, 0<#TestVal#>) -eq 0<#OldVal#>)
    {
        try 
        {
            Write-Log "  OnAbortScript() starting graceful shutdown in 3 seconds ..." -ForegroundColor Magenta
            # ... Add code to release resources
            Start-Sleep -Seconds 3
            Write-Log "  OnAbortScript() finished graceful shutdown" -ForegroundColor Magenta
        }
        catch 
        {
            Write-Log ('Fatal exception in OnAbortScript(): ' + $_.Exception.Message) -ForegroundColor Red
        }
        finally
        {
            Get-EventSubscriber -SourceIdentifier 'PowerShell.Exiting' -Force -ErrorAction Ignore | Unregister-Event
        }

        # Terminate this Powershell session
        #Exit 1 # May not kill the Main Powershell session

        # Hard Terminate this process even if other threads are running
        #[Environment]::Exit(1) 
    }
}


###### Main ######
#
# 'PowerShell.Exiting' event is called when the PowerShell engine is exiting.
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/register-engineevent?view=powershell-7.4
# PSEngineEvent Class: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.psengineevent?view=powershellsdk-7.3.0
# 
# See Console API Function: GenerateConsoleCtrlEvent()
# https://learn.microsoft.com/en-us/windows/console/generateconsolectrlevent
#
#

<#
# PowerShell function to send Ctrl-C to 

$MemberDefinition = '
    [DllImport("kernel32.dll")]public static extern bool FreeConsole();
    [DllImport("kernel32.dll")]public static extern bool AttachConsole(uint p);
    [DllImport("kernel32.dll")]public static extern bool GenerateConsoleCtrlEvent(uint e, uint p);
    public static void SendCtrlC(uint p) {
        FreeConsole();
        AttachConsole(p);
        GenerateConsoleCtrlEvent(0, p);
        //FreeConsole();
        //AttachConsole(uint.MaxValue);
    }'
Add-Type -Name 'dummyName' -Namespace 'dummyNamespace' -MemberDefinition $MemberDefinition

function Send-CtrlC([int] $ProcessID)
{
    [dummyNamespace.dummyName]::SendCtrlC($ProcessID) 
}
#>


$MaxRunTimeSec = 30
Write-Log "Started Test-HandleExitingEvnet.ps1 - Program ID: $Pid"
Write-Log "Command to test this program in seperate PowerShell process:"
Write-Log "  rm .\Test-HandleExitingEvent.log; Start-Process -FilePath powershell -ArgumentList '-NoProfile','-File .\Test-HandleExitingEvent.ps1' -wait; cat .\Test-HandleExitingEvent.log"
Write-Log "Process loop will exit after: $MaxRunTimeSec seconds"
Write-Log 'Or press <Z> key to exit normally'
Write-Log 'Or press <Ctrl>C key to gracefully stop PowerShell & trigger the "PowerShell.Exiting" event handler'

Get-EventSubscriber -SourceIdentifier 'PowerShell.Exiting' -ErrorAction Ignore | Unregister-Event
$null = Register-EngineEvent -SourceIdentifier 'PowerShell.Exiting' -Action { OnAbortScript -Reason 'PowerShell.Exiting Event' }

$EndTime = (Get-Date).AddSeconds($MaxRunTimeSec)
$ExitLoop = $false
do
{
    Write-Log "." -NoNewline
    Start-Sleep -Milliseconds 500
    if (Test-KeyPressed -KeyS @([system.consolekey]::Z))
    {
        Write-Log ' The <Z> key was pressed'
        $ExitLoop = $true
    }
    if ($EndTime -lt (Get-Date))
    {
        Write-Log " MaxRunTimeSec: $MaxRunTimeSec expired"
        $ExitLoop = $true
    }
} until ($ExitLoop)

#Get-EventSubscriber -SourceIdentifier 'PowerShell.Exiting' -Force -ErrorAction Ignore | Unregister-Event
#OnAbortScript -Reason "Normal ShutDown"
Write-Log 'Closing in 2 seconds ...'
Start-Sleep -Seconds 2
