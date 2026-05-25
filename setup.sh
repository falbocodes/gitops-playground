#!/bin/bash
set -euo pipefail

USERNAME=${1:-}

if [ -z "$USERNAME" ]; then
  echo "Usage: ./setup.sh <github-username>"
  exit 1
fi

echo "Setting GitHub username to '$USERNAME'..."

SED_INPLACE=(-i)
[[ "$OSTYPE" == "darwin"* ]] && SED_INPLACE=(-i '')

find . -type f \( -name "*.yaml" -o -name "*.md" \) -exec grep -l "falbocodes" {} \; | while IFS= read -r file; do
  sed "${SED_INPLACE[@]}" "s/falbocodes/$USERNAME/g" "$file"
  echo "  updated: $file"
done

echo ""
echo "Done. Commit and push the changes to your fork:"
echo ""
echo "  git add ."
echo "  git commit -m \"chore: set repoURL to my fork\""
echo "  git push"
