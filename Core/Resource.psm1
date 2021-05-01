
Function Approve-ResourceAction {
  [CmdletBinding()]
  param (
    $Resources,
    $Title,
    $Question,
    [String[]]$Show
  )
  $Resources | Select-Object $Properties | Out-Host
  $Choices  = '&Yes', '&No'
  $Decision = $Host.UI.PromptForChoice("$Title---------------------------", "$Question", $Choices, 1)
  if ($Decision -eq 0) { return $true }
  else { return $false }
}

Function Assert-ResourceProperties {
  [CmdletBinding()]
  param (
    [PSCustomObject]$Object,
    [String[]]$Properties,
    [Int]$TotalCount
  )
  $TestProperties = $Object.PSObject.Properties.Name
  if ($TestProperties.Count -ne $TotalCount) { return $false }
  foreach ($Property in $Properties) {
    if ($Property -notin $TestProperties) { return $false }
  }
  return $true
}

Function Find-Resource {
  [CmdLetBinding()]
  param(
    [ValidateSet([Provider])]
    [String]$Provider = 'AWS',

    [Alias('r')]
    [String]$Region = 'us-west-2',

    [Alias('type', 't')]
    [ValidateSet([ResourceType])]
    [String]$ResourceType = 'VirtualMachine',

    [Alias('p')]
    [String[]]$Profiles,

    [Alias('f')]
    [String[]]$Filters,

    [Alias('s')]
    [Switch]$Summary,

    [Alias('h')]
    [Switch]$Help
  )
  if ($Help) { Get-ResourceHelp $Provider $ResourceType; return }

  switch ($Provider) {
    'AWS' {
      # use local profiles to search all accounts in aws
      if (-not $Profiles) { $SearchProfiles = aws configure list-profiles }
      else { $SearchProfiles = $Profiles
      }
      $FilterString = New-Object System.Collections.Generic.List[String]
      foreach ($Filter in $Filters) {
        $Name, $Values = $Filter.Split('=').Trim()
        $FilterString.Add("Name=$Name,Values=$Values")
      }
      $SearchProfiles | ForEach-Object -Parallel {
        $SearchProfile = $_
        switch ($Using:ResourceType) {
          'VirtualMachine' {
            $Search = @{
              Provider      = $Using:Provider
              ResourceType  = $Using:ResourceType
              SearchProfile = $SearchProfile
              Region        = $Using:Region
              Service       = 'ec2'
              Command       = 'describe-instances'
              Filter        = $Using:FilterString
              Query         = 'Reservations[].Instances[]'
              Properties    = 'InstanceId','InstanceType','State','PrivateIpAddress'
              Summary       = $Using:Summary
            }
            Invoke-CommonGet @Search
          }
          'BlockStorage' {
            $Search = @{
              Provider      = $Using:Provider
              ResourceType  = $Using:ResourceType
              SearchProfile = $SearchProfile
              Region        = $Using:Region
              Service       = 'ec2'
              Command       = 'describe-volumes'
              Filter        = $Using:FilterString
              Query         = 'Volumes[]'
              Properties    = 'VolumeId','Encrypted','Size','State'
              Summary       = $Using:Summary
            }
            Invoke-CommonGet @Search
          }
          default { throw "ResourceType [$Using:ResourceType] is currently not supported" }
        }
      } -ThrottleLimit 8
    }
    default { throw "Provider [$Provider] is currently not supported" }
  }
}
Set-Alias -Name resource -Value Find-Resource

Function Get-ResourceHelp {
  [CmdletBinding()]
  param (
    [ValidateSet([Provider])]
    [String]$Provider = 'AWS',

    [Alias('type', 't')]
    [ValidateSet([ResourceType])]
    [String]$ResourceType = 'VirtualMachine'
  )
  switch ($Provider) {
    'AWS' {
      switch ($ResourceType) {
       'VirtualMachine' {
          $Hint = @{
            Provider = $Provider
            ResourceType = $ResourceType
            Service = 'ec2'
            Command = 'describe-instances'
          }
          Invoke-CommonGetHelp @Hint
        }
        default { throw "ResourceType [$ResourceType] is currently not supported" }
      }
    }
    default { throw "Provider [$Provider] is currently not supported" }
  }
}

