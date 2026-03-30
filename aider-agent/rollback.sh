#!/bin/bash
# Использование:
#   ./rollback.sh      — откатить 1 последний коммит
#   ./rollback.sh 3    — откатить 3 последних коммита

COUNT=${1:-1}

echo ""
echo "Commits to rollback:"
echo ""
git log -"$COUNT" --pretty=format:"  %s  [%an, %ar]"
echo ""
echo ""
read -p "Rollback $COUNT commit(s)? (y/n): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    git reset --hard HEAD~"$COUNT"
    echo ""
    echo "Done. Rolled back $COUNT commit(s)."
fi