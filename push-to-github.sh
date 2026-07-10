#!/bin/bash
# Run this while authenticated as a user with PUSH access to judeprogrammer-bot/fcb-demo
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -d .git ]; then
  git init
  git branch -M main
  git remote add origin https://github.com/judeprogrammer-bot/fcb-demo.git
fi
git add -A
git commit -m "Flatten repo structure for Context7 indexing" || true
git push -u origin main --force
echo "Done: https://github.com/judeprogrammer-bot/fcb-demo"
