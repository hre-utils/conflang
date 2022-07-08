#!/bin/bash

declare -g  NODE
declare -g  RV
declare -gi i

declare -ga INPUT=( '1' '+' '2' '*' '3' )

declare -g  IDX=0
declare -g CURRENT=${INPUT[IDX]}
declare -g PEEK=${INPUT[IDX+1]}


function advance {
   (( ++IDX ))
   declare -g CURRENT=${INPUT[IDX]}
   declare -g PEEK=${INPUT[IDX+1]}
}


function binary {
   local -- lhs="$1" op="$2" rbp="$3"

   (( ++i ))
   local -- nname="NODE_${i}"
   declare -gA $nname
   declare -g  NODE=$nname

   expr $rbp
   local -- rhs=$NODE

   declare -n  n=$nname
   n[left]=$lhs
   n[op]=$op
   n[right]=$rhs

   declare -g NODE=$nname
}


function integer {
   (( ++i ))
   local   -- nname="NODE_${i}"
   declare -gi $nname
   declare -g  NODE=$nname
   local   -n  node=$nname
   node=$1
}


function expr {
   local -- min_bp="${1:-0}"

   integer "$CURRENT"
   local -- lhs="$NODE"

   advance

   while :; do
      case "$CURRENT" in
         '+' | '-')  lbp=1  rbp=2 ;;
         '*' | '/')  lbp=3  rbp=4 ;;
         '') break 2 ;;
         *) echo "Bad token: $CURRENT" ;;
      esac

      if [[ $lbp -lt $min_bp ]] ; then
         break
      fi

      local op="$CURRENT"
      advance

      binary "$lhs" "$op" "$rbp"
      local lhs=$NODE
   done

   declare -g NODE=$lhs
}

expr
[[ -n ${!NODE_*} ]] && declare -p ${!NODE_*}
