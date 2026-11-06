#!/usr/bin/env bash
#
# Install the Bangla Fonts collection.
#
# Fonts are installed as a flat set of files into a directory owned by this
# installer (matching the Windows layout):
#
#   Default (per-user): ${XDG_DATA_HOME:-$HOME/.local/share}/fonts/bangla-fonts
#   --system:           /usr/local/share/fonts/bangla-fonts
#
# Re-running the script is safe: unchanged files are skipped and stale fonts
# from older runs are removed.
#
set -euo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
ORIGINAL_ARGS=("$@")

SYSTEM=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Install every Bangla font in this repository into a flat font directory.

Options:
  --system       Install for all users (requires root; uses sudo when available)
  -n, --dry-run  Show what would be installed without copying anything
  -h, --help     Show this help and exit
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --system)
      SYSTEM=1
      ;;
    -n|--dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$SYSTEM" -eq 1 ]; then
  TARGET='/usr/local/share/fonts/bangla-fonts'
  if [ "$DRY_RUN" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      printf 'System-wide install requires root; re-running with sudo...\n'
      exec sudo -- bash "$SCRIPT_DIR/$(basename -- "$0")" ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"}
    fi
    printf 'error: --system requires root. Re-run with sudo.\n' >&2
    exit 1
  fi
else
  TARGET="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/bangla-fonts"
fi

# Make sure this really is the font repository.
if [ ! -f "$SCRIPT_DIR/README.md" ]; then
  printf 'error: README.md not found next to this script; run it from the repository.\n' >&2
  exit 1
fi

# Collect font paths once. null-delimited, so spaces/newlines in names are safe.
font_files=()
while IFS= read -r -d '' file; do
  case "$file" in
    "$TARGET"/*) continue ;;
  esac
  font_files+=("$file")
done < <(find "$SCRIPT_DIR" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -not -path '*/.git/*' -print0)

font_count=${#font_files[@]}
if [ "$font_count" -eq 0 ]; then
  printf 'error: no .ttf or .otf files found in %s\n' "$SCRIPT_DIR" >&2
  exit 1
fi

# Fonts are installed flat, so every file name must be unique.
declare -A basenames=()
for file in "${font_files[@]}"; do
  base="${file##*/}"
  key="${base,,}"
  if [ -n "${basenames[$key]:-}" ]; then
    printf 'error: two font files share the name "%s":\n  %s\n  %s\n' \
      "$base" "${basenames[$key]}" "$file" >&2
    printf 'Fonts are installed into a single flat folder; rename one of them to continue.\n' >&2
    exit 1
  fi
  basenames[$key]="$file"
done

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p -- "$TARGET"
fi

# Remove fonts left over from previous layouts (for example the old
# family-subfolder layout) or removed from the repository. Only files inside
# our own target directory are considered.
removed=0
if [ -d "$TARGET" ]; then
  while IFS= read -r -d '' existing; do
    base="${existing##*/}"
    key="${base,,}"
    directory="${existing%/*}"
    if [ "$directory" != "$TARGET" ] || [ -z "${basenames[$key]:-}" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        printf 'would remove stale %s\n' "${existing#"$TARGET"/}"
      else
        rm -f -- "$existing"
      fi
      removed=$((removed + 1))
    fi
  done < <(find "$TARGET" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)

  if [ "$DRY_RUN" -eq 0 ]; then
    find "$TARGET" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  fi
fi

installed=0
unchanged=0
failed=0

for file in "${font_files[@]}"; do
  base="${file##*/}"
  destination="$TARGET/$base"

  if [ -f "$destination" ] && cmp -s -- "$file" "$destination"; then
    unchanged=$((unchanged + 1))
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'would install %s\n' "$base"
    installed=$((installed + 1))
    continue
  fi

  if cp -f -- "$file" "$destination"; then
    chmod 644 -- "$destination" 2>/dev/null || true
    installed=$((installed + 1))
  else
    printf 'warning: failed to install %s\n' "$base" >&2
    failed=$((failed + 1))
  fi
done

printf '\n'
if [ "$DRY_RUN" -eq 1 ]; then
  printf 'Dry run: %d file(s) would be installed, %d stale file(s) would be removed, %d already up to date (%d total).\n' \
    "$installed" "$removed" "$unchanged" "$font_count"
  printf 'Target: %s\n' "$TARGET"
  exit 0
fi

printf 'Installed: %d   Unchanged: %d   Removed: %d   Failed: %d   Total: %d\n' \
  "$installed" "$unchanged" "$removed" "$failed" "$font_count"
printf 'Font directory: %s\n' "$TARGET"

if command -v fc-cache >/dev/null 2>&1; then
  printf 'Refreshing font cache...\n'
  if fc-cache -f -- "$TARGET" >/dev/null 2>&1; then
    printf 'Done. Open a new application (or restart running ones) to use the fonts.\n'
  else
    printf 'warning: fc-cache failed. Run "fc-cache -f" manually to refresh the font cache.\n' >&2
  fi
else
  printf 'warning: fc-cache not found. Install fontconfig or log out and back in.\n' >&2
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi
