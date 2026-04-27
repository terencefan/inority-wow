#!/usr/bin/env bash
set -eu

skip_format=0
skip_luals=0
fail_on_warnings=0

while [ "$#" -gt 0 ]; do
	case "$1" in
	--skip-format)
		skip_format=1
		;;
	--skip-luals)
		skip_luals=1
		;;
	--fail-on-warnings)
		fail_on_warnings=1
		;;
	*)
		echo "Unknown argument: $1" >&2
		exit 1
		;;
	esac
	shift
done

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required command: $1" >&2
		exit 1
	fi
}

run_script() {
	local script_name=$1
	shift
	bash "$script_dir/$script_name" "$@"
}

require_command find
require_command lua
require_command luac

cd "$repo_root"

for target in src tests tools Locale; do
	if [ ! -d "$target" ]; then
		continue
	fi

	find "$target" -type f -name '*.lua' -print0 |
		while IFS= read -r -d '' lua_file; do
			luac -p "$lua_file"
		done
done

if [ "$fail_on_warnings" -eq 1 ]; then
	run_script run_luacheck.sh --fail-on-warnings
else
	run_script run_luacheck.sh
fi

if [ "$skip_luals" -ne 1 ]; then
	run_script run_luals_check.sh
fi

if [ "$skip_format" -ne 1 ]; then
	run_script run_stylua.sh --check
fi

run_script run_lua_tests.sh
