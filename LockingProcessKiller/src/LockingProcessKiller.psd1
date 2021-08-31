#
# Module manifest for module 'LockingProcessKiller'
#
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'LockingProcessKiller.psm1'
    
    # Version number of this module.
    ModuleVersion = '0.9.0'
    
    # ID used to uniquely identify this module
    GUID = 'f938e18a-3b10-4e91-ac1c-bfe2d5fa7384'
    
    # Author of this module
    Author = 'David Ramos'
    
    # Description of the functionality provided by this module
    Description       = 'Utility to discover & kill processes that have open handles to a file or folder'
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1.14'
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        "Find-LockingProcess"
        "Stop-LockingProcess"
    )
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
    
        PSData = @{
    
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @("find", "lock", "locking", "file", "directory", "handle", "kill", "process")
    
            # A URL to the license for this module.
            # LicenseUri = ''
    
            # A URL to the main website for this project.
            ProjectUri = ''
    
            # ReleaseNotes of this module
            ReleaseNotes = @'
## Utility to discover & kill processes that have open handles to a file or folder.

### Find-LockingProcess()  
    Retrieves process information that has a file handle open to the specified path.
    Example: Find-LockingProcess -Path $Env:LOCALAPPDATA
    Example: Find-LockingProcess -Path $Env:LOCALAPPDATA | Get-Process

### Stop-LockingProcess()  
    Kills all processes that have a file handle open to the specified path.
    Example: Stop-LockingProcess -Path $Home\Documents 
'@
    
        } # End of PSData hashtable
    
    } # End of PrivateData hashtable
    
    # HelpInfo URI of this module
    HelpInfoURI       = ''
    
 }
