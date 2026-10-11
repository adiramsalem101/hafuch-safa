#!/bin/bash
# hafuch-safa (הפוך שפה): one-line installer for macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/adiramsalem101/hafuch-safa/main/get.sh | bash
#
# Downloads the project into a temporary folder, runs mac/install.sh and
# deletes the temporary folder. Uses only bash, curl and unzip; no sudo.

set -euo pipefail

main() {
    local url="https://github.com/adiramsalem101/hafuch-safa/archive/refs/heads/main.zip"
    local tmp
    [ "$(uname -s)" = "Darwin" ] || { echo "hafuch-safa: this installer is for macOS. On Windows see the README." >&2; exit 1; }
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/hafuch-safa.XXXXXX")"
    trap 'rm -rf "$tmp"' EXIT
    echo "Downloading hafuch-safa..."
    curl -fsSL -o "$tmp/main.zip" "$url"
    unzip -q "$tmp/main.zip" -d "$tmp"
    bash "$tmp/hafuch-safa-main/mac/install.sh"
}

# Wrapped in a function so that a partial download never runs half a script.
main "$@"
