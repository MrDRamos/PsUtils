#region Mutex

<#
.Parameter Name
Note: The allowed characters for the mutex name are restricted (similar to file names).
The Name should not contain back '\' characters.

.Parameter MaxWaitMiliSec
The maximum amount of time to wait for an other process to release the mutex.
Default = 0. Set to -1 to wait indefinitely

.Parameter Scope
Use Global\ scope to make the mutex name visible to all system processes
Use Local\ scope, which limits the visibility to the logon session
#>
function New-MutexSingleton
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [int] $MaxWaitMilliSec = 0,

        [Parameter()]
        [ValidateSet('Global', 'Local')]
        [string] $Scope = 'Global'
    )
    
    $Mutex = $null
    try 
    {
        $Name = $Scope + '\' + $Name.Replace('\', '/')
        try 
        {           
            #[bool] $IsNewMutex = $true
            #$Mutex = New-Object System.Threading.Mutex($false, $Name, [ref] $IsNewMutex)
            #if (!$IsNewMutex -or !($Mutex.WaitOne($MaxWaitMilliSec)))
            $Mutex = New-Object System.Threading.Mutex($false, $Name)
            if (!($Mutex.WaitOne($MaxWaitMilliSec)))
            {
                $Mutex.Dispose()
                $Mutex = $null
            }
        }
        catch [System.Threading.AbandonedMutexException]
        {
            # When a thread/process abandons a mutex, the exception is thrown in the next thread/process that acquires the mutex
            Write-Host "Acquired abandoned mutex: $Name; $($_.Exception.Message)"
            $Mutex = $_.Exception.Mutex
            if ($Mutex)
            {
                if (!($Mutex.WaitOne(0)))
                {
                    $Mutex.Dispose()
                    $Mutex = $null
                }    
            }
        }
        catch 
        {
            $Mutex = $null
            Write-Host "Failed to create mutex: $Name; $($_.Exception.Message)"
        }
    }
    catch {

    }
    return $Mutex        
}


# Release the singleton app mutex
# A mutex is flagged as abandoned if the app/thread exits without releasing it.
# Beginning in version 2.0 of the .NET Framework, an AbandonedMutexException is thrown in the next thread that acquires the mutex!
function Clear-MutexSingleton
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object] $Mutex
    )

    if ($Mutex)
    {
        try 
        {
            $Mutex.ReleaseMutex()
        }
        catch 
        {
            Write-Host $_.Exception.Message
        }
        finally 
        {
            $Mutex.Dispose()
        }
    }    
}

#endregion Mutex


#### Main ####

# Acquire the singleton application mutex
$AppName = 'MyAppName'
$Script:AppMutex = New-MutexSingleton -Name $AppName
if (!$AppMutex)
{
    Throw "Failed to start $AppName because an other instance is already running"
}


# ... App code
Write-Host "Running $AppName Pid= $PID"
$UsrInp = Read-Host "Press enter to continue ..."
if ($UsrInp -eq 'e')
{
    if (!($AppMutex.WaitOne($MaxWaitMilliSec)))
    {
        Write-Host "WaitOne()" -ForegroundColor Magenta
        $Mutex.Dispose()
        Write-Host "Dispose()" -ForegroundColor Magenta
        $Mutex = $null
    }    
    Throw "Exit & abandon Mutex"
}
Write-Host "Closing $AppName"


# Release the singleton application mutex
Clear-MutexSingleton -Mutex $Script:AppMutex