Function Get-ResourceNetworkFlow {
  [CmdLetBinding()]
  param(
    [ValidateSet([Provider])]
    [String]$Provider = 'AWS',

    [Alias('r')]
    [String]$Region = 'us-west-2',

    [Alias('type', 't')]
    [ValidateSet([ResourceType])]
    [String]$ResourceType = 'VirtualMachine',

    [Alias('p')]
    [String[]]$Profiles,

    [Alias('f')]
    [String[]]$Filters,

    [Alias('src')]
    [String]$Source = '*',

    [Alias('dst')]
    [String]$Destination = '*',

    [Alias('srcp')]
    [String]$SourcePort = '*',

    [Alias('dstp')]
    [String]$DestinationPort = '*',

    [String]$Protocol = '*',

    [Alias('a')]
    [String]$Action = '*',

    [String]$Status = '*'
  )
  if (!(Test-Path Cache:IanaProtocolNumbers)) {
    $XML = Invoke-WebRequest https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xml | Select-Object -ExpandProperty Content
    ([XML]$XML).Registry.Registry.Record | Select-Object Name, Value | ConvertTo-Json | Set-Content -Path Cache:IanaProtocolNumbers
  }
  else {
    $IanaProtocolNumbers = Get-Content Cache:IanaProtocolNumbers | ConvertFrom-Json
  }
  $SearchRequest = @{
    Provider     = $Provider
    Region       = $Region
    ResourceType = $ResourceType
    Profiles     = $Profiles
    Filters      = $Filters
  }
  $Resources = Find-Resource @SearchRequest
  $Resources | ForEach-Object -Parallel {
    $Resource = $_
    if ($Resource.Provider -eq 'AWS') {
      switch ($Resource.ResourceType) {
        'VirtualMachine' {
          $LogGroupNames = aws --profile $Resource.Profile ec2 describe-flow-logs --filter "Name=resource-id,Values=$($Resource.VpcId)" --query "FlowLogs[].LogGroupName" --output json | ConvertFrom-Json
          foreach($LogGroupName in $LogGroupNames) {
            $StartTime = Get-Date -Minute 1 -AsUTC -UFormat '%s'
            $NetworkInterfaceIds = $Resource.NetworkInterfaces.NetworkInterfaceId
            foreach($NetworkInterfaceId in $NetworkInterfaceIds) {
              $NetworkInterfaceIds = 'interface-id=' + ($NetworkInterfaceIds -join ' || interface-id=')
              #$FilterPattern = "[..., $NetworkInterfaceIds, srcaddr=$Using:Source, dstaddr=$Using:Destination, srcport=$Using:SourcePort, dstport=$Using:DestinationPort, protocol=$Using:Protocol, bytes, start, end, action=$Using:Action, log-status=$Using:Status]"
              $LogGroupNames
              aws --profile $Resource.Profile logs filter-log-events --log-group-name $LogGroupName --log-stream-names "$NetworkInterfaceId-all" --start-time $StartTime --query "events[1]" --output json
            }
          }
          return
        }
        default { throw "ResourceType [$ResourceType] is currently not supported" }
      }
    }
    if ($Provider -eq 'Azure') {
      throw "Provider [$Provider] is currently not supported"
    }
  } -ThrottleLimit 8
}
Set-Alias -Name flow -Value Get-NetworkFlow
# flow -srcaddr '10.10.10*' -f tag:Name=x

Function Remove-Resource {
  [CmdLetBinding()]
  param(
    [ValidateSet([Provider])]
    [String]$Provider = 'AWS',

    [Alias('r')]
    [String]$Region = 'us-west-2',

    [Alias('type', 't')]
    [ValidateSet([ResourceType])]
    [String]$ResourceType = 'VirtualMachine',

    [Alias('p')]
    [String[]]$Profiles,

    [Alias('f')]
    [String[]]$Filters
  )
  if (!$Filters) {
    throw "Filter [$Filters] is not allowed"
  }
  $SearchRequest = @{
    Provider     = $Provider
    Region       = $Region
    ResourceType = $ResourceType
    Profiles     = $Profiles
    Filters      = $Filters
    Summary      = $true
  }
  $Resources = Find-Resource @SearchRequest
  switch ($Provider) {
    'AWS' {
      if (Approve-ResourceAction $Resources -Title 'Virtual Machine(s)' -Question 'Delete vm(s) listed?' -Show Profile, Name, InstanceId) {
        $Resources | ForEach-Object -Parallel {
          $Resource = $_
          switch ($Using:ResourceType) {
            'VirtualMachine' {
              aws --profile $Resource.Profile --region $Resource.Region ec2 terminate-instances --instance-ids $Resource.InstanceId --query "TerminatingInstances[]" --output json | ConvertFrom-Json
              return
            }
            default { throw "ResourceType [$ResourceType] is currently not supported" }
          }
        } -ThrottleLimit 8
      }
    }
    default { throw "Provider [$Provider] is currently not supported" }
  }
}
Set-Alias -Name release -Value Remove-Resource
