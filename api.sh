#!/bin/bash
#
# The programmer-facing part of the script. Allows accessing the nodes created
# by the config file.
#
# IMPORTS:
#  __DATA_*


declare -- RV='__DATA_ROOT'

function conf {
   local -i idx=1

   while [[ $# -gt 0 ]] ; do
      local -n d=$RV
      declare -g RV="${d[$1]}"

      if [[ -z $RV ]] ; then
         # Tracebacks would be A+ here.
         echo "selector #$idx '$1' not found" 1>&2
         exit -1
      fi

      shift && (( idx++ ))
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

conf 0 "tim" "tam"
echo "RV == $RV"
