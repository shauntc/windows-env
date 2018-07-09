# This only runs when launched from %tools%/windows-env/shortcuts
if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){
    # Has Admin Privilages
    Set-Location $env:windir
} else {
    # Does not have Admin Privilages
    Set-Location ~ 
}