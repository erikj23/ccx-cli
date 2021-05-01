
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
          # Summary will contain only a handful of properties, See Support/Utility/Get-Resource
          foreach ($Property in $Properties) {
            $SummaryObject.$Property = $Object.$Property
          }
          # Object tags are specifically extracted
          $Object.Tags | ForEach-Object { $SummaryObject[$_.Key] = $_.Value }
          Write-Output ([PSCustomObject]$SummaryObject)
        }
        else {
          # Convert object from psobject to more basic type for terminal
          $Object = Format-Resource $Object
          
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
