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
#
# Everything that's "exported" here (via `declare -p`) will be sourced by the
# user. Need to be more cognizant of naming. Can't have vars get stomped.

declare -- NODE

#────────────────────────────────( build data )─────────────────────────────────
declare -- KEY DATA

declare -i DATA_NUM=0
declare -- _DATA_ROOT='_DATA_1'

function mk_data_dict {
   (( DATA_NUM++ ))
   local   --  dname="_DATA_${DATA_NUM}"
   declare -gA $dname
   declare -g  DATA=$dname
   local   -n  data=$dname
   data=()
}


function mk_data_array {
   (( DATA_NUM++ ))
   local   --  dname="_DATA_${DATA_NUM}"
   declare -ga $dname
   declare -g  DATA=$dname
   local   -n  data=$dname
   data=()
}

function walk_data {
   declare -g NODE="$1"
   #semantics_${TYPEOF[$NODE]}
   data_${TYPEOF[$NODE]}
}


function data_decl_section {
   # Save reference to current NODE. Restored at the end.
   local -- save=$NODE
   local -n node=$save

   # Create data dictionary object.
   mk_data_dict
   local -- dname=$DATA
   local -n data=$DATA

   walk_data ${node[name]}
   local -- key="$DATA"

   declare -n items="${node[items]}" 
   for nname in "${items[@]}"; do
      walk_data $nname
      data[$KEY]="$DATA"
   done

   declare -g KEY="$key"
   declare -g DATA="$dname"
   declare -g NODE="$save"
}


function data_decl_variable {
   local -- save=$NODE
   local -n node=$save

   walk_data ${node[name]}
   local -- key="$DATA"

   if [[ -n ${node[expr]} ]] ; then
      walk_data ${node[expr]}
   else
      declare -g DATA=''
   fi

   declare -g KEY="$key"
   declare -g NODE=$save
}


function data_array {
   local -- save=$NODE
   local -n node=$save

   mk_data_array
   local -- dname=$DATA
   local -n data=$DATA

   for nname in "${node[@]}"; do
      walk_data $nname
      data+=( "$DATA" )
   done

   declare -g DATA=$dname
   declare -g NODE=$save
}


function data_boolean {
   local -n node=$NODE
   declare -g DATA="${node[value]}"
}


function data_integer {
   local -n node=$NODE
   declare -g DATA="${node[value]}"
}


function data_string {
   local -n node=$NODE
   declare -g DATA="${node[value]}"
}


function data_path {
   local -n node=$NODE
   declare -g DATA="${node[value]}"
}


function data_identifier {
   local -n node=$NODE
   declare -g DATA="${node[value]}"
}


#─────────────────────────────( semantic analysis )─────────────────────────────
# Easy way of doing semantic analysis is actually similar to how we did the node
# traversal in the `conf()` function. Globally point to a Type() node.
# Everything at that level should match the Type.kind property. Descend into
# node, set global Type to previous Type.subtype (if exists). Continue semantic
# analysis.
#
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


function walk_semantics {
   declare -g NODE="$1"
   semantics_${TYPEOF[$NODE]}
}


function semantics_decl_section {
   local -- save=$NODE
   local -n node=$save

   declare -n items="${node[items]}" 
   for each in "${items[@]}"; do
      walk $each
   done

   declare -g NODE=$save
}


function semantics_decl_variable {
   local -- save=$NODE
   local -n node=$save

   walk ${node[name]}

   [[ -n ${node[type]} ]] && walk ${node[type]}
   [[ -n ${node[expr]} ]] && walk ${node[expr]}

   declare -g NODE=$save
}


function semantics_array {
   local -- save=$NODE
   local -n node=$save

   for nname in "${node[@]}"; do
      walk $nname
   done

   declare -g NODE=$save
}


function semantics_typedef {
   local -- save=$NODE
   local -n node=$save

   walk ${node[kind]}

   [[ -n ${node[subtype]} ]] && {
      walk ${node[subtype]}
   }
}


# This can only occur within a validation section. Validation expressions must
# return a boolean.
function semantics_binary {
   local -- save=$NODE
   local -n node=$save
   local -n op=${node[op]}

   walk ${node[left]}
   local -- type_left=$TYPE

   walk ${node[right]}
   local -- type_right=$TYPE

   # CURRENT

   #if [[ ${op[value]} =~ (PLUS|MINUS|STAR|SLASH) ]] ; then
   #fi

   declare -g NODE=$save
}


# This can only occur within a validation section. Validation expressions must
# return a boolean.
function semantics_unary {
   local -- save=$NODE
   local -n node=$save

   walk ${node[right]}

   declare -g NODE=$save
}


function semantics_boolean {
   local -n node=$NODE
   # mk_type Boolean
}


function semantics_integer {
   local -n node=$NODE
   # mk_type Integer
}


function semantics_string {
   local -n node=$NODE
   # mk_type String
}


function semantics_path {
   local -n node=$NODE
   # mk_type Path
}


function semantics_identifier { :; }
# pass.
# No semantics to be checked here. Identifiers can only occur as names to
# elements, or function calls.

#──────────────────────────────────( engage )───────────────────────────────────
walk_data $ROOT
#walk_semantics $ROOT
