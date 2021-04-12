#Input Parameters
$WallixUsr = "walix-doamin\username"
$WallixPwd = "xxx"
$JmpBoxUsr = "aws-domain\username"
$JmpBoxPwd = "xxx"
$WallixRdpFile = Resolve-Path "$PSScriptRoot\AwsWallix.rdp"

$ErrorActionPreference = "Stop"


<#
  Alternative Send-AppKeys() implementation that does NOT depend on any external Assemblies
#>
function Send-AppKeys_v1 
{
    param (
        [string] $Keys,
        [string] $WinTitle,
        [int] $WaitForTitle = 1000,
        [int] $WaitForKeys = 1000
    )
    
    $wshell = New-Object -ComObject wscript.shell;
    IF ($WinTitle) 
    {
        $IsActivated = $wshell.AppActivate($WinTitle)
        if (!$IsActivated)
        {
            return    
        }
        Start-Sleep -Milliseconds $WaitForTitle
    }
    IF ($Keys) 
    {
        $wshell.SendKeys($Keys) #, $WaitForKeys)
    }
}


<#
  Alternative Send-AppKeys() implementation that depends on 2 external Assemblies:
    [Microsoft.VisualBasic.Interaction]
    [System.Windows.Forms.SendKeys]
Ref: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-powershell-1.0/ff731008(v=technet.10)?redirectedfrom=MSDN
#>
Function Send-AppKeys_v2
{
    param (
        [string] $Keys,
        [string] $WinTitle,
        [int] $WaitForTitle = 1000,
        [switch] $WaitForKeys
    )

    IF ($WinTitle) 
    {
        # Give the focus to the windows application having $WinTitle in its title-bar
        # load .Net Framework class: Microsoft.VisualBasic
        # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-type?view=powershell-7
        add-type -AssemblyName "Microsoft.VisualBasic"
        try 
        {
            [Microsoft.VisualBasic.Interaction]::AppActivate($WinTitle)    
        }
        catch 
        {
            return
        }
        Start-Sleep -Milliseconds $WaitForTitle
    }
    IF ($Keys) 
    {
        # load .Net Framework class: System.Windows.Forms
        add-type -AssemblyName "System.Windows.Forms"
        if ($WaitForKeys)
        {
            [System.Windows.Forms.SendKeys]::SendWait($Keys)   
        }
        else 
        {
            [System.Windows.Forms.SendKeys]::Send($Keys)    
        }        
    } 
}


<#
 Private helper for Send-AppKeys() & Wait-ForWindow()
 Ensures that the Assembly: [Microsoft.VisualBasic] is loaded
#>
Function Initialize_AppInterAction()
{
    $AssemblyLoaded = $false
    try 
    {
        $AssemblyLoaded = [reflection.assembly]::GetAssembly([Microsoft.VisualBasic.Interaction])
    }
    catch { }
    if (!$AssemblyLoaded)
    {
        # load .Net Framework class: Microsoft.VisualBasic
        # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-type?view=powershell-7
        Add-Type -AssemblyName "Microsoft.VisualBasic"

        # Workaround issue where SendKeys() failes the first time its invoked
        $MyKeyboard = New-Object -TypeName "Microsoft.VisualBasic.Devices.Keyboard"
        $MyKeyboard.SendKeys("", $false)
    }
}


<#
Send-AppKeys() implementation that depends on 1 external Assembly:
    [Microsoft.VisualBasic.Interaction]
Ref: https://docs.microsoft.com/en-us/previous-versions/office/developer/office-xp/aa202943(v=office.10)?redirectedfrom=MSDN

The Keys argument can specify any single key or any key combined with ALT, CTRL, or SHIFT (or any combination of those keys). 
Each key is represented by one or more characters, such as "a" for the character a, or "{ENTER}" for the ENTER key.
To specify characters that aren't displayed when you press the corresponding key (for example, ENTER or TAB), 
use the codes listed in the following table. Each code in the table represents one key on the keyboard.

