
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
    [String]$RootAccount = 'manage',
    [Switch]$Force
  )
  switch ($Provider) {
    'AWS' {
      if (Test-Path Cache:AwsResourceAccounts) {
        $LastWriteTime = Get-ItemProperty -Path Cache:AwsResourceAccounts -Name LastWriteTime | Get-Date | New-Timespan
        
        # cache expires after 1 days
        if ($LastWriteTime.Days -gt 1 -or $Force) {
          $Accounts = aws --profile $RootAccount organizations list-accounts --query "Accounts[]" --output json | ConvertFrom-Json
          $Accounts | ForEach-Object -Parallel {
            $AccountInfo = $_
            $AccountTags = aws --profile $Using:RootAccount organizations list-tags-for-resource --resource-id $AccountInfo.Id --output json | ConvertFrom-Json
            $AccountInfo | Add-Member -Name 'Tags' -Value ($AccountTags.Tags) -Type NoteProperty
            Write-Output $AccountInfo
          } -ThrottleLimit 8 | ConvertTo-Json | Set-Content Cache:AwsResourceAccounts
        } 
      }
      else {
        $Accounts = aws --profile $RootAccount organizations list-accounts --query "Accounts[]" --output json | ConvertFrom-Json
        $Accounts | ForEach-Object -Parallel {
          $AccountInfo = $_
          $AccountTags = aws --profile $Using:RootAccount organizations list-tags-for-resource --resource-id $AccountInfo.Id --output json | ConvertFrom-Json
          $AccountInfo | Add-Member -Name 'Tags' -Value ($AccountTags.Tags) -Type NoteProperty
          Write-Output $AccountInfo
        } -ThrottleLimit 8 | ConvertTo-Json | Set-Content Cache:AwsResourceAccounts
      }
      $Cache:AwsResourceAccounts | ConvertFrom-Json
    }
  }
}
