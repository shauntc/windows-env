param(
    [parameter(Position=0,Mandatory=$false)][string]$ConfigFile=$(Resolve-Path "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\..\psconfig.json")
)

$CmdColors = @{
	fg = @{
		white = "37"
		red = "31"
		green = "32"
		blue = "34"
		grey = "90"
	}
	bg = @{
		green = "42"
		red = "41"
		blue = "44"
	}
}

class Shauntc { # This class is pointless and really should be broken up
	# Class Variables and Methods
	static [string] $fg_white = "37";
	static [string] $fg_red = "31";
	static [string] $fg_green = "32";
	static [string] $fg_blue = "34";
	static [string] $fg_grey = "90";

	static [string] $bg_green = "42";
	static [string] $bg_red = "41";
	static [string] $bg_blue = "44";

	static [string] GetStyledString([string]$string, [string[]]$styles) {
		return "[" + [string]::Join(";", $styles) + "m" + $string + "[0m";
	}

	# Instance Variables and Methods
	[string[]] $Functions;

	[string] $ConfigName = "shauntc";

	[bool] $UsePrompt = $true;
	[bool] $HistoryCount = 10000

	[bool] $IsAdmin = $false;

	[bool] $PrintCommands = $true;
	[bool] $PrintConfig = $false;

	[bool] $UseBashCommands = $true;
	[bool] $UseConvenienceCommands = $true;
	[bool] $UseVisualStudioCommands = $true;

	[hashtable] $PromptConfig = @{
		Git = $true;
		Time = $true;
		Admin = $true;
	}

	[hashtable] $KeyHandlers = @{
        UpArrow = "HistorySearchBackward";
        DownArrow = "HistorySearchForward";
        Tab = "MenuComplete";
	};

	[hashtable] $FunctionAlias = @{}
	
	$config;

	Shauntc($config) {
		if($config) { $this.ParseConfig($config); }
		$this.IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator");
		$this.Functions = @();
	}

	[void] ParseConfig($config) {
		$this.config = $config;
		if($($config.PSobject.Properties.name -Match "name")) { $this.ConfigName = $config.name;  }
		if($($config.PSobject.Properties.name -Match "historyLength")) { $this.HistoryCount = $config.historyLength;  }
		if($($config.PSobject.Properties.name -Match "usePrompt")) { $this.UsePrompt = $config.usePrompt;  }
		if($($config.PSobject.Properties.name -Match "printCommands")) { $this.PrintCommands = $config.printCommands;  }
		if($($config.PSobject.Properties.name -Match "printConfig")) { $this.PrintConfig = $config.printConfig;  }
		if($($config.PSobject.Properties.name -Match "bashCommands")) { $this.UseBashCommands = $config.bashCommands;  }
		if($($config.PSobject.Properties.name -Match "convenienceCommands")) { $this.UseConvenienceCommands = $config.convenienceCommands;  }
		if($($config.PSobject.Properties.name -Match "vsCommands")) { $this.UseVisualStudioCommands = $config.vsCommands;  }
		if($($config.PSobject.Properties.name -Match "prompt")) {
			if($($config.prompt.PSobject.Properties.name -Match "admin")) { $this.PromptConfig.Admin = $config.prompt.admin;  }
			if($($config.prompt.PSobject.Properties.name -Match "time")) { $this.PromptConfig.Time = $config.prompt.time;  }
			if($($config.prompt.PSobject.Properties.name -Match "git")) { $this.PromptConfig.Git = $config.prompt.git;  }
		}
		if($($config.PSobject.Properties.name -Match "keyBindings")) { 
			foreach ( $key in $($config.keyBindings | Get-Member -MemberType Properties).Name ) {
				$this.KeyHandlers[$key] = $config.keyBindings.$key;
			}
		}
		if($($config.PSobject.Properties.name -Match "functionAlias")) { 
			foreach ( $key in $($config.functionAlias | Get-Member -MemberType Properties).Name ) {
				$this.FunctionAlias[$key] = $config.functionAlias.$key;
			}
		}
	}

	[string] GetInitMessage() {
		$initMessage = [Shauntc]::GetStyledString(" Powershell\$($this.ConfigName) ", @( [Shauntc]::fg_white, [Shauntc]::bg_blue ));
		if ($this.IsAdmin) {
			$initMessage += [Shauntc]::GetStyledString(" Admin\$env:username ", @( [Shauntc]::fg_white, [Shauntc]::bg_red));
		} else {
			$initMessage += [Shauntc]::GetStyledString(" User\$env:username ", @([Shauntc]::fg_white, [Shauntc]::bg_green));
		}

		if($this.PrintConfig) {
			$initMessage += "`n";
			$initMessage += $this.GetConfigString();	
		}
		if($this.PrintCommands) {
			$initMessage += "`n";
			$initMessage += $this.GetFunctionString();	
		}
		return $initMessage;
	}