Key             Key-Code
--------------- -------------------
BACKSPACE	    {BACKSPACE} or {BS}
BREAK	        {BREAK}
CAPS LOCK	    {CAPSLOCK}
CLEAR	        {CLEAR}
DELETE or DEL	{DELETE} or {DEL}
DOWN ARROW	    {DOWN}
END	            {END}
ENTER (#keypad)	{ENTER}
ENTER	        ~ (tilde)
ESC	            {ESCAPE} or {ESC}
HELP	        {HELP}
HOME	        {HOME}
INS	            {INSERT}
LEFT ARROW	    {LEFT}
NUM LOCK	    {NUMLOCK}
PAGE DOWN	    {PGDN}
PAGE UP	        {PGUP}
RETURN	        {RETURN}
RIGHT ARROW	    {RIGHT}
SCROLL LOCK	    {SCROLLLOCK}
TAB	            {TAB}
UP ARROW	    {UP}
F1 through F15	{F1} through {F15}
Keypad add      {ADD}
Keypad subtract {SUBTRACT}
Keypad multiply {MULTIPLY}
Keypad divide   {DIVIDE}

You can also specify keys combined with SHIFT and/or CTRL and/or ALT. 
To specify a key combined with another key or keys, use the following table.

Key             Key-Code
--------------- -------------------
SHIFT	        + (plus sign)
CTRL	        ^ (caret)
ALT             % (percent sign)

#>
Function Send-AppKeys
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $Keys,

        [Parameter(Mandatory = $true, ParameterSetName = "ByAppProcess")]
        [ValidateNotNull()]
        [System.Diagnostics.Process] $Process,

        [Parameter(Mandatory = $true, ParameterSetName = "ByAppTitle")]
        [ValidateNotNullOrEmpty()]
        [string] $WinTitle,

        [Parameter()]
        [switch] $DontWaitForKeys
    )

    IF ($WinTitle)
    {
        $WinShowOk = Show-Window -WinTitle $WinTitle -WindowState SW_Normal -PassThru
    }
    else 
    {
        $WinShowOk = Show-Window -Process $Process -WindowState SW_Normal -PassThru
        if ($WinShowOk)
        {            
            $WinTitle = $Process.MainWindowTitle
        }        
    }
    if (!$WinShowOk)
    {
        Throw "In Send-AppKeys(): Failed to activate target application window"
    }
    Wait-ForWindow -WinTitle $WinTitle

    IF ($Keys) 
    {
        Initialize_AppInterAction
        # https://docs.microsoft.com/en-us/dotnet/api/microsoft.visualbasic.devices.keyboard?view=netframework-4.8
        $MyKeyboard = New-Object -TypeName "Microsoft.VisualBasic.Devices.Keyboard"
        $MyKeyboard.SendKeys($Keys, !$DontWaitForKeys)
    }
}




<#
  Returns one or more Processes that have a window with the title matching WinTitle
#>
Function Get-ProcessByWindowTitle
{
    [outputType([System.Diagnostics.Process])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $WinTitle
    )

    [array] $Process = Get-Process | Where-Object {$_.MainWindowTItle -match $WinTitle}
    return $Process
}


Enum WindowState
{
    SW_Hide = 0
    SW_Normal = 1
    SW_Minimized = 2
    SW_Maximized = 3
    SW_ShowNoActivateRecentPosition = 4
    SW_Show = 5
    SW_MinimizeActivateNext = 6
    SW_MinimizeNoActivate = 7
    SW_ShowNoActivate = 8
    SW_Restore = 9
    SW_ShowDefault = 10
    SW_ForceMinimize = 11
}
<#
Calls the native Win32 API ShowWindow(WindowHandle, WindowState)
Ref: https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showwindow

The caller can pass either the Windows title or a handle to the Window Process
#>
Function Show-Window
{
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "ByAppProcess")]
        [ValidateNotNull()]
        [System.Diagnostics.Process] $Process,

        [Parameter(Mandatory = $true, ParameterSetName = "ByAppTitle")]
        [ValidateNotNullOrEmpty()]
        [string] $WinTitle,

        [Parameter()]
        [WindowState]$WindowState = [WindowState]::SW_Show,

        [Parameter()]
        [switch] $PassThru
    )

    if ($WinTitle)
    {
        [array] $Process = Get-Process | Where-Object {$_.MainWindowTItle -match $WinTitle}
        if ($Process)
        {
            $Process = $Process[0]
        }
        else
        {
            Write-Error "In Show-Window(): No process found with WinTitle: '$WinTitle'"
        }    
    }
    if ($Process)
    {
        $PInvokeFuncDef = @"
        [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")] public static extern IntPtr FindWindow(string className, string windowTitle);
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr  hWnd);
"@
        Add-Type -MemberDefinition $PInvokeFuncDef -name WindowFunc -namespace Win32

        $hwnd = $Process.MainWindowHandle
        if ($hwnd -ne 0)
        {
            $Retval = [Win32.WindowFunc]::ShowWindow($hwnd, $WindowState)
        }
        else 
        {
            Write-Error "In Show-Window(): Process MainWindowHandle not found"
        }
    }
    else 
    {
        Write-Error "In Show-Window(): No Process specified"
    }
    if ($PassThru)
    {
        return $Retval
    }
}


<#
  Activates a background window so that its on top and ready for user input
#>
Function Wait-ForWindow
{
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "ByAppProcess")]
        [ValidateNotNull()]
        [System.Diagnostics.Process] $Process,

        [Parameter(Mandatory = $true, ParameterSetName = "ByAppTitle")]
        [ValidateNotNullOrEmpty()]
        [string] $WinTitle,

        [int] $TimeoutSec = 2
    )

    if ($Process)
    {
        $WinTitle = $Process.MainWindowTitle
    }

    Initialize_AppInterAction
    $IsShowing = $false
    $EndTime = (Get-Date).AddSeconds($TimeoutSec)
    if ($VerbosePreference)
    {
        Write-Host "Activating: $WinTitle"
    }
    do {
        try 
        {
            [Microsoft.VisualBasic.Interaction]::AppActivate($WinTitle)
            $IsShowing = $true
        }
        catch 
        {
            Start-Sleep -Milliseconds 1000
            if ($VerbosePreference)
            {
                Write-Host "." -NoNewline
            }
        }
        $NowTime = Get-Date
    } until ($IsShowing -or ($EndTime -lt $NowTime))
    if (!$IsShowing)
    {
        Write-Host "Failed to activate: $WinTitle" -ForegroundColor Red
        Exit 1
    }
}


