$ErrorActionPreference = 'Stop'
$Godot = 'C:\Users\Nenad\Desktop\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$ProjectPath = (Resolve-Path "$PSScriptRoot\..").ProviderPath
& $Godot --headless --path $ProjectPath --import
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}
& $Godot --headless --path $ProjectPath -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
exit $LASTEXITCODE
