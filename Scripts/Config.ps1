Get-ResourceAccounts | sort -property Name |
%{
$awsprofile = @(
    "[profile $($_.name)]"
    "role_arn       = arn:aws:iam::$($_.id):role/OrganizationAccountAccessRole"
    'region         = us-west-2'
    'output         = yaml'
    'source_profile = default'
) -join "`r`n"
Write-Output $awsprofile, ''
}