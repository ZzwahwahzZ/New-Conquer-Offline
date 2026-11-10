#!/usr/bin/env bash
set -euo pipefail

echo "[workshop] Preparing OpenCode..."
mkdir -p "$HOME/.opencode/bin" "$HOME/.local/bin"

if ! command -v opencode >/dev/null 2>&1 && [ ! -x "$HOME/.opencode/bin/opencode" ] && [ ! -x "$HOME/.local/bin/opencode" ]; then
  curl -fsSL https://opencode.ai/install | bash
fi

if [ -x "$HOME/.opencode/bin/opencode" ]; then
  ln -sf "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"
elif command -v opencode >/dev/null 2>&1; then
  ln -sf "$(command -v opencode)" "$HOME/.local/bin/opencode"
fi

export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if ! command -v opencode >/dev/null 2>&1; then
  echo "[workshop] ERROR: OpenCode installation could not be verified."
  exit 1
fi

for profile in "$HOME/.bashrc" "$HOME/.profile"; do
  touch "$profile"
  grep -qxF 'export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"' "$profile" || \
    echo 'export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"' >> "$profile"
done

echo "[workshop] OpenCode installed:"
opencode --version
echo "[workshop] Setup complete. No game files were changed by this setup."
