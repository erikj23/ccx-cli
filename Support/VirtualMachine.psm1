
Function Set-VirtualMachineState  {
  param(
    [ValidateSet('AWS', 'Azure')]
    [String]$Provider = 'AWS',

    [Alias('r')]
    [String]$Region = 'us-west-2',

    [Alias('p')]
    [String[]]$Profiles,
    
    [Parameter(ParameterSetName='Filter')]
    [Alias('f')]
    [String[]]$Filters,

    [Parameter(ParameterSetName='MultiMatchByProperty')]
    [String[]]$Match,

    [Parameter(ParameterSetName='MultiMatchByProperty')]
    [Alias('by')]
    [String]$ByProperty,

    [ValidateSet('On','Off')]
    [String]$State,

    [ValidateSet('Parallel','Series')]
    [Switch]$In,

    [Switch]$Status
  )
  # find
  # if parallel
  # if series
  # action
  # state on/off requires confirmation (name, ip, current-state)
}
Set-Alias -Name vm -Value Set-VirtualMachine
# vm -state on -serial -f tag:Name=awo* -p webqa
# vm -status -f tag:Name=cas* -p webqa
# Set-VirtualMachine