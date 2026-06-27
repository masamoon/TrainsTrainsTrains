param(
	[string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Find-Godot {
	param([string]$Preferred)
	if ($Preferred -and (Test-Path -LiteralPath $Preferred)) {
		return (Resolve-Path -LiteralPath $Preferred).Path
	}
	foreach ($name in @("godot", "godot4", "godot4.5")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) {
			return $cmd.Source
		}
	}
	$desktopGodot = Join-Path $env:USERPROFILE "Desktop\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
	if (Test-Path -LiteralPath $desktopGodot) {
		return (Resolve-Path -LiteralPath $desktopGodot).Path
	}
	throw "Godot executable not found. Install Godot 4.5 or set GODOT_BIN to the full Godot executable path."
}

$godot = Find-Godot $GodotBin
Write-Host "Using Godot: $godot"
& $godot --headless --path $repoRoot --script "res://scripts/SmokeTest.gd"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}
