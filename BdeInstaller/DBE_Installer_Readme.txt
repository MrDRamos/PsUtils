#1)	Choose a directory to unzip the BDE_Installer.zip files:
# For example your "Downloads" folder

#2) Open a PowerShell (64Bit) prompt as administrator
#2a) 1st method: In a DOS comamnd prompt type:
powershell.exe "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -NoProfile' -Verb RunAs"

#2b) 2nd method: From the windows start menu 
  - Type: PowerShell in the start menu, a PowerShell icon will show in the 'Best Match'
  - Right click on the shown PowerShell icon and select "Run as Administrator'
  - Enable running downloaded PowerShell scripts on this computer:
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
 
#3) Go to the directory of the unzipped DBE installer files (from step 1):
cd ~\Downloads\BDE_Installer

#4) Remove the security block from the unzipped PowerShell scripts:
dir *.ps1 -Recurse | Unblock-File

#5) See if the BDE Was already installed on the system:
Show-BDEInfo.ps1

#6a) Run the BDE installer script if this is a new installation of the DBE:
.\Install-BDE.ps1

#6b) If the BDE was already installed on Windows 10 systems with the default 
# installer, then it needs to be fixed by moving the \Borland shared\ folder 
# out of \Program Files\ by running the Move-BorlandShared.ps1 program:
.\Move-BorlandShared.ps1 *>&1 | tee BDE_Movelog.txt

#7) Install other applications that need the BDE
#-The old Borland Database Desktop app: DBD32.exe
# Note: Rename the executable to DBDx32.exe 
#       This will remove the popup errors on startup
#-PdxEditor - Paradox and dBase editor
# http://www.nknabe.dk/database/pdxeditor/index.htm
