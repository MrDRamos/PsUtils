#region MsSql API
<#
.COMPONENT
Note: The 'System.Data.SqlClient' package is now deprecated and replaced by: 'Microsoft.Data.SqlClient'
https://techcommunity.microsoft.com/blog/sqlserver/announcement-system-data-sqlclient-package-is-now-deprecated/4227205
#>


<#
.SYNOPSIS
Converts a [hashtable] or [PSCustomObject] with database connection parameters to a connection string,
Return a ';' delimited list of key=value parameters needed to open the connection to an MsSQL database server

.LINK
SqlConnection.ConnectionString Properties:
https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlconnection.connectionstring?view=net-9.0-pp

Example Parameters:
Data Source         = HostName[\ServiceName][,Port]
User Id             = $ENV:USERNAME
Password            = Password
Integrated Security = true
Database            = Database
Application Name    = MyAppName
#>
function ConvertTo-MsSqlConnectionString($ConnectionArgs = $null)
{
    if ($ConnectionArgs)
    {
        if ($ConnectionArgs -is [hashtable])
        {
            $QuotedArgS = @{}
            foreach ($kvp in $ConnectionArgs.GetEnumerator()) 
            {
                $Name = ([string]$kvp.Name).Trim()
                $Value = ([string]$kvp.Value).Trim()
                if ($Name -eq 'User Id' -or $Name -eq 'Password')
                {
                    $Value = "'" + $Value +"'"
                }
                $QuotedArgS[$Name] = $Value
            } 
            $ConnectionString = ($QuotedArgS.GetEnumerator() | ForEach-Object { $_.Name +'=' +$_.Value }) -join ';'
        }
        else 
        {
            $QuotedArgS = @{}
            foreach ($kvp in $ConnectionArgs.PsObject.Properties)
            {
                $Name = ([string]$kvp.Name).Trim()
                $Value = ([string]$kvp.Value).Trim()
                if ($Name -eq 'User Id' -or $Name -eq 'Password')
                {
                    $Value = "'" + $Value +"'"
                }
                $QuotedArgS[$Name] = $Value
            } 
            $ConnectionString = ($QuotedArgS.GetEnumerator() | ForEach-Object { $_.Name +'=' +$_.Value }) -join ';'
        }
        return $ConnectionString
    }
}


<#
.SYNOPSIS
Creates and opens a database connection based on the provided ConnectionArgs

.PARAMETER ConnectionString
A ';' delimited list of key=value parameters needed to open the connection to an MsSQL database server
Connection string examples:
    "Integrated Security=true"  # Uses MsSQL installed on local host
    "Server=HostName;Integrated Security=true"
    "Data Source=HostName[\ServiceName][,Port];User Id=UserName;Password=Password[;Database=Database][;Application Name=AppName]"

