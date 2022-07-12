#!/bin/bash
#
# IMPORTS:
#  ROOT
#  TYPEOF{}
#  NODE_*
#---
#
# THINKIES:
# This is going to end up pretty complicated. Going to have to...
#  1. Generate symbol table
#  2. Typecheck
#  3. Generate validation IR
#  4. Generate stripped down tree for programmer's queries
#     - Move meta-information from nodes to a separate dict
#     - Collapse tree as much as possible
#       - Value nodes (string, int, etc.) don't need a node unto themselves, can
#         be collapsed to the [value]= property of their parent.

# TODO;CURRENT:
# I feel like the blocks of...
#
#> declare -g NODE=${node[left]}
#> _0_debug_${TYPEOF[$NODE]}
#
# ...could be replaced by a function:
#
#> funtion walk {
#>    declare -g NODE=$1
#>    _0_debug_${TYPEOF[$NODE]}
#> }
#
# Pretty straightforward to call then:
#
#> function _0_debug_typedef {
#>    local -- save=$NODE
#>    local -n node=$save
#> 
#>    walk ${node[kind]}
#> 
#>    [[ -n ${node[subtype]} ]] && {
#>       walk ${node[subtype]}
#>    }
#> }

declare -- NODE=$ROOT

function walk {
   declare -g NODE=${1?}
   _0_debug_${TYPEOF[$NODE]}
}

function _0_debug_decl_section {
   local -- save=$NODE
   local -n node=$save

   walk ${node[name]}

   declare -n items="${node[items]}" 
   for nname in "${items[@]}"; do
      walk $nname
   done

   declare -g NODE=$save
}


function _0_debug_decl_variable {
   local -- save=$NODE
   local -n node=$save

   walk ${node[name]}

   [[ -n ${node[type]} ]] && walk ${node[type]}
   [[ -n ${node[expr]} ]] && walk ${node[expr]}

   declare -g NODE=$save
}


function _0_debug_array {
   local -- save=$NODE
   local -n node=$save

   for nname in "${node[@]}"; do
      walk $nname
   done

   declare -g NODE=$save
}


function _0_debug_typedef {
   local -- save=$NODE
   local -n node=$save

   walk ${node[kind]}

   [[ -n ${node[subtype]} ]] && {
      walk ${node[subtype]}
   }
}


function _0_debug_binary {
   local -- save=$NODE
   local -n node=$save

   walk ${node[left]}
   walk ${node[right]}

   declare -g NODE=$save
}


function _0_debug_unary {
   local -- save=$NODE
   local -n node=$save

   walk ${node[right]}

   declare -g NODE=$save
}


function _0_debug_boolean {
   local -n node=$NODE
   echo "BOOL[${node[value]}]"
}


function _0_debug_integer {
   local -n node=$NODE
   echo "INT[${node[value]}]"
}


function _0_debug_string {
   local -n node=$NODE
   echo "STRING[${node[value]}]"
}


function _0_debug_path {
   local -n node=$NODE
   echo "PATH[${node[value]}]"
}


function _0_debug_identifier {
   local -n node=$NODE
   echo "IDENT[${node[value]}]"
}

_0_debug_decl_section




#declare -- SYMBOL
#declare -i SYMBOL_NUM=0
#
#declare -- TYPE
#declare -i TYPE_NUM=0
#
#declare -- SYMTAB
#declare -i SYMTAB_NUM=0
#
#declare -a SCOPE=()
##> class Symtab:
##     parent : Symtag
##     keys   : dict[str, Type]
#
## This isn't actually used anywhere, it's kinda just self-documentation that
## these are the types.
#declare -A BUILT_INS=(
#   [int]='INTEGER'
#   [str]='STRING'
#   [bool]='BOOLEAN'
#   [path]='PATH'
#   [array]='ARRAY'
#)
#
#
#function mk_type {
#   (( TYPE_NUM++ ))
#   local   --  tname="TYPE_${TYPE_NUM}"
#   declare -gA $tname
#   declare -g  TYPE=$tname
#   local   --  type=$tname
#
#   type[kind]=
#   type[subtype]=
#}
#
#
#function mk_symbol {
#   (( SYMBOL_NUM++ ))
#   local   --  sname="SYMBOL_${SYMBOL_NUM}"
#   declare -gA $sname
#   declare -g  SYMBOL=$sname
#   local   --  symbol=$sname
#
#   symbol[name]=
#   symbol[type]=
#}
