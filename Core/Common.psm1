
Function Format-CommonResource {
  [CmdletBinding()]
  param (
    [PSCustomObject]$Object
  )
  $PropertyTable = [HashTable]@{}
  foreach($PropertyName in $Object.PSObject.Properties.Name) {
    switch ($Object.$PropertyName.GetType().Name.ToString()) {
      'PSCustomObject' {
        $PropertyTable[$PropertyName] = Format-CommonResource $Object.$PropertyName        
      }
      'Object[]' {
        if ((Assert-ResourceProperties $Object.$PropertyName[0] -Properties 'Key','Value' -TotalCount 2) -eq $true) {
          $SubPropertyTable = [HashTable]@{}
          foreach ($Property in $Object.$PropertyName) {
            $SubPropertyTable[$Property.Key] = $Property.Value
          }
          $PropertyTable[$PropertyName] = $SubPropertyTable
        }
        else {
          $Index = 0
          $PropertyArray = [Object[]]::new($Object.$PropertyName.Count)
          foreach ($SubProperty in $Object.$PropertyName) {
            $PropertyArray[$Index] = Format-CommonResource $SubProperty
            $Index += 1
          }
          $PropertyTable[$PropertyName] = $PropertyArray
        }
      }
      default {
        $PropertyTable[$PropertyName] = $Object.$PropertyName
      }
    }
  }
  return $PropertyTable
}

Function Invoke-CommonGet {
  [CmdletBinding()]
  param (
    [String]$Provider,
    [String]$ResourceType,
    [String]$SearchProfile,
    [String]$Region,
    [String]$Service,
    [String]$Command,
    [String]$Filter,
    [String]$Query,
    [Switch]$Summary,
    [String[]]$Properties
  )
  switch ($Provider) {
    'AWS' {
      $Objects = aws --profile $SearchProfile --region $Region $Service $Command --filter $Filter --query $Query --output json | ConvertFrom-Json

      foreach($Object in $Objects) {
        $SummaryObject = [Ordered]@{
          Provider     = $Provider
          Region       = $Region
          ResourceType = $ResourceType
          Profile      = $SearchProfile
        }
        if ($Summary) {
          # Summary will contain only a handful of properties, See Core/Resource/Get-Resource
          foreach ($Property in $Properties) {
            $SummaryObject.$Property = $Object.$Property
          }
          # Object tags are specifically extracted
          $Object.Tags | ForEach-Object { $SummaryObject[$_.Key] = $_.Value }
          Write-Output ([PSCustomObject]$SummaryObject)
        }
        else {
          # Convert object from psobject to more basic type for terminal
          $Object = Format-CommonResource $Object

          # Copy over all the properties
          foreach($Property in ($Object.Keys | Sort-Object)) {
            $SummaryObject.$Property = $Object.$Property
          }
          Write-Output ([PSCustomObject]$SummaryObject)
        }
      }
    }
    default { throw "Provider [$Provider] is currently not supported" }
  }
}

Function Invoke-CommonGetHelp {
  [CmdletBinding()]
  param (
    $Provider,
    $ResourceType,
    $Service,
    $Command
  )
  $Helper = @{
    Providers     = (Get-Command -Name Get-ResourceHelp).Parameters['Provider'].Attributes.ValidValues
    ResourceTypes = (Get-Command -Name Get-ResourceHelp).Parameters['ResourceType'].Attributes.ValidValues
    FilterType    = $ResourceType
  }
  switch ($Provider) {
    'AWS' {
      $HelpFilters = aws $Service $Command help |
        Select-String '^   \* "(.+)" -' | Select-Object -ExpandProperty Matches |
        Select-Object -ExpandProperty Groups | Where-Object Name -eq 1 |
        Select-Object -ExpandProperty Value
      $Helper.Filters    = $HelpFilters
      switch ($ResourceType) {
        'VirtualMachine' {
          $Helper.Example = "resource -t vm -f 'tag:schedule=* * * * *','tag:description=nginx reverse proxy' -p production,development"
        }
        'BlockStorage' {
          $Helper.Example = "resource -t blocks -f 'size=200','tag:backup=0 */1 * * *' -p production, development"            
        }
      }
    }
  }
  [PSCustomObject]@{
    Providers     = $Helper.Providers
    ResourceTypes = $Helper.ResourceTypes
    FilterType    = $Helper.FilterType
    Filters       = $Helper.Filters
    Example       = $Helper.Example
  }
}