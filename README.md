[chocolatey-install]: https://chocolatey.org/
[wox-install]: https://github.com/Wox-launcher/Wox
[vscode-install]: https://visualstudio.microsoft.com/
[vs-install]: https://visualstudio.microsoft.com/
[ps-keyhandlers]: https://docs.microsoft.com/en-us/powershell/module/psreadline/set-psreadlinekeyhandler?view=powershell-6
[windows-dev-env]: https://github.com/felixrieseberg/windows-development-environment

# windows-env
Windows Environment set-up for a dev coming from MacOS, extension of [felixrieseberg's][windows-dev-env]

install [Chocolatey][chocolatey-install]

install [WOX][wox-install]

install [VSCode][vscode-install] and [Visual Studios][vs-install]


### PS/CMD Shortcuts for Wox:
**/shortcuts** contains shortcuts for cmd/ps and launching as admin (a_cmd/a_ps) as well as getting into the visual studio cmd prompt
<br/>Wox -> Settings -> Plugin -> Program -> Add ( windows-env\shortcuts )

### Powershell Config:
From Powershell:
```powershell
ii $profile
```
This will open your powershell profile

Add the following to your powershell profile<br/>
* {path to repo} = the path to where this repo is
* {path to psconfig} = A custom path to psconfig.json if desired (defaults to windows-env/psconfig.json)

```powershell
# Set the profile module path
$ProfileModule = "{path to repo}\windows-env\.config\ps_profile.psm1"
# ie. "C:\tools\windows-env\.config\ps_profile.psm1"
if (Test-Path($ProfileModule)) { # Test if it exists
  # Import the module
  # Add: '-ArgumentList {path to psconfig}' if you want a custom psconfig location
  Import-Module "$ProfileModule" -DisableNameChecking
} else { # Warn if fails to load
	Write-Host "Failed to load profile module from $ProfileModule" -BackgroundColor Red;
}
```

edit windows-env/psconfig.json to change the powershell profile settings

```javascript
{
    "name": "shauntc", // Profile name (doesnt really do anything)

    "historyLength": 10000,
    "usePrompt": true, // Use the custom prompt
    "prompt": {
        "git": true, // Show status of git repos in the prompt
        "time": true, // Show timestamps in the prompt
        "admin": true // Show if prompt is in admin mode or user mode
    },
    "keyBindings": { 
        // List of powershell keybindings
        "UpArrow": "HistorySearchBackward",
        "DownArrow": "HistorySearchForward",
        "Tab": "MenuComplete"
    },
    "functionAlias": {
        // Function bindings
        // These will fail if they clash with currently available commands
        // ie. this will not rebind cd, it will just skip it
        // Currently these can only be one line functions
        // function inputs will be passed at the end of the command
        // ie calling 'home -Verbose' => 'cd $env:USERPROFILE -Verbose' 
        "home": "cd $env:USERPROFILE"
    },

    // Print a list of the commands added by this profile
    // I prefer to have this on so I know what I'm using that is not stock
    "printCommands": true, 

    // Enables/Disables sets of commands
    "bashCommands": true, // bash like commands
    "vsCommands": true, // vs, vscmd
    "convenienceCommands": true // .., ..., get-path, etc
}
```
For a list of possible keybindings see [Set-PSReadlineKeyHandler][ps-keyhandlers]