.PARAMETER ConnectionArgs
A [hashtable] or [PSCustomObject] with connection parameters used to generate a connection string
#>
function Open-MsSqlConnection
{
    [CmdletBinding(DefaultParameterSetName='ByString')]
    [OutputType([System.Data.SqlClient.SqlConnection])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='ByString', HelpMessage = "Example: Server=<HostName>;Integrated Security=true")]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='ByKvp', HelpMessage = "[hashtable] or [PSCustomObject] with connection parameters")]
        [ValidateNotNullOrEmpty()]
        $ConnectionArgs
    )


    $DbConnection = $null
    $ActionErr = $ShowConnectionStr = $null
    try 
    {
        if ($ConnectionArgs)
        {
            $ActionErr = 'Creating database connection string'
            $ConnectionString = ConvertTo-MsSqlConnectionString -ConnectionArgs $ConnectionArgs
        }
        $ShowConnectionStr = $ConnectionString
        if ($ConnectionString -match '(.*Password)\s*=(.*)')
        {
            # Drop anything after Password= because the password may be malformed e.g. contain a ';\w+=' character sequence
            $ShowConnectionStr = $Matches[1] + '=*** ;...' 
        }        
        Write-Verbose "Opening MsSql-Server connection: $ShowConnectionStr"

        $ActionErr = 'Opening a connection to the MsSql-Server'
        $DbConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString) 
        $ActionErr = '- A connection was successfully established with the MsSql-Server, but then an error occurred during the logon process.'
        $DbConnection.Open()
    }
    catch 
    {
        if ($ShowConnectionStr)
        {
            $ErrMsg = "Error {0}. Connection String:{1}`n{2}" -f $ActionErr, $ShowConnectionStr, $_.Exception.Message    
        }
        else 
        {
            $ErrMsg = "Error {0}`n{1}" -f $ActionErr, $_.Exception.Message    
        }
        Write-Warning $ErrMsg
        Close-MsSqlConnection -DbConnection $DbConnection -ErrorAction Continue
        if (@("SilentlyContinue", "Ignore", "Continue") -notcontains $ErrorActionPreference)
        {
            Throw $ErrMsg
        }
        $DbConnection = $null
    }

    return $DbConnection
}
<#### Unit Test
@{Server=$ENV:COMPUTERNAME;'Integrated Security'=$true} | Open-MsSqlConnection
@{Server=$ENV:COMPUTERNAME;'User Id'='UserName';Password='Password'} | Open-MsSqlConnection
[PSCustomObject]@{Server=$ENV:COMPUTERNAME;'User Id'='UserName';Password='Password'} | Open-MsSqlConnection
"Server=.;User Id=UserName;Password=Password" | Open-MsSqlConnection
exit
#>



function Close-MsSqlConnection
{
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [System.Data.SqlClient.SqlConnection] $DbConnection = $null
    )

    if ($DbConnection)
    {
        try 
        {
            if ($DbConnection.State -eq 'Open')
            {
                $DbConnection.Close()
                try 
                {
                    $DbConnection.Close()
                }
                catch
                {
                    Write-Warning "Failed to close database connection: $($_.Exception.Message)"
                }
            }
            $DbConnection.Dispose()
        }
        catch
        {
            $ErrMsg = "Error removing database connection: $($_.Exception.Message)"
            if (@("SilentlyContinue", "Ignore", "Continue") -notcontains $ErrorActionPreference)
            {
                Throw $ErrMsg
            }
            Write-Warning $ErrMsg
        }
    }
}


<#
.SYNOPSIS
Tests if a connection could be made to a Sql Server using the provided ConnectionArgs
Returns:
  On success: The connection properties (including the ServerVersion)
  On failure: $null if -ErrorAction was set to "SilentlyContinue" | "Ignore" | "Continue"
              Otherwise an exception is thrown
#>
function Test-MsSqlConnection
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = "[hashtable] or [PSCustomObject] with connection parameters")]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ConnectionArgs
    )


    $Retval = $null
    $DbConnection = Open-MsSqlConnection -ConnectionArgs $ConnectionArgs -WarningAction SilentlyContinue
    if ($DbConnection)
    {
        $Retval = @{}
        foreach ($Prop in $DbConnection.PSObject.Properties) 
        {
            $Retval[$Prop.Name] = [string]$Prop.Value
        }
        Close-MsSqlConnection -DbConnection $DbConnection -WarningAction SilentlyContinue
    }
    return $Retval
}


<#
.Synopsis
   Retrieves data records from an MSSQL database
   The returned records are selected by executing the SQL Query on the server
   Returns multiple record sets if multiple Queries were piped in.
   The -whatif flag will open a connection to the server but the SQL will not be submitted and the result set will be empty.

.EXAMPLE
   $ConnectionArgs = @{Server=$ENV:COMPUTERNAME;'Integrated Security'=$true}
   $Records = Invoke-MsSqlQuery -Query "Select * from states" -ConnectionArgs $ConnectionArgs
   $RecordS | Format-Table

