
Function Get-ResourceAccounts {
  [CmdletBinding()]
  param
  (
    [ValidateSet([Provider])]
    [String]$Provider = 'AWS',

    [String]$RootAccount = 'manage'

  )
  switch ($Provider) {
    'AWS' {
      Get-ResourceAccountsCache -Provider AWS -RootAccount $RootAccount 
    }
  }
}
Set-Alias -Name accounts -Value Get-ResourceAccounts

Function Get-ResourceAccountsCache {
  param
  (
    [ValidateSet([Provider])]
    [String]$Provider,

    [String]$RootAccount = 'manage'
  )
  switch ($Provider) {
    'AWS' {
      if (Test-Path Cache:AwsResourceAccounts) {
        $LastWriteTime = Get-ItemProperty -Path Cache:AwsResourceAccounts -Name LastWriteTime | Get-Date | New-Timespan
        
        # cache expires after 1 days
        if ($LastWriteTime.Days -gt 1) {
          $Update = aws --profile $RootAccount organizations list-accounts --query "Accounts[]" --output json
          Set-Content Cache:AwsResourceAccounts -Value $Update
        }
      }
      else {
        $Update = aws --profile $RootAccount organizations list-accounts --query "Accounts[]" --output json
        Set-Content Cache:AwsResourceAccounts -Value $Update
      }
      $Cache:AwsResourceAccounts | ConvertFrom-Json
    }
  }
}
