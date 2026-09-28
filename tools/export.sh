#!/usr/bin/env bash
# Автоматическая сборка BALLISTIK через Godot CLI (Linux / macOS / Git Bash).
#
#   ./tools/export.sh [--godot PATH] [--targets "linux windows android"] [--mode release|debug]
#                     [--install-templates] [--skip-tests]
#
# Результат:  build/windows/BALLISTIK.exe, build/linux/BALLISTIK.x86_64, build/android/BALLISTIK.apk,
#             build/ios/BALLISTIK.xcodeproj (только при явном --targets ios)
#
# Android: нужны OpenJDK 17 и Android SDK (platform-tools, build-tools 35.0.1, platforms;android-35).
# Пути берутся из JAVA_HOME и ANDROID_HOME (или из настроек редактора Godot).
# Release-APK подписывается ключом из GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD,
# debug-APK — отладочным ключом редактора или GODOT_ANDROID_KEYSTORE_DEBUG_PATH / _USER / _PASSWORD.
# iOS: Godot создаёт проект Xcode, на iPhone его ставят из Xcode на macOS (README, «Запуск на iPhone»).
set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_RELEASE="stable"
GODOT_BIN="${GODOT:-godot}"
MODE="release"
TARGETS="linux windows android"
INSTALL_TEMPLATES=0
SKIP_TESTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot) GODOT_BIN="$2"; shift 2 ;;
    --targets) TARGETS="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --install-templates) INSTALL_TEMPLATES=1; shift ;;
    --skip-tests) SKIP_TESTS=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "Неизвестный параметр: $1" >&2; exit 2 ;;
  esac
done

if [[ "$MODE" != "release" && "$MODE" != "debug" ]]; then
  echo "--mode должен быть release или debug" >&2
  exit 2
fi

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot $GODOT_VERSION не найден. Укажите --godot /path/to/Godot_v${GODOT_VERSION}-stable_linux.x86_64 или переменную GODOT." >&2
  exit 1
fi
VERSION_TEXT="$("$GODOT_BIN" --version | head -n 1)"
step "Godot: $GODOT_BIN ($VERSION_TEXT)"
if [[ "$VERSION_TEXT" != "$GODOT_VERSION.$GODOT_RELEASE"* ]]; then
  echo "Внимание: ожидается Godot $GODOT_VERSION-$GODOT_RELEASE — версия шаблонов экспорта должна совпадать с редактором." >&2
fi

# --- Шаблоны экспорта ------------------------------------------------------------------------------
case "$(uname -s)" in
  Darwin) DATA_DIR="$HOME/Library/Application Support/Godot" ;;
  MINGW*|MSYS*|CYGWIN*) DATA_DIR="$APPDATA/Godot" ;;
  *) DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot" ;;
esac
GODOT_DIR="$(cd "$(dirname "$(command -v "$GODOT_BIN" || echo "$GODOT_BIN")")" && pwd)"
if [[ -f "$GODOT_DIR/_sc_" || -f "$GODOT_DIR/._sc_" ]]; then
  DATA_DIR="$GODOT_DIR/editor_data"
fi
TEMPLATES_DIR="$DATA_DIR/export_templates/$GODOT_VERSION.$GODOT_RELEASE"

if [[ ! -f "$TEMPLATES_DIR/linux_release.x86_64" ]]; then
  if [[ "$INSTALL_TEMPLATES" -ne 1 ]]; then
    echo "Шаблоны экспорта не найдены в '$TEMPLATES_DIR'. Запустите с --install-templates или установите их в редакторе (Editor > Manage Export Templates)." >&2
    exit 1
  fi
  step "Загрузка шаблонов экспорта $GODOT_VERSION -> $TEMPLATES_DIR"
  TMP_DIR="$(mktemp -d)"
  URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_export_templates.tpz"
  curl -fL --retry 3 -o "$TMP_DIR/templates.tpz" "$URL"
  unzip -q "$TMP_DIR/templates.tpz" -d "$TMP_DIR"
  mkdir -p "$TEMPLATES_DIR"
  cp -R "$TMP_DIR/templates/." "$TEMPLATES_DIR/"
  rm -rf "$TMP_DIR"
fi

# --- Импорт, проверки, экспорт ---------------------------------------------------------------------
cd "$PROJECT_DIR"
step "Импорт проекта"
"$GODOT_BIN" --headless --path . --import

if [[ "$SKIP_TESTS" -ne 1 ]]; then
  step "Компиляция всех скриптов"
  "$GODOT_BIN" --headless --path . res://tests/compile_check.tscn
fi

for target in $TARGETS; do
  RESULT=""
  case "$target" in
    windows) PRESET="Windows Desktop"; OUT="build/windows/BALLISTIK.exe" ;;
    linux) PRESET="Linux"; OUT="build/linux/BALLISTIK.x86_64" ;;
    android)
      PRESET="Android"; OUT="build/android/BALLISTIK.apk"
      [[ "$MODE" == "debug" ]] && OUT="build/android/BALLISTIK-debug.apk"
      ;;
    # Пресет iOS экспортирует только проект Xcode (Export Project Only).
    ios) PRESET="iOS"; OUT="build/ios/BALLISTIK.ipa"; RESULT="build/ios/BALLISTIK.xcodeproj" ;;
    *) echo "Неизвестная платформа: $target (windows, linux, android, ios)" >&2; exit 2 ;;
  esac
  RESULT="${RESULT:-$OUT}"
  mkdir -p "$(dirname "$OUT")"
  rm -rf "$RESULT"
  step "Экспорт: $PRESET ($MODE) -> $OUT"
  "$GODOT_BIN" --headless --path . "--export-$MODE" "$PRESET" "$OUT"
  if [[ ! -e "$RESULT" ]]; then
    echo "Сборка '$PRESET' не удалась — смотрите вывод Godot выше." >&2
    exit 1
  fi
  printf '\033[32mГотово: %s (%s)\033[0m\n' "$RESULT" "$(du -sh "$RESULT" | cut -f1)"
done
