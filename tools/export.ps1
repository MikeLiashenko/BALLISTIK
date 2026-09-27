<#
.SYNOPSIS
  Автоматическая сборка BALLISTIK через Godot CLI (Windows PowerShell 5.1+ / PowerShell 7).

.DESCRIPTION
  1. Находит Godot 4.7.2 (параметр -Godot, переменная окружения GODOT или godot в PATH).
  2. Проверяет шаблоны экспорта (при -InstallTemplates скачивает официальный .tpz с GitHub).
  3. Импортирует проект, компилирует все скрипты (tests/compile_check.tscn).
  4. Экспортирует выбранные платформы по пресетам из export_presets.cfg:
       windows -> build/windows/BALLISTIK.exe
       linux   -> build/linux/BALLISTIK.x86_64
       android -> build/android/BALLISTIK.apk

.EXAMPLE
  .\tools\export.ps1 -Godot "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" -Targets windows,android

.EXAMPLE
  .\tools\export.ps1 -Targets windows,linux,android -Mode debug -InstallTemplates

.NOTES
  Android: нужны OpenJDK 17 и Android SDK (platform-tools, build-tools 35.0.1, platforms;android-35).
  Пути берутся из переменных JAVA_HOME и ANDROID_HOME (или из настроек редактора Godot).
  Release-APK подписывается ключом из переменных окружения:
    GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
  Debug-APK подписывается отладочным ключом редактора (создаётся автоматически) или
    GODOT_ANDROID_KEYSTORE_DEBUG_PATH / _USER / _PASSWORD.
#>
param(
    [string]$Godot = $env:GODOT,
    [string[]]$Targets = @("windows", "android"),
    [ValidateSet("release", "debug")]
    [string]$Mode = "release",
    [switch]$InstallTemplates,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$GodotVersion = "4.7.2"
$GodotRelease = "stable"
$ProjectDir = Split-Path -Parent $PSScriptRoot

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

# --- Godot ---------------------------------------------------------------------------------------
if (-not $Godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $Godot = $cmd.Source }
}
if (-not $Godot -or -not (Test-Path $Godot)) {
    throw "Godot $GodotVersion не найден. Укажите -Godot 'C:\path\Godot_v$GodotVersion-stable_win64_console.exe' или переменную окружения GODOT."
}
$versionText = (& $Godot --version) | Select-Object -First 1
Write-Step "Godot: $Godot ($versionText)"
if ($versionText -notlike "$GodotVersion.$GodotRelease*") {
    Write-Warning "Ожидается Godot $GodotVersion-$GodotRelease — версия шаблонов экспорта должна совпадать с версией редактора."
}

# --- Шаблоны экспорта ----------------------------------------------------------------------------
$godotDir = Split-Path -Parent (Resolve-Path $Godot)
$selfContained = (Test-Path (Join-Path $godotDir "_sc_")) -or (Test-Path (Join-Path $godotDir "._sc_"))
if ($selfContained) {
    $templatesDir = Join-Path $godotDir "editor_data\export_templates\$GodotVersion.$GodotRelease"
} else {
    $templatesDir = Join-Path $env:APPDATA "Godot\export_templates\$GodotVersion.$GodotRelease"
}
$marker = Join-Path $templatesDir "windows_release_x86_64.exe"
if (-not (Test-Path $marker)) {
    if (-not $InstallTemplates) {
        throw "Шаблоны экспорта не найдены в '$templatesDir'. Запустите скрипт с -InstallTemplates или установите их в редакторе: Editor > Manage Export Templates."
    }
    Write-Step "Загрузка шаблонов экспорта $GodotVersion ($templatesDir)"
    $url = "https://github.com/godotengine/godot/releases/download/$GodotVersion-$GodotRelease/Godot_v$GodotVersion-$($GodotRelease)_export_templates.tpz"
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "ballistik_templates"
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $zip = Join-Path $tmp "templates.zip"
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force $templatesDir | Out-Null
    Copy-Item -Path (Join-Path $tmp "templates\*") -Destination $templatesDir -Recurse -Force
    Remove-Item -Recurse -Force $tmp
}

# --- Импорт и проверки ---------------------------------------------------------------------------
Push-Location $ProjectDir
try {
    Write-Step "Импорт проекта"
    & $Godot --headless --path . --import
    if (-not $SkipTests) {
        Write-Step "Компиляция всех скриптов"
        & $Godot --headless --path . res://tests/compile_check.tscn
        if ($LASTEXITCODE -ne 0) { throw "Ошибки компиляции скриптов." }
    }

    # --- Экспорт ---------------------------------------------------------------------------------
    $presets = @{
        "windows" = @("Windows Desktop", "build/windows/BALLISTIK.exe")
        "linux"   = @("Linux", "build/linux/BALLISTIK.x86_64")
        "android" = @("Android", "build/android/BALLISTIK.apk")
    }
    foreach ($t in $Targets) {
        $key = $t.ToLowerInvariant()
        if (-not $presets.ContainsKey($key)) { throw "Неизвестная платформа '$t' (допустимо: windows, linux, android)." }
        $preset = $presets[$key][0]
        $out = $presets[$key][1]
        if ($key -eq "android" -and $Mode -eq "debug") { $out = "build/android/BALLISTIK-debug.apk" }
        New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
        if (Test-Path $out) { Remove-Item -Force $out }
        Write-Step "Экспорт: $preset ($Mode) -> $out"
        & $Godot --headless --path . "--export-$Mode" $preset $out
        if (-not (Test-Path $out)) { throw "Сборка '$preset' не удалась — смотрите вывод Godot выше." }
        $size = [math]::Round((Get-Item $out).Length / 1MB, 1)
        Write-Host "Готово: $out ($size МБ)" -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
