"`nInterlocked.Increment()"
$OrgValue = 0
$NewValue = $OrgValue
$RefInput = [ref]$NewValue;
$RetValue = [Threading.Interlocked]::Increment($RefInput)
([PSCustomObject]@{ OrgValue = $OrgValue; RetValue = $RetValue; NewValue = $NewValue } | Format-Table | Out-String).Trim()

"`nInterlocked.Add()"
$OrgValue = 1
$NewValue = $OrgValue
$Increment = 1
$RetValue = [Threading.Interlocked]::Add([ref]$NewValue, $Increment)
([PSCustomObject]@{ OrgValue = $OrgValue; RetValue = $RetValue; NewValue = $NewValue } | Format-Table | Out-String).Trim()

"`nInterlocked.CompareExchange(Same)"
$OrgValue = 0
$NewValue = $OrgValue
$RetValueIfTrue = 3
$Comparand = 0
$RetValue = [Threading.Interlocked]::CompareExchange([ref]$NewValue, $RetValueIfTrue, $Comparand)
([PSCustomObject]@{ OrgValue = $OrgValue; RetValue = $RetValue; NewValue = $NewValue; Comparand = $Comparand } | Format-Table | Out-String).Trim()

"`nInterlocked.CompareExchange(Diff)"
$OrgValue = 1
$NewValue = $OrgValue
$RetValueIfTrue = 4
$Comparand = 0
$RetValue = [Threading.Interlocked]::CompareExchange([ref]$NewValue, $RetValueIfTrue, $Comparand)
([PSCustomObject]@{ OrgValue = $OrgValue; RetValue = $RetValue; NewValue = $NewValue; Comparand = $Comparand } | Format-Table | Out-String).Trim()
