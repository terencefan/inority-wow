#!/usr/bin/env bash
set -eu

fail_on_warnings=0
check_level=Warning

while [ "$#" -gt 0 ]; do
	case "$1" in
	--fail-on-warnings)
		fail_on_warnings=1
		;;
	--check-level)
		if [ "$#" -lt 2 ]; then
			echo "Missing value for --check-level" >&2
			exit 1
		fi
		check_level=$2
		shift
		;;
	*)
		echo "Unknown argument: $1" >&2
		exit 1
		;;
	esac
	shift
done

case "$check_level" in
Error | Warning | Information | Hint) ;;
*)
	echo "Invalid check level: $check_level" >&2
	exit 1
	;;
esac

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
log_dir="$repo_root/dist/luals-check"
meta_dir="$log_dir/meta"

if command -v lua-language-server >/dev/null 2>&1; then
	lua_ls_bin=$(command -v lua-language-server)
elif command -v lua_ls >/dev/null 2>&1; then
	lua_ls_bin=$(command -v lua_ls)
else
	echo "lua-language-server (or lua_ls) is not installed or not on PATH. Install LuaLS first, then rerun this script." >&2
	exit 1
fi

mkdir -p "$meta_dir"
cd "$repo_root"

set +e
output=$("$lua_ls_bin" \
	--configpath=.luarc.json \
	"--logpath=$log_dir" \
	"--metapath=$meta_dir" \
	"--check=$repo_root" \
	--check_format=pretty \
	"--checklevel=$check_level" 2>&1)
status=$?
set -e

if [ -n "$output" ]; then
	printf '%s\n' "$output"
fi

if [ "$status" -eq 0 ]; then
	exit 0
fi

if [ "$fail_on_warnings" -ne 1 ] && ! printf '%s\n' "$output" | grep -q '\[Error\]'; then
	exit 0
fi

exit "$status"
