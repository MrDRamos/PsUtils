"`nInterlocked.Increment(`$RetValue = `$NewValue = `$OrgValue + 1)"
$OrgValue = 0
$NewValue = $OrgValue
$RefValue = [ref]$NewValue;
$RetValue = [Threading.Interlocked]::Increment($RefValue)
([PSCustomObject]@{ OrgValue = $OrgValue; RetValue = $RetValue; NewValue = $NewValue } | Format-Table | Out-String).Trim()

"`nInterlocked.Add(`$RetValue = `$NewValue = `$OrgValue + `$Increment)"
$OrgValue = 1
$NewValue = $OrgValue
$Increment = 1
$RetValue = [Threading.Interlocked]::Add([ref]$NewValue, $Increment)
([PSCustomObject]@{ OrgValue = $OrgValue; RetValue = $RetValue; NewValue = $NewValue; Increment = $Increment } | Format-Table | Out-String).Trim()

"`nInterlocked.CompareExchange(if (`$OrgValue -EQ `$Comparand) then {`$NewValue = 3} )"
$OrgValue = 0
$NewValue = $OrgValue
$RetValueIfTrue = 3
$Comparand = 0
$RetValue = [Threading.Interlocked]::CompareExchange([ref]$NewValue, $RetValueIfTrue, $Comparand)
([PSCustomObject]@{ OrgValue = $OrgValue; RetValue = $RetValue; NewValue = $NewValue; Comparand = $Comparand } | Format-Table | Out-String).Trim()

"`nInterlocked.CompareExchange(if (`$OrgValue -EQ `$Comparand) then {`$NewValue = 4} )"
$OrgValue = 1
$NewValue = $OrgValue
$RetValueIfTrue = 4
$Comparand = 0
$RetValue = [Threading.Interlocked]::CompareExchange([ref]$NewValue, $RetValueIfTrue, $Comparand)
([PSCustomObject]@{ OrgValue = $OrgValue; RetValue = $RetValue; NewValue = $NewValue; Comparand = $Comparand } | Format-Table | Out-String).Trim()
