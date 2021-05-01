
try {
    Get-PSDrive -Name Cache -PSProvider FileSystem -ErrorAction Stop
}
catch {
    if (-not (Test-Path "~/variable/cache")) {
        New-Item "~/variable/cache" -ItemType Directory
    }
    New-PSdrive -Name Cache -PSProvider FileSystem -Root "~/variable/cache"
}
