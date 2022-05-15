<#
.Synopsis
This will get a Information on the last users who logged into a machine.
More info can be found: https://docs.microsoft.com/en-us/windows/security/threat-protection/auditing/basic-audit-logon-events

.DESCRIPTION
This script is not the same as the Get Last Logon Date For All Users in Your Domain. 
That script checks Active Directory for last login information, while this script specifically checks a local or remote computer’s 
last login info. With that said, the machine you want to query must be online since we’re going to be checking the event logs to 
get this data

Requirements: This script uses the machine’s Event Security log so you will need run with Administrator rights. 

.PARAMETER ComputerName
By default this will use the local computer, but you can specify other computers in a comma separated format or through an array variable

.PARAMETER SamAccountName
This will only output the SamAccountName that you specified. All other users would be excluded and cannot be used with ExcludeSamAccountName

.PARAMETER ExcludeSamAccountName
This will exclude the SamAccountName that you specified. All other users would be displayed and cannot be used with SamAccountName

.PARAMETER LoginEvent
This will filter which event types you would like to display. Only one option can be selected and the only valid options are 
    SuccessfulLogin
    FailedLogin
    Logoff
    DisconnectFromRDP
If a value is not specified, it will default to SuccessfulLogin

.PARAMETER DaysFromToday
This will query how many days back you would like to search for. The default is 3 days.

.PARAMETER MaxEvents
This will set the maximum number of events to display.

.PARAMETER Credential
Allow other credentials to be used for remote machines.

.EXAMPLE
Get-LastLoginInfo -ComputerName Server01, Server02, PC03 -SamAccountName username
 
.LINK
https://thesysadminchannel.com/get-computer-last-login-information-using-powershell -

.NOTES
    Name: Get-LastLoginInfo
    Author: theSysadminChannel
    Version: 1.0
    DateCreated: 2020-Nov-27
#>

[CmdletBinding(DefaultParameterSetName = "Default")]
param(
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 0
    )]
    [string[]]  $ComputerName = $env:COMPUTERNAME,
 
 
    [Parameter(
        Position = 1,
        Mandatory = $false,
        ParameterSetName = "Include"
    )]
    [string]    $SamAccountName,
 
 
    [Parameter(
        Position = 1,
        Mandatory = $false,
        ParameterSetName = "Exclude"
    )]
    [string]    $ExcludeSamAccountName,
 
 
    [Parameter(
        Mandatory = $false
    )]
    [ValidateSet("SuccessfulLogin", "FailedLogin", "Logoff", "DisconnectFromRDP")]
    [string]    $LoginEvent = "SuccessfulLogin",
 
 
    [Parameter(
        Mandatory = $false
    )]
    [int]       $DaysFromToday = 3,
 
 
    [Parameter(
        Mandatory = $false
    )]
    [int]       $MaxEvents = 1024,
 
 
    [System.Management.Automation.PSCredential]
    $Credential
)



Function Get-LastLoginInfo
{
    #requires -RunAsAdministrator 
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string[]]  $ComputerName = $env:COMPUTERNAME,
 
 
        [Parameter(
            Position = 1,
            Mandatory = $false,
            ParameterSetName = "Include"
        )]
        [string]    $SamAccountName,
 
 
        [Parameter(
            Position = 1,
            Mandatory = $false,
            ParameterSetName = "Exclude"
        )]
        [string]    $ExcludeSamAccountName,
 
 
        [Parameter(
            Mandatory = $false
        )]
        [ValidateSet("SuccessfulLogin", "FailedLogin", "Logoff", "DisconnectFromRDP")]
        [string]    $LoginEvent = "SuccessfulLogin",
 
 
        [Parameter(
            Mandatory = $false
        )]
        [int]       $DaysFromToday = 3,
 
 
        [Parameter(
            Mandatory = $false
        )]
        [int]       $MaxEvents = 1024,
 
 
        [System.Management.Automation.PSCredential]
        $Credential
    )
 
 
    BEGIN
    {
        $StartDate = (Get-Date).AddDays(-$DaysFromToday)
        Switch ($LoginEvent)
        {
            SuccessfulLogin { $EventID = 4624 }
            FailedLogin { $EventID = 4625 }
            Logoff { $EventID = 4647 }
            DisconnectFromRDP { $EventID = 4779 }
        }
    }
 
    PROCESS
    {
        foreach ($Computer in $ComputerName)
        {
            try
            {
                $Computer = $Computer.ToUpper()
                $Time = "{0:F0}" -f (New-TimeSpan -Start $StartDate -End (Get-Date) | Select-Object -ExpandProperty TotalMilliseconds) -as [int64]
 
                if ($PSBoundParameters.ContainsKey("SamAccountName"))
                {
                    $EventData = "
                        *[EventData[
                                Data[@Name='TargetUserName'] != 'SYSTEM' and
                                Data[@Name='TargetUserName'] != '$($Computer)$' and
                                Data[@Name='TargetUserName'] = '$($SamAccountName)'
                            ]
                        ]
                    "
                }
 
                if ($PSBoundParameters.ContainsKey("ExcludeSamAccountName"))
                {
                    $EventData = "
                        *[EventData[
                                Data[@Name='TargetUserName'] != 'SYSTEM' and
                                Data[@Name='TargetUserName'] != '$($Computer)$' and
                                Data[@Name='TargetUserName'] != '$($ExcludeSamAccountName)'
                            ]
                        ]
                    "
                }
 
                if ((-not $PSBoundParameters.ContainsKey("SamAccountName")) -and (-not $PSBoundParameters.ContainsKey("ExcludeSamAccountName")))
                {
                    $EventData = "
                        *[EventData[
                                Data[@Name='TargetUserName'] != 'SYSTEM' and
                                Data[@Name='TargetUserName'] != '$($Computer)$'
                            ]
                        ]
                    "
                }
 
                $Filter = @"
                    <QueryList>
                        <Query Id="0">
                            <Select Path="Security">
                            *[System[
                                    Provider[@Name='Microsoft-Windows-Security-Auditing'] and
                                    EventID=$EventID and
                                    TimeCreated[timediff(@SystemTime) &lt;= $($Time)]
                                ]
                            ]
                            and
                                $EventData
                            </Select>
                        </Query>
                    </QueryList>
"@
 
                if ($PSBoundParameters.ContainsKey("Credential"))
                {
                    $EventLogList = Get-WinEvent -ComputerName $Computer -FilterXml $Filter -Credential $Credential -ErrorAction Stop
                }
                else
                {
                    $EventLogList = Get-WinEvent -ComputerName $Computer -FilterXml $Filter -ErrorAction Stop
                }
 
 
                $Output = foreach ($Log in $EventLogList)
                {
                    #Removing seconds and milliseconds from timestamp as this is allow duplicate entries to be displayed
                    $TimeStamp = $Log.timeCReated.ToString('MM/dd/yyyy hh:mm tt') -as [DateTime]
 
                    switch ($Log.Properties[8].Value)
                    {
                        2 { $LoginType = 'Interactive' }
                        3 { $LoginType = 'Network' }
                        4 { $LoginType = 'Batch' }
                        5 { $LoginType = 'Service' }
                        7 { $LoginType = 'Unlock' }
                        8 { $LoginType = 'NetworkCleartext' }
                        9 { $LoginType = 'NewCredentials' }
                        10 { $LoginType = 'RemoteInteractive' }
                        11 { $LoginType = 'CachedInteractive' }
                    }
 
                    if ($LoginEvent -eq 'FailedLogin')
                    {
                        $LoginType = 'FailedLogin'
                    }
 
                    if ($LoginEvent -eq 'DisconnectFromRDP')
                    {
                        $LoginType = 'DisconnectFromRDP'
                    }
 
                    if ($LoginEvent -eq 'Logoff')
                    {
                        $LoginType = 'Logoff'
                        $UserName = $Log.Properties[1].Value.toLower()
                    }
                    else
                    {
                        $UserName = $Log.Properties[5].Value.toLower()
                    }
 
 
                    [PSCustomObject]@{
                        ComputerName = $Computer
                        TimeStamp    = $TimeStamp
                        UserName     = $UserName
                        LoginType    = $LoginType
                    }
                }
 
                #Because of duplicate items, we'll append another select object to grab only unique objects
                $Output | Select-Object ComputerName, TimeStamp, UserName, LoginType -Unique | Select-Object -First $MaxEvents
 
            }
            catch
            {
                Write-Error $_.Exception.Message
 
            }
        }
    }
 
    END {}
}


Get-LastLoginInfo @PSBoundParameters
