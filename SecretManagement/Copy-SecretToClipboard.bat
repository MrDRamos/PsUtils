rem make a desktop shorcut to this bat file, Set its properties to run minimized
@start /B Powershell /NoLogo -Command "& { %~dpn0%.ps1 }"