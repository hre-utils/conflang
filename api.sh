#!/bin/bash
#
# The programmer-facing part of the script. Allows accessing the nodes created
# by the config file.
#
# IMPORTS:
#  _DATA_*

declare -- RV

function conf {
   declare -g RV=$_DATA_ROOT

   while [[ $# -gt 0 ]] ; do
      local -n d=$RV
      declare -g RV="${d[$1]}"

      if [[ -z $RV ]] ; then
         # Tracebacks would be A+ here.
         echo "selector '$1' not found" 1>&2
         exit -1
      fi

      shift && (( idx++ ))
   done
}

echo "RV == $RV"
