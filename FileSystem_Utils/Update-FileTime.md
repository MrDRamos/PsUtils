**Update-FileTime: A Full-Featured PowerShell 'touch' Equivalent**

Update-FileTime is a cross-platform PowerShell function that replicates and extends the functionality of the Linux `touch` command. It allows you to create empty files or update the LastWriteTime and LastAccessTime of one or more files to the current system time, a specified local time, or a specified UTC time. You can also match timestamps from a reference file.

**Key features:**
- Creates files if they do not exist (unless disabled).
- Updates both access and modification times by default, or only one if specified.
- Supports setting timestamps to a specific local time (`-TimeStamp`) or UTC time (`-TimeStampUTC`).
- Allows copying timestamps from a reference file.
- Optionally creates parent directories if needed (`-CreateFolders`).
- Skips directories and provides clear feedback.
- Supports pipeline input and robust error handling.
- Well-documented and user-friendly.
- Compatible with Windows, Linux, and macOS (PowerShell Core).

This script is a versatile solution for anyone needing true `touch` functionality in PowerShell, offering advanced timestamp options and cross-platform support.
