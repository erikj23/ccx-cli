
Function Set-VMState {
  param(
    [ValidateSet([Provider])]
    [String]$Provider = 'AWS',

    [Alias('r')]
    [String]$Region = 'us-west-2',

    [Alias('p')]
    [String[]]$Profiles,
    
    [Parameter(ParameterSetName='Filter')]
    [Alias('f')]
    [String[]]$Filters,
        
    [ValidateSet('Parallel','Series')]
    [Switch]$In,
        
    [String[]]$Changes
  )
  # pseudo
  # get state
  # Get-VMState
  # if changes
  #   power off
  #   do changes
  #   set state
  # find
  # if parallel
  # if series
  # action
  # state on/off requires confirmation (name, ip, current-state)
}
Set-Alias -Name vm -Value Set-VMState
# vm -changes backup, resize=t3.small -f tag:Name=awo* -p webqa
# vm -status -f tag:Name=cas* -p webqa
# Set-VirtualMachine

function Resize-VM {
  param(
    [String[]]$VMs,
    [String]$newsize,
    [String]$p
  )   
  foreach($VM in $VMs) {
    $info = resource -p $p -f tag:Name=$VM
    $state = ''
    while ($state -ne 'Stopped') {      
      $state = aws --profile $p ec2 stop-instances --instance-ids $info.instanceid --query "StoppingInstances[].CurrentState.Name" --output json | ConvertFrom-Json
      start-sleep -Seconds 1      
    }
    "STOPPED $VM"
    aws --profile $p ec2 modify-instance-attribute --instance-id $info.instanceid --instance-type "{\`"Value\`": \`"$newsize\`"}"
    "RESIZED to $newsize`n`r"
    $state = ''
    while ($state -ne 'Running') {      
      $state = aws --profile $p ec2 start-instances --instance-ids $info.instanceid --query "StartingInstances[].CurrentState.Name" --output json | ConvertFrom-Json 
      start-sleep -Seconds 1      
    }
    "STARTED $VM"
  }
}

Function Backup-VM {
  [CmdLetBinding()]
  param(
    [ValidateSet([Provider])]
    [String]$Provider = 'AWS',

    [Alias('r')]
    [String]$Region = 'us-west-2',
    
    [Alias('p')]
    [String[]]$Profiles,
    
    [Alias('f')]
    [String[]]$Filters,

    [ValidateSet('Parallel','Series')]
    [Switch]$In,

    [Switch]$NoPrompt,
    [Switch]$Step
  )
  if (!$Filters) {
    throw "Filter [$Filters] is not allowed"
  }
  $Request = @{
    Provider = $Provider
    Region   = $Region
    Profiles = $Profiles
    Filters  = $Filters
    NoPrompt = $NoPrompt
  }      
  $Resources = Stop-VM @Request
  switch ($Provider) {
    'AWS' {
      foreach ($Resource in $Resources) {
        $Tags = ($Resource.Tags.Keys | ForEach-Object { "{Key=$_,Value=$($Resource.Tags[$_])}"}) -join ','
        $Resource.BlockDeviceMappings.Ebs.VolumeId | ForEach-Object -Parallel {
          $VolumeId = $_
          $VolumeId
          $Snapshot = aws --profile $Using:Resource.Profile --region $Using:Resource.Region ec2 create-snapshot `
            --volume-id $VolumeId --tag-specifications "ResourceType=snapshot,Tags=[$Using:Tags]" `
            --output json | ConvertFrom-Json
          $Snapshot
          while ($Snapshot.State -ne 'Pending') {
            Start-Sleep -Seconds 1
            $Snapshot = aws --profile $Using:Resource.Profile --region $Using:Resource.Region ec2 describe-snapshots `
              --snapshot-ids $Snapshot.SnapshotId --query "Snapshots[0].{SnapshotId:SnapshotId,State:State}" `
              --output json | ConvertFrom-Json
            $Snapshot
          }
        } -ThrottleLimit 8
        #Invoke-ResourceAction -In Parallel {}
      }
    }
    default { throw "Provider [$Provider] is currently not supported" }
  }
  if (-not $Step.IsPresent) {
    return Start-VM @Request
  }
}

Function Stop-VM {
  [CmdLetBinding()]
  param(
    [ValidateSet([Provider])]
    [String]$Provider = 'AWS',

    [Alias('r')]
    [String]$Region = 'us-west-2',
    
    [Alias('p')]
    [String[]]$Profiles,
    
    [Alias('f')]
    [String[]]$Filters,

    [ValidateSet('Parallel','Series')]
    [Switch]$In,

    [Switch]$NoPrompt
  )
  if (!$Filters) {
    throw "Filter [$Filters] is not allowed"
  }
  $SearchRequest = @{
    Provider     = $Provider
    Region       = $Region
    ResourceType = 'VirtualMachine'
    Profiles     = $Profiles
    Filters      = $Filters
  }
  $Resources = Find-Resource @SearchRequest
  switch ($Provider) {
    'AWS' {
      $ApprovalRequest = @{
        Resources = $Resources
        Title     = 'Virtual Machine(s)'
        Question  = 'Stop vm(s) listed?'
        Show      = 'Profile','InstanceId','tag:Name'
        NoPrompt  = $NoPrompt
      }
      if (Approve-ResourceAction @ApprovalRequest) {
        $Resources | ForEach-Object -Parallel {
          $Resource = $_          
          $State = ''
          while ($State -ne 'Stopped') {      
            $State = aws --profile $Resource.Profile --region $Resource.Region ec2 stop-instances --instance-ids $Resource.InstanceId --query "StoppingInstances[].CurrentState.Name" --output json | ConvertFrom-Json
            Start-Sleep -Seconds 1      
          }           
        } -ThrottleLimit 8
      }
    }
    default { throw "Provider [$Provider] is currently not supported" }
  }
  return $Resources
}

Function Start-VM {
  [CmdLetBinding()]
  param(
    [ValidateSet([Provider])]
    [String]$Provider = 'AWS',

    [Alias('r')]
    [String]$Region = 'us-west-2',
    
    [Alias('p')]
    [String[]]$Profiles,
    
    [Alias('f')]
    [String[]]$Filters,
    [Switch]$NoPrompt
  )
  if (!$Filters) {
    throw "Filter [$Filters] is not allowed"
  }
  $SearchRequest = @{
    Provider     = $Provider
    Region       = $Region
    ResourceType = 'VirtualMachine'
    Profiles     = $Profiles
    Filters      = $Filters
  }
  $Resources = Find-Resource @SearchRequest
  switch ($Provider) {
    'AWS' {
      $ApprovalRequest = @{
        Resources = $Resources
        Title     = 'Virtual Machine(s)'
        Question  = 'Start vm(s) listed?'
        Show      = 'Profile','InstanceId','tag:Name'
        NoPrompt  = $NoPrompt
      }
      if (Approve-ResourceAction @ApprovalRequest) {
        $Resources | ForEach-Object -Parallel {
          $Resource = $_          
          $State = ''
          while ($State -ne 'Running') {      
            $State = aws --profile $Resource.Profile --region $Resource.Region ec2 start-instances --instance-ids $Resource.InstanceId --query "StartingInstances[].CurrentState.Name" --output json | ConvertFrom-Json
            Start-Sleep -Seconds 1      
          }           
        } -ThrottleLimit 8
      }
    }
    default { throw "Provider [$Provider] is currently not supported" }
  }
  return $Resources
}