	[string] GetConfigString() {
		return "[Debug] Config: $($this.config)"
	}

	[void] AddFunction($function) {
		$this.Functions += $function;
	}
	[string] GetFunctionString() {
		[array]::sort($this.Functions);
		$message = "";
		$bufferSize = [console]::BufferWidth;
		$stringBuffer = "  $([Shauntc]::name) Module Commands: ";
		foreach ( $fnName in $this.Functions) {
			$formattedName = "$fnName, ";
			$length = $formattedName.Length + $stringBuffer.Length + [console]::CursorLeft;
			if($length -gt $bufferSize) {
				$message += "$stringBuffer`n    ";
				$stringBuffer = "";
			}
			$stringBuffer += $formattedName;
		}
		$message += $stringBuffer.Trim(", ");
		return $message;
	}



	[string] GetPromptString([int] $nestingLevel) {
		$promptString = ""
		if($this.PromptConfig.Admin) { $promptString += $this.PromptAdmin(); }
		if($this.PromptConfig.Time) { $promptString += $this.PromptTimestamp(); }
		if($this.PromptConfig.Git) { $promptString += $this.PromptGit(); }
		$promptString += " $($this.PromptLocation())`n";
		$promptString += $this.PromptCursor($nestingLevel);
		return $promptString;
	}

	[string] PromptGit() {
		$gitBranch = $(git symbolic-ref --short HEAD);
		if($gitBranch) {
			$gitString = "";
			$gitStatus = $(git status --porcelain);
			if($gitStatus) {
				$gitString += "[" + [Shauntc]::GetStyledString("*" + $gitBranch, @([Shauntc]::fg_red)) + "]";
			} elseif ($gitBranch) {
				$gitString = "[" + [Shauntc]::GetStyledString($gitBranch, @([Shauntc]::fg_green)) + "]";
			}
			return $gitString;
		} else {
			return ""
		}
	}

	[string] PromptTimestamp() {
		return [Shauntc]::GetStyledString("[$(Get-Date -UFormat "%T")]", @([Shauntc]::fg_grey));
	}
	
	[string] PromptLocation() {
		return "$(Get-Location)"
	}

	[string] PromptAdmin() {
		if ($this.IsAdmin) {
			return [Shauntc]::GetStyledString("[A]", @([Shauntc]::fg_red));
		} else {
			return [Shauntc]::GetStyledString("[U]", @([Shauntc]::fg_green));
		}
	}

	[string] PromptCursor($nestLevel) {
		$cursorString = "PS";
		for($i=0; $i -le $nestLevel; $i++) {
			$cursorString += ">"
		}
		return [Shauntc]::GetStyledString($cursorString, @([Shauntc]::fg_blue));
	}
}

$config;
if(Test-Path($ConfigFile)) {
	$config = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json;	
} else {
	Write-Host "Unable to find config at $ConfigFile"
}
$shauntc = [Shauntc]::new($config);


if($shauntc.UsePrompt) {
	function Prompt {
		return $shauntc.GetPromptString($NestedPromptLevel);
	}
}

# Increase history
$MaximumHistoryCount = $shauntc.HistoryCount;

# Produce UTF-8 by default
$PSDefaultParameterValues["Out-File:Encoding"]="utf8"

# Show selection menu for tab
# Set-PSReadlineKeyHandler -Chord Tab -Function MenuComplete
# Set-PSReadlineKeyHandler -Chord UpArrow -Function HistorySearchBackward
# Set-PSReadlineKeyHandler -Chord DownArrow -Function HistorySearchForward
foreach ($key in $shauntc.KeyHandlers.Keys ) {
	Set-PSReadlineKeyHandler -Chord $key -Function $shauntc.KeyHandlers.Item($key);
}

