#!/usr/bin/env bash
set -euo pipefail

cd /workspace

echo "==> git identity (local, gitignored)"
gitconfig_local=".devcontainer/gitconfig"
gitconfig_example=".devcontainer/gitconfig.example"
if [ ! -f "$gitconfig_local" ] && [ -f "$gitconfig_example" ]; then
  cp "$gitconfig_example" "$gitconfig_local"
  echo "    Created ${gitconfig_local} from example — edit your name and email."
fi
if [ -f "$gitconfig_local" ]; then
  install -m 644 "$gitconfig_local" "${HOME}/.gitconfig"
else
  echo "    No ${gitconfig_local}; set identity with: git config --global user.name ..."
fi

if ! [ -w /sdks/flutter/bin/cache ]; then
  echo "==> Fixing Flutter SDK permissions"
  sudo chown -R "$(id -u):$(id -g)" /sdks/flutter
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter doctor"
flutter doctor -v

echo "==> Dev container ready."
echo "    Windows host (once per session): start-dev.cmd"
echo "    Then in this container: ./scripts/dev-run.sh"
echo "    Or press F5 -> Unrecorded (mobile)"
