param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GodotArgs)
$ErrorActionPreference = 'Stop'
$Godot = 'C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $Godot --path (Resolve-Path "$PSScriptRoot\..").ProviderPath @GodotArgs
exit $LASTEXITCODE
