#!/bin/bash
#
# The programmer-facing part of the script. Allows accessing the nodes created
# by the config file.
#
# IMPORTS:
#  _DATA_ROOT
#  _DATA_$n

declare -- RV

function conf {
   declare -g RV=$_DATA_ROOT

   while [[ $# -gt 0 ]] ; do
      local -n d=$RV

      # Test if the selector exists. If it's trying to query an index that's
      # *UNSET*, rather than just declared as an empty string, it explodes.
      if [[ ! "${d[$1]+_}" ]] ; then
         echo "selector '$1' not found." 1>&2
         exit -1
         # TODO: error reporting
         # Tracebacks would be A+ here.
      fi

      declare -g RV="${d[$1]}"
      shift && (( idx++ ))
   done
}
