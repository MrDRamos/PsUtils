## Utility to discover/kill processes that have open file handles to a file or folder.

### Find-ProcessLockingFile  
    This function retrieves process and user information that have a file handle open to the specified path.
    Example: Find-ProcessLockingFile -Path $Env:LOCALAPPDATA
    Example: Find-ProcessLockingFile -Path $Env:LOCALAPPDATA | Get-Process

### Stop-ProcessLockingFile  
    This function kills all processes that have a file handle open to the specified path.
    Example: Stop-ProcessLockingFile -Path $Home\Documents 
