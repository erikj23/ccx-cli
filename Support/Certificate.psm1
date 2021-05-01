Function Get-Certificates {
    [CmdletBinding()]
    param (
        [ValidateSet('AWS', 'Azure')]
        [String]$Provider = 'AWS',
        
        [Alias('p')]
        [String[]]$Profiles,
        
        
        [Alias('r')]
        [String[]]
        $Regions,

        [Alias('f')]
        [String]
        $Filter,

        [Switch]
        $Expired
    )
    $SearchProfiles = aws configure list-profiles
    if ($Profiles) {
        $SearchProfiles = $Profiles | Foreach-Object { $SearchProfiles | Where-Object Name -eq $_ }
    }

    $ResourceRegions = aws --profile manage ec2 describe-regions --output json --query "Regions[].{Name:RegionName}" | ConvertFrom-Json
    if ($Regions) {
        $ResourceRegions = $Regions | Foreach-Object { $ResourceRegions | Where-Object Name -eq $_ }
    }

    $SearchProfiles | Foreach-Object -Parallel {
        $SearchProfile = $_
        $Using:ResourceRegions | Foreach-Object {  
            $Region = $_
            # try to fetch all certs ACM in this region
            try   { $Certificates = aws --profile $SearchProfile acm list-certificates --output json --query "CertificateSummaryList[].{ARN:CertificateArn,DomainName:DomainName}" | ConvertFrom-Json }
            catch { $Certificates = $null }
    
            if ($Certificates) {    
                foreach ($Certificate in $Certificates) {
                    # get full cert info from AWS
                    $Certificate = aws --profile $SearchProfile acm describe-certificate --certificate-arn $Certificate.ARN --output json --query "Certificate.{ARN:CertificateArn,DomainName:DomainName,Expires:NotAfter,Resources:InUseBy,Serial:Serial}" | ConvertFrom-Json
    
                    # format cert into nice package
                    $Certificate = [PSCustomObject]@{
                        Profile    = $SearchProfile
                        ARN        = $Certificate.ARN
                        DomainName = $Certificate.DomainName
                        Expires    = (Get-Date $Certificate.Expires)
                        Expired    = $Certificate.Expires -lt (Get-Date)
                        Resources  = $Certificate.Resources -Join ';'
                        Serial     = $Certificate.Serial
                    }
                    if ($Using:Filter) {
                        $PatternMatch = $Certificate.DomainName | Select-String -Pattern $Using:Filter
                        if ($PatternMatch) {
                            if ($Using:Expired) {
                                if ($Certificate.Expired) {
                                    $Certificate                            
                                }
                            }
                            else {
                                $Certificate
                            }
                        }
                    }            
                    elseif ($Using:Expired) {
                        if ($Certificate.Expired) {
                            $Certificate
                        }
                    }
                    else {
                        $Certificate
                    }                
                }
            }
        }
    } -ThrottleLimit 8
}
Set-Alias -Name certificates -V Get-Certificates
