#!/bin/bash
#
# The programmer-facing part of the script. Allows accessing the nodes created
# by the config file.
#
# IMPORTS:
#  __DATA_*
#
# THINKIES:
# Also a recursive descenty kinda tree traversal here, except hopefully flatten
# out some of the unnecessary nodes for faster queries.
#  - Pull out type & validation nodes
#  - Squash literals directly into their parent's dict
#
# For faster access, drop values into a global `RV` variable. Better than having
# the raw values `echo` themselves. Super slow as you add subshell calls.
#
# Thinking of doing something like...

declare -- RV

function conf {
   while [[ $# -gt 0 ]] ; do
      local -n d=$RV
      declare -g RV="${d[$1]}"
      shift
   done
}

declare -- RV=_D1
declare -A _D1=(
   [global]=_D2
)
declare -A _D2=(
   [one]="this"
   [two]=_D3
)
declare -a _D3=(
   "zero"
   "one"
   "two"
)

conf "global" "two" "0"
echo "RV == $RV"
