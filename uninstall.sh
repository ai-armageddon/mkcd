#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Uninstall mkcd (macOS/Linux)

Usage:
  ./uninstall.sh [options]

Options:
  --shell zsh|bash     Override shell type for rc-file selection.
  --rc-file FILE       Explicit rc file to edit.
  --prefix DIR         Install directory (default: $XDG_DATA_HOME/mkcd or ~/.local/share/mkcd).
  --skip-rc            Do not edit shell rc files.
  --yes                Remove files without prompting.
  -h, --help           Show this help.
USAGE
}

OS="$(uname -s)"
if [[ "$OS" != "Darwin" && "$OS" != "Linux" ]]; then
  echo "error: unsupported OS: $OS (supported: macOS/Linux)" >&2
  exit 1
fi

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/mkcd"
SHELL_KIND="${SHELL##*/}"
RC_FILE=""
SKIP_RC=0
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --shell)
      [[ $# -ge 2 ]] || { echo "error: --shell requires a value" >&2; exit 1; }
      SHELL_KIND="$2"
      shift 2
      ;;
    --rc-file)
      [[ $# -ge 2 ]] || { echo "error: --rc-file requires a value" >&2; exit 1; }
      RC_FILE="$2"
      shift 2
      ;;
    --prefix)
      [[ $# -ge 2 ]] || { echo "error: --prefix requires a value" >&2; exit 1; }
      PREFIX="$2"
      shift 2
      ;;
    --skip-rc)
      SKIP_RC=1
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$RC_FILE" && "$SKIP_RC" -eq 0 ]]; then
  case "$SHELL_KIND" in
    zsh)
      RC_FILE="$HOME/.zshrc"
      ;;
    bash)
      if [[ "$OS" == "Darwin" ]]; then
        RC_FILE="$HOME/.bash_profile"
      else
        RC_FILE="$HOME/.bashrc"
      fi
      ;;
    *)
      echo "warning: unsupported shell '$SHELL_KIND'; skipping rc update" >&2
      SKIP_RC=1
      ;;
  esac
fi

TARGET_FILE="$PREFIX/mkcd.zsh"
LEGACY_ZSH_FUNC="$HOME/.zsh/functions/mkcd.zsh"
SOURCE_LINE="[ -f \"$TARGET_FILE\" ] && source \"$TARGET_FILE\""

tmp_file=""
cleanup() {
  [[ -n "$tmp_file" ]] && rm -f "$tmp_file"
}
trap cleanup EXIT

echo "This will remove:"
echo "  - $TARGET_FILE"
[[ -f "$LEGACY_ZSH_FUNC" ]] && echo "  - $LEGACY_ZSH_FUNC"
[[ "$SKIP_RC" -eq 0 ]] && echo "  - mkcd block from: $RC_FILE"

if [[ "$ASSUME_YES" -ne 1 ]]; then
  if ! read -r -p "Continue? [y/N] " answer; then
    echo "aborted" >&2
    exit 1
  fi
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

if [[ "$SKIP_RC" -eq 0 && -f "$RC_FILE" ]]; then
  if grep -q '^# mkcd$' "$RC_FILE" || grep -Fq "$SOURCE_LINE" "$RC_FILE"; then
    tmp_file="$(mktemp)"
    # Drop the "# mkcd" comment and the exact source line, then collapse
    # any runs of blank lines that this leaves behind.
    awk -v line="$SOURCE_LINE" '
      /^# mkcd$/ { next }
      $0 == line { next }
      { lines[++n] = $0 }
      END {
        for (i = 1; i <= n; i++) {
          if (lines[i] == "" && (i == 1 || lines[i-1] == "")) continue
          print lines[i]
        }
      }
    ' "$RC_FILE" > "$tmp_file"
    mv "$tmp_file" "$RC_FILE"
    tmp_file=""
    echo "removed mkcd block from $RC_FILE"
  else
    echo "info: no mkcd source line found in $RC_FILE"
  fi
fi

if [[ -f "$TARGET_FILE" ]]; then
  rm -f "$TARGET_FILE"
  echo "removed: $TARGET_FILE"
else
  echo "info: $TARGET_FILE not present"
fi

if [[ -f "$LEGACY_ZSH_FUNC" ]]; then
  rm -f "$LEGACY_ZSH_FUNC"
  echo "removed legacy zsh function: $LEGACY_ZSH_FUNC"
fi

# Remove the install directory if it is now empty.
if [[ -d "$PREFIX" ]] && rmdir "$PREFIX" 2>/dev/null; then
  echo "removed empty directory: $PREFIX"
fi

echo "mkcd uninstalled."
