
Function Format-Resource {
  [CmdletBinding()]
  param (
    [PSCustomObject]$Object    
  )
  $PropertyTable = [HashTable]@{}
  foreach($PropertyName in $Object.PSObject.Properties.Name) {
    switch ($Object.$PropertyName.GetType().Name.ToString()) {
      'PSCustomObject' {        
        $PropertyTable[$PropertyName] = Format-Resource $Object.$PropertyName
        break     
      }
      'Object[]' {
        if ((Assert-Properties $Object.$PropertyName[0] -Properties 'Key','Value' -TotalCount 2) -eq $true) {
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
            $PropertyArray[$Index] = Format-Resource $SubProperty
            $Index += 1
          }
          $PropertyTable[$PropertyName] = $PropertyArray
        }
        break
      }
      default {
        $PropertyTable[$PropertyName] = $Object.$PropertyName
        break
      }
    }
    # problem is that entry object does     
  }
  return $PropertyTable
}

Function Assert-Properties {
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

$base = aws --profile production ec2 describe-instances --filter "Name=tag:Name,Values=awolpaxon01v01.puget.com" --query "Reservations[].Instances[]"  --output json | convertfrom-json

Format-Resource $base | Sort-Object
