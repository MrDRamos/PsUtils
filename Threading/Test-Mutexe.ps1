<#
# Mutexes
$mtx = New-Object System.Threading.Mutex($false, "MyMutex")
If ($mtx.WaitOne()) #Calling WaitOne() without parameters creates a blocking call until mutex available
{
    #Do Work
    [void]$mtx.ReleaseMutex()
}
#$mtx.Dispose()
#>