<#
.SYNOPSIS
Make sure CISCO VPN is connected to OLF.COM
#>
Function Connect-CiscoVPN
{
    # 0) There is nothing to do if we are already connected to the olf.com domain
    if ((Get-DnsClientGlobalSetting).SuffixSearchList -contains "olf.com")
    {
        return
    }

    # 1st make sure the Cisco app is up and running ...
    $CiscoExe = $null
    $CiscoApp = Get-Process "vpnui" -ErrorAction Ignore
    if ($CiscoApp)
    {
        $CiscoNet = Get-NetAdapter | Where-Object { $_.DriverDescription -match "Cisco" }
        if (!$CiscoNet -or ($CiscoNet.MediaConnectionState -ne "Connected"))
        {
            if ($CiscoApp.MainWindowTItle -eq "")
            {
                # The app is running minimized in the tray, Bur without a window handle by which it can be activated
                $CiscoApp.Kill();
                $CiscoApp = $null
            }
            else 
            {
                $CiscoExe = $CiscoApp.Path
                Write-Host "Activating $($CiscoApp.Path)"
            }
        }    
    }
    if (!$CiscoApp)
    {
        $DirProp = Get-ItemProperty -path  "HKLM:\SOftware\WOW6432Node\Cisco\Cisco AnyConnect Secure Mobility Client" -Name InstallPathWithSlash -ErrorAction Ignore
        if (!$DirProp)
        {
            Write-Host "Cisco VPN client is not installed" -ForegroundColor Red
            Exit 1    
        }
        $CiscoExe = "$($DirProp.InstallPathWithSlash)\vpnui.exe"
    }
    if ($CiscoExe)
    {
        if (!$CiscoApp)
        {
            Write-Host "Starting: $CiscoExe"
            $CiscoApp = Start-Process $CiscoExe -PassThru
            Start-Sleep -Seconds 2
        }        
        Send-AppKeys -Process $CiscoApp -Keys "~" # <Enter>
        #Show-Window -Process $CiscoApp -WindowState SW_Minimized
        Write-Host "Select this window and Press <ENTER> after MFA callback has completed" -ForegroundColor Yellow
        [void] (Read-Host)
    }

    # 2nd make sure the Cisco app is connected
    $CiscoNet = Get-NetAdapter | Where-Object { $_.DriverDescription -match "Cisco" }
    if (!$CiscoNet -or ($CiscoNet.Status -eq "Disabled"))
    {
        Write-Host "Try again after starting Cisco VPN" -ForegroundColor Red
        Exit 1
    }
    if (!((Get-DnsClientGlobalSetting).SuffixSearchList -contains "olf.com"))
    {
        Write-Host "The Cisco connection is not joined to OLF.COM domain" -ForegroundColor Red
        Exit 1
    }  
}




<#
#######################################################################################################################
                                                    MAIN()
#######################################################################################################################
#>

# Make sure CISCO VPN is connected to OLF.COM
Connect-CiscoVPN
$WalixProcess =  Get-ProcessByWindowTitle -WinTitle "AwsWallix"
if ($WalixProcess)
{
    $WalixProcess.Kill()
}
# Start Wallix RDP session
Write-Host "Please don't switch focus from the Walix window ..."
$WalixProcess = Start-Process -FilePath mstsc.exe -ArgumentList $WallixRdpFile -PassThru
Start-Sleep 3

# Wallix Login
Send-AppKeys -Process $WalixProcess -Keys "$WallixUsr`{TAB}"
Send-AppKeys -Process $WalixProcess -Keys "$WallixPwd`~"

# Wait for MFA phone call
Show-Window -Process $WalixProcess -WindowState SW_Minimized
Write-Host "Use your phone to confirm MFA callback ..."
Write-Host "Select this window and Press <ENTER> after MFA callback has completed" -ForegroundColor Yellow
Start-Sleep 10
[void] (Read-Host)
Show-Window -Process $WalixProcess -WindowState SW_Normal

# Select US JumpBox (=last entry in list)
Send-AppKeys -Process $WalixProcess -Keys "{END}~"

# ACK ION message screeen
Start-Sleep -Seconds 1
Send-AppKeys -Process $WalixProcess -Keys "~"

# Login to JumpBox
Start-Sleep -Seconds 1
Send-AppKeys -Process $WalixProcess -Keys "$JmpBoxUsr`{TAB}"
Send-AppKeys -Process $WalixProcess -Keys "$JmpBoxPwd`~"

Write-Host "Completed Aws RDP connection." -ForegroundColor Green
