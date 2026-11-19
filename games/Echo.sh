#!/bin/sh
printf '\033c\033]0;%s\a' Echo
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Echo.x86_64" "$@"
