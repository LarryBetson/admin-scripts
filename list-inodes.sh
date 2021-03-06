#!/bin/bash
# find directories with a lot of inodes

TOP_COUNT=40
TOP_MSG="top ${TOP_COUNT} by inodes"
INPUT_PATH="."

if [ -n "$1" ]; then
  INPUT_PATH=$(readlink -m "$@")
  echo "$TOP_MSG: $INPUT_PATH"
else
  INPUT_PATH=$(readlink -m "$INPUT_PATH")
  echo "$TOP_MSG"
fi

find "${INPUT_PATH}" -xdev -printf '%h\n' \
  | sort \
  | uniq -c \
  | sort -k 1 -n -r \
  | head -${TOP_COUNT}
