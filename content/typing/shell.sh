#!/usr/bin/env bash
set -euo pipefail

name="${1:-world}"
count=3
files=("README.md" "Makefile" "src")

echo "hello ${name}"
printf 'count=%d\n' "${count}"

if [[ -d src ]]; then
  echo "src exists"
elif [[ -f README.md ]]; then
  echo "readme only"
else
  echo "empty tree"
fi

for file in "${files[@]}"; do
  echo "check ${file}"
done

case "${name}" in
  ada|grace) echo "known" ;;
  *) echo "guest" ;;
esac

greet() {
  local who="$1"
  echo "hi ${who}"
}
greet "${name}"

# quotes: weak vs strong vs none
echo "home=${HOME}"
echo 'home=${HOME}'
echo home="${HOME}"

# tests, globs, and defaults
[[ -n "${name}" ]] && echo nonempty
echo "${unset_var:-fallback}"
echo src/*.[ch]

exit 0
