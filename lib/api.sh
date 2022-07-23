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

      # If variable IS UNSET. Will not trigger if variable is SET but EMPTY.
      if [[ ! "${d[$1]+_}" ]] ; then
         # Tracebacks would be A+ here.
         echo "selector '$1' not found ${d[$1]-_}" 1>&2
         exit -1
      fi

      declare -g RV="${d[$1]}"
      shift && (( idx++ ))
   done
}
