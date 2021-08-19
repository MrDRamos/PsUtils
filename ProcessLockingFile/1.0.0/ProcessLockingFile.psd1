#
# Module manifest for module 'ProcessUsing'
#
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ProcessLockingFile.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'aaca8efd-fa3d-4e42-9e27-0db927fe061c'
    
    # Author of this module
    Author = 'David Ramos'

    # Description of the functionality provided by this module
    Description = 'Functions to discover & kill processes that have open file handles to a file or folder'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1.14'

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        "Find-ProcessLockingFile"
        "Stop-ProcessLockingFile"
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
    
        PSData = @{
    
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @("lock", "file", "directory", "handle", "kill", "process" )
    
            # A URL to the license for this module.
            # LicenseUri = ''
    
            # A URL to the main website for this project.
            ProjectUri = ''
    
            # ReleaseNotes of this module
            # ReleaseNotes = ''
    
        } # End of PSData hashtable
    
    } # End of PrivateData hashtable
 }
