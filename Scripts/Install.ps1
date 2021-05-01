if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $RepoPath = Read-Host -Prompt 'Enter local path to module (cloned in ~/git ex: ~/git/aws-tools)'
    
    if (Test-Path $RepoPath) {
        # Convert to absolute path
        $RepoPath = Convert-Path $RepoPath
    
        # Create a directory junction in the powershell modules location to the repo
        New-Item -ItemType Junction -Path $env:USERPROFILE\Documents\Powershell\Modules\CCX-CLI -Target $RepoPath
    }
}
else {
    Write-Error ((
        @(
            'This script requires administrator privileges to create a directory junction'
            "`tNew-Item -ItemType Junction -Path $env:USERPROFILE\Documents\Powershell\Modules\PSEResource -Target \PATH\TO\THIS\REPO"
        ) -join "`r`n"
    ) -replace '\\','/')
}