# Visual Studio Functions
#######################################################
if($shauntc.UseVisualStudioCommands) {
	$VisualStudioPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Enterprise";
	if(Test-Path($VisualStudioPath)) {
		function vs {
			Param(
				[parameter(
					Position = 0,
					ParameterSetName = "Solution"
				)]
				[String] $SolutionPath,
				[parameter(
					ValueFromRemainingArguments = $true
				)]
				[String[]]
				$RemainingArgs
			)

			if($SolutionPath) {
				$inputPath = $SolutionPath;
				if ($SolutionPath -eq '.') {
					$SolutionPath = '*.sln'
				}
				$SolutionPath = Resolve-Path $SolutionPath

				if([System.IO.File]::Exists($SolutionPath)) {
					Write-Host "Visual Studio opening $SolutionPath with args $RemainingArgs";
					& "${VisualStudioPath}\Common7\IDE\devenv.exe" $SolutionPath $RemainingArgs;
				} else {
					Write-Host "Error: No Solution found for path: $inputPath" -BackgroundColor Red;
				}
			} else {
				Write-Host "Open Visual Studio $RemainingArgs";
				& "${VisualStudioPath}\Common7\IDE\devenv.exe" $RemainingArgs;
			}
		}

		function avs {
			Param(
				[parameter(
					Position = 0,
					ParameterSetName = "Solution"
				)]
				[String] $SolutionPath,
				[parameter(
					ValueFromRemainingArguments = $true
				)]
				[String[]]
				$RemainingArgs
			)

			if($SolutionPath) {
				$inputPath = $SolutionPath;
				if ($SolutionPath -eq '.') {
					$SolutionPath = '*.sln'
				}
				$SolutionPath = Resolve-Path $SolutionPath

				if([System.IO.File]::Exists($SolutionPath)) {
					Write-Host "Visual Studio opening $SolutionPath $RemainingArgs";
					$newProcess = new-object System.Diagnostics.ProcessStartInfo "${VisualStudioPath}\Common7\IDE\devenv.exe";
					$newProcess.Arguments = $RemainingArgs;
					$newProcess.Verb = "runas";
					[System.Diagnostics.Process]::Start($newProcess);
				} else {
					Write-Host "Error: No Solution found for path: $inputPath" -BackgroundColor Red;
				}
			} else {
				Write-Host "Open Visual Studio $RemainingArgs";
				$newProcess = new-object System.Diagnostics.ProcessStartInfo "${VisualStudioPath}\Common7\IDE\devenv.exe";
				$newProcess.Arguments = $RemainingArgs;
				$newProcess.Verb = "runas";
				[System.Diagnostics.Process]::Start($newProcess);
			}
		}
		
		function vscmd {
			$vsBatPath = "${VisualStudioPath}\Common7\Tools\VsDevCmd.bat"
			if([System.IO.File]::Exists($vsBatPath)) {
				$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator");
				if($isAdmin) {
					Write-Host "Prompt has correct permissions, opening inline" -BackgroundColor Green;
					cmd /k "$vsBatPath";
				} else {
					Write-Host "Elevated Permissions Required, Opening new window" -BackgroundColor Red;
					$newProcess = new-object System.Diagnostics.ProcessStartInfo "cmd";
					$newProcess.Arguments = "/k `"$vsBatPath`"";
					$newProcess.Verb = "runas";
					[System.Diagnostics.Process]::Start($newProcess);
				}
			} else {
				Write-Output "VS Dev Batch file does not exist at: $vsBatPath"
			}	
		}
	}
}

# Convenience Functions
#######################################################
if($shauntc.UseConvenienceCommands) {
	function .. {
		Set-Location ..
	}
	function ... {
		Set-Location ..\..
	}
	function .... {
		Set-Location ..\..\..
	}
	function ..... {
		Set-Location ..\..\..\..
	}
	
	function uptime { # From https://github.com/felixrieseberg/windows-development-environment
		Get-WmiObject win32_operatingsystem | Select-Object csname, @{LABEL='LastBootUpTime';
		EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}
	}
	
	function find-file($name) { # From https://github.com/felixrieseberg/windows-development-environment
		Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
			$place_path = $_.directory
			Write-Output "${place_path}\${_}"
		}
	}
	
	function get-path { # From https://github.com/felixrieseberg/windows-development-environment
		($Env:Path).Split(";")
	}
}

# Bash like commands all from https://github.com/felixrieseberg/windows-development-environment
#######################################################
if($shauntc.UseBashCommands) {
	function df {
		get-volume
	}

	function sed($file, $find, $replace){
		(Get-Content $file).replace("$find", $replace) | Set-Content $file
	}

	function sed-recursive($filePattern, $find, $replace) {
		$files = Get-ChildItem . "$filePattern" -rec
		foreach ($file in $files) {
			(Get-Content $file.PSPath) |
			Foreach-Object { $_ -replace "$find", "$replace" } |
			Set-Content $file.PSPath
		}
	}

	function grep($regex, $dir) {
		if ( $dir ) {
			Get-ChildItem $dir | select-string $regex
			return
		}
		$input | select-string $regex
	}

	function grepv($regex) {
		$input | Where-Object { !$_.Contains($regex) }
	}

	function which($name) {
		Get-Command $name | Select-Object -ExpandProperty Definition
	}

	function open($file) {
		Invoke-Item $file
	}

	function export($name, $value) {
		set-item -force -path "env:$name" -value $value;
	}

	function pkill($name) {
		Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
	}

	function pgrep($name) {
		Get-Process $name
	}

	function touch($file) {
		"" | Out-File $file -Encoding ASCII
	}

	# From https://github.com/keithbloom/powershell-profile/blob/master/Microsoft.PowerShell_profile.ps1
	function sudo {
		$file, [string]$arguments = $args;
		$psi = new-object System.Diagnostics.ProcessStartInfo $file;
		$psi.Arguments = $arguments;
		$psi.Verb = "runas";
		$psi.WorkingDirectory = get-location;
		[System.Diagnostics.Process]::Start($psi) >> $null
	}

	# https://gist.github.com/aroben/5542538
	function pstree {
		$ProcessesById = @{}
		foreach ($Process in (Get-WMIObject -Class Win32_Process)) {
			$ProcessesById[$Process.ProcessId] = $Process
		}

		$ProcessesWithoutParents = @()
		$ProcessesByParent = @{}
		foreach ($Pair in $ProcessesById.GetEnumerator()) {
			$Process = $Pair.Value

			if (($Process.ParentProcessId -eq 0) -or !$ProcessesById.ContainsKey($Process.ParentProcessId)) {
				$ProcessesWithoutParents += $Process
				continue
			}

			if (!$ProcessesByParent.ContainsKey($Process.ParentProcessId)) {
				$ProcessesByParent[$Process.ParentProcessId] = @()
			}
			$Siblings = $ProcessesByParent[$Process.ParentProcessId]
			$Siblings += $Process
			$ProcessesByParent[$Process.ParentProcessId] = $Siblings
		}

		function Show-ProcessTree([UInt32]$ProcessId, $IndentLevel) {
			$Process = $ProcessesById[$ProcessId]
			$Indent = " " * $IndentLevel
			if ($Process.CommandLine) {
				$Description = $Process.CommandLine
			} else {
				$Description = $Process.Caption
			}

			Write-Output ("{0,6}{1} {2}" -f $Process.ProcessId, $Indent, $Description)
			foreach ($Child in ($ProcessesByParent[$ProcessId] | Sort-Object CreationDate)) {
				Show-ProcessTree $Child.ProcessId ($IndentLevel + 4)
			}
		}

		Write-Output ("{0,6} {1}" -f "PID", "Command Line")
		Write-Output ("{0,6} {1}" -f "---", "------------")

		foreach ($Process in ($ProcessesWithoutParents | Sort-Object CreationDate)) {
			Show-ProcessTree $Process.ProcessId 0
		}
	}

	function unzip ($file) {
		$dirname = (Get-Item $file).Basename
		Write-Output("Extracting", $file, "to", $dirname)
		New-Item -Force -ItemType directory -Path $dirname
		expand-archive $file -OutputPath $dirname -ShowProgress
	}
}

# Custom functions are defined last to ensure no name clashing ones are created
if($shauntc.FunctionAlias.Count -ne 0) {
	$scriptPath = $(Split-Path -Parent $MyInvocation.MyCommand.Path);
	$genPath = "$scriptPath\gen"
	if(-Not(Test-Path($genPath))) {
		mkdir $genPath;
	}
	$fnFileName = "_customFunctions.psm1";
	$fnFilePath = "$genPath\$fnFileName";
	if(Test-Path($fnFilePath)) {
		Remove-Item $fnFilePath; # Ensure we create a new file each time
	}
	New-Item -Path $genPath -Name $fnFileName  -ItemType "file"
	foreach ($key in $shauntc.FunctionAlias.Keys ) {
		if(Get-Command $key -errorAction SilentlyContinue) {
			Write-Host "Command '$key' already exists, please choose another name";
		} else {
			$value = $shauntc.FunctionAlias.Item($key);
			$functionDefn = "function $key {`n`t$value @args;`n}`n";
			Out-File -FilePath $fnFilePath -InputObject $functionDefn -Append;
			$shauntc.AddFunction($key);
		}
	}
	Import-Module $fnFilePath

	#clean up the generated file/folder after importing the functions
	Remove-Item $fnFilePath
	Remove-Item $genPath
}

$shauntc.AddFunction($(Get-Command -Module ps_profile));
Write-Host $shauntc.GetInitMessage();

$profile_config = $ConfigFile;
Export-ModuleMember -Function * -Variable profile_config