.OUTPUTS
   The data records [System.Data.DataRow] resulting from the select Query
   Returns multiple record sets tf multiple Queries were piped in
   The -whatif flag will open a connection to the server but the SQL will not be submitted and the result set will be empty.
#>
Function Invoke-MsSqlQuery
{
    [CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
    [OutputType([System.Data.DataRow])]
    Param
    (
        [Parameter(ValueFromPipeline, HelpMessage = "One or more SQL select statements to execute")]
        [string[]] $Query,

        [Parameter(Mandatory = $false, HelpMessage = "Optional argument thats useful for protecting passwords contained in the actual query. It used in verbose logs & error messages.")]
        [string[]] $QueryToDisplay = $null,

        [Parameter(Mandatory = $true, ParameterSetName = "TempConnection", HelpMessage = "[hashtable] or [PSCustomObject] with connection parameters")]
        [ValidateNotNullOrEmpty()]
        $ConnectionArgs,

        [Parameter(Mandatory = $true, ParameterSetName = "ByConnection", HelpMessage = "A Connection returned from call to Open-MsSqlConnection()")]
        [ValidateNotNull()]
        [System.Data.SqlClient.SqlConnection] $DbConnection = $null
    )

    begin 
    {
        $QueryS = New-Object System.Collections.ArrayList
    }
    
    process 
    {
        [void]$QueryS.AddRange($Query) # Aggregate all the input objects int an array
    }
    
    end
    {
        $Retval = $null
        if ($ConnectionArgs)
        {
            $DbConnection = Open-MsSqlConnection -ConnectionArgs $ConnectionArgs
        }
        if ($DbConnection)
        {
            $Action = $null
            try 
            {
                if ($DbConnection.State -ne 'Open')
                {
                    $Action = "Opening Connection"
                    $DbConnection.Open()
                }

                # Process query in the array
                [int] $QryIdx = 0
                foreach ($Query in $QueryS)
                {
                    $ShowQuery = $Query
                    if ($QueryToDisplay -and $QueryToDisplay.Count -ge $Query.Count)
                    {
                        $ShowQuery = $QueryToDisplay[$QryIdx]
                        $QryIdx++
                    }

                    Write-Verbose "Executing $ShowQuery"
      
                    $Action = "Preparing SQL-Query: $ShowQuery"
                    $Command = $DbConnection.CreateCommand()
                    $Command.CommandTimeout = 0 #There should never be a timeout on SQL operations. Its up to the invoking process to limit execution time ifneeded
                    $Command.CommandText = $Query

                    if ($pscmdlet.ShouldProcess($ShowQuery, "Executing SQL-Query:")) 
                    {
#                        if ($Query -match '\bselect\b')
#                        {
                            $Action = "Executing SQL-Query: $ShowQuery"
                            $DataSet = New-Object System.Data.DataSet
                            $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($Command)
                            [void] $DataAdapter.Fill($DataSet)
                            $Retval = $DataSet.Tables[0]
#                        }
<#                         else 
                        {
                            $Action = "Executing SQL-Statement: $ShowQuery"
                            $Retval += $Command.ExecuteNonQuery()
                        } #>
                    }
                } #foreach ($Query in $QueryS)
            }
            catch 
            {
                $ErrMsg = "Error {0}`n{1}" -f $Action, $_.Exception.Message
                if ($ConnectionArgs)
                {
                    Close-MsSqlConnection -DbConnection $DbConnection -ErrorAction Continue
                }
                Write-Error $ErrMsg
            }
            finally
            {
                if ($ConnectionArgs)
                {
                    Close-MsSqlConnection -DbConnection $DbConnection
                }
            }
        }
        return $Retval
    }
}



<#
.Synopsis
   Executes an SQL statement against the Connection and returns the number of rows affected.
   For UPDATE, INSERT, and DELETE statements, the return value is the number of rows affected by the command. 
   For CREATE TABLE and DROP TABLE statements, the return value is 0. 
   For all other types of statements, the return value is -1
   The -whatif flag will open a connection to the server but the SQL will not be submitted and the result set will be empty.

.EXAMPLE
   $ConnectionArgs = @{Server=$ENV:COMPUTERNAME;'Integrated Security'=$true}
   Invoke-MsSqlExecute -Statement "Select * from states" -ConnectionArgs $ConnectionArgs

.OUTPUTS
   For UPDATE, INSERT, and DELETE statements, the return value is the number of rows affected by the command. 
   For all other types of statements, the return value is -1
#>
function Invoke-MsSqlExecute
{
    [CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
    [OutputType([int[]])]
    Param
    (
        [Parameter(ValueFromPipeline, HelpMessage = "One or more SQL-Statements to execute")]
        [Alias("Query")]
        [string[]] $Statement,

        [Parameter(Mandatory = $false, HelpMessage = "Optional argument thats useful for protecting passwords contained in the actual SQL-Statement. Its used in verbose logs & error messages.")]
        [Alias("QueryToDisplay")]
        [string[]] $StatementToDisplay = $null,

        [Parameter(Mandatory = $true, ParameterSetName = "TempConnection", HelpMessage = "[hashtable] or [PSCustomObject] with connection parameters")]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ConnectionArgs,

        [Parameter(Mandatory = $true, ParameterSetName = "ByConnection", HelpMessage = "A Connection returned from call to Open-MsSqlConnection()")]
        [ValidateNotNull()]
        [System.Data.SqlClient.SqlConnection] $DbConnection = $null
    )

    begin 
    {
        $StatementS = New-Object System.Collections.ArrayList
    }
    
    process 
    {
        [void]$StatementS.AddRange($Statement) # Aggregate all the input objects int an array
    }
    
    end
    {
        $EffectedRows = @()
        if ($ConnectionArgs)
        {
            $DbConnection = Open-MsSqlConnection -ConnectionArgs $ConnectionArgs
        }
        if ($DbConnection)
        {
            $Action = $null
            try 
            {
                if ($DbConnection.State -ne 'Open')
                {
                    $Action = "Opening Connection"
                    $DbConnection.Open()
                }

                # Process Statement in the array
                [int] $QryIdx = 0
                foreach ($Statement in $StatementS)
                {
                    $ShowStatement = $Statement
                    if ($StatementToDisplay -and $StatementToDisplay.Count -ge $Statement.Count)
                    {
                        $ShowStatement = $StatementToDisplay[$QryIdx]
                        $QryIdx++
                    }
                    Write-Verbose "Executing $ShowStatement"

                    $Action = "Preparing SQL-Statement: $ShowStatement"
                    $Command = $DbConnection.CreateCommand()
                    $Command.CommandTimeout = 0 #There should never be a timeout on SQL operations. Its up to the invoking process to limit execution time ifneeded
                    $Command.CommandText = $Statement

                    if ($pscmdlet.ShouldProcess($ShowStatement, "Executing SQL-Statement:"))
                    {
                        $Action = "Executing SQL-Statement: $ShowStatement"
                        $EffectedRows += $Command.ExecuteNonQuery()
                    }
                } #foreach ($Query in $QueryS)
            }
            catch 
            {
                $ErrMsg = "Error {0}`n{1}" -f $Action, $_.Exception.Message
                if ($ConnectionArgs)
                {
                    Close-MsSqlConnection -DbConnection $DbConnection -ErrorAction Continue
                }
                Write-Error $ErrMsg
            }
            finally
            {
                if ($ConnectionArgs)
                {
                    Close-MsSqlConnection -DbConnection $DbConnection
                }
            }
        }
        return $EffectedRows
    }
}
<#### Unit Test ####
$DbConnectionArgS = @{
    Server                  = $ENV:COMPUTERNAME
    Database                = 'SecureStore'
    'Integrated Security'   = $true
    'Application Name'      = 'Comms-Migration'
}
Test-MsSqlConnection -ConnectionArgs $DbConnectionArgS -ErrorAction Stop
Exit
#>

#endregion MsSql API
