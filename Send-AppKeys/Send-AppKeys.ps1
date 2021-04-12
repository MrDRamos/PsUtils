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



<########## Example ##########
$Proc = Get-Process "Notepad"
if (!$Proc)
{
    & notepad.exe
    Start-Sleep -Seconds 1 # wait for app to start    
}

Send-AppKeys -WinTitle "Untitled - Notepad" -Keys "Hello{ENTER}"
Send-AppKeys -Process $Proc -Keys "World~"
#>

