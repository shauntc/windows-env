# windows-env
Windows Environment set-up for a dev coming from MacOS

install [Chocolatey](https://chocolatey.org/)

install [WOX](https://github.com/Wox-launcher/Wox)
Wox -> Settings -> Plugin -> Program -> Add ( windows-env\shortcuts )

install [VSCode](https://visualstudio.microsoft.com/) and [Visual Studios](https://visualstudio.microsoft.com/)

#### Powershell Config:
From Powershell (open the powershell profile):
```powershell
ii $profile
```
Add to the file, setting PATH_TO_REPO_ROOT (import the windows-env ps_profile module):
```powershell
# Set the profile module path
$ProfileModule = "PATH_TO_REPO_ROOT\windows-env\.config\ps_profile.psm1"
# ie. "C:\tools\windows-env\.config\ps_profile.psm1"
if (Test-Path($ProfileModule)) { # Test if it exists
  # Import the module
  # Add: '-ArgumentList "PATH_TO(psconfig.json)"' if you want a custom psconfig location
  # Default location is windows-env\psconfig.json
  Import-Module "$ProfileModule" -DisableNameChecking
} else { # Warn if fails to load
	Write-Host "Failed to load profile module from $ProfileModule" -BackgroundColor Red;
}
```
