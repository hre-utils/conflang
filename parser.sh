#!/bin/bash
#
# from ./lexer.sh import {
#  TOKENS[]             # Array of token names
#  TOKEN_$n             # Sequence of all token objects
#  INPUT_FILE           # Name of input file
#  FILE_LINES[]         # INPUT_FILE.readlines()
# }

# Need to think through the structure of the file a little more. Both to write a
# grammer, but also to make something that can be used to parse the programmer's
# .cfg, as well as the user's. Still not 100% on how I want that split to work.
# It very well may end up being such that they're the same thing. The user's is
# sourced second, and only settings in direct conflict supersede prior ones.
#
# List items are separated by any whitespace.
:<<COMMENT
   SECTION_NAME {
      # Key/value pairs.
      key (type:subtype) default_value {
         assert_1;
         assert_2;
         assert_3;
      }

      # Lists.
      key (type:subtype) [
         item_1
         item_2
         item_3
      ] {
         assert_1;
         assert_2;
         assert_3;
      }
   }
COMMENT


#═════════════════════════════════╡ AST NODES ╞═════════════════════════════════
declare -- NODE
declare -i _NODE_NUM=0

# I'm not entirely sure if I need this yet. Will just be a dictionary mapping
# the internal name of a node to its type. E.g,
#> typeof=(
#>    [NODE_1]='string'
#>    [NODE_2]='dict'
#>    [NODE_3]='identifier'
#>    [NODE_4]='type'
#> )
#
# Would save me from having to use a `get_type' function using `declare -p` to
# haphazardly determine from basic types. Though maybe that's actually all we
# need in this case. Going to have to just start banging on it and see what
# happens.
declare -A TYPEOF=()


function mk_section {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname

   local -n node=$nname
   #node=()
   # An array declared with only `declare -a NODE`, but no value, will not be
   # printed by `declare -p ${!NODE*}`. Requires to be set to at least an empty
   # array.

   # To differentiate from dict associateive arrays.
   node[%type]='type'
}


function mk_list {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -ga $nname
   declare -g  NODE=$nname

   local -n node=$nname
   node=()
}


function mk_key {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -g $nname
   declare -g NODE=$nname
}


function mk_type {
   # Example, representing a list[string]:
   #> Type(
   #>    kind: 'list',
   #>    subtype: Type(
   #>       kind: 'string',
   #>       subtype: None
   #>    )
   #> )

   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname

   local -n node=$nname
   node[kind]=          # Primitive type
   node[subtype]=       # Sub `Type' node
}


function mk_integer {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -gi $nname
   declare -g  NODE=$nname
}


function mk_string {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -g $nname
   declare -g NODE=$nname
}


#═══════════════════════════════════╡ utils ╞═══════════════════════════════════
declare -i IDX
declare -- CURRENT PEEK

function advance { 
   while [[ $IDX -lt ${#TOKENS[@]} ]] ; do
      CURRENT=${TOKENS[IDX]}
      PEEK=${TOKENS[IDX+1]}

      local -n t=$CURRENT
      if [[ ${t[type]} == 'ERROR' ]] ; then
         syntax_error $CURRENT
      fi

      (( ++IDX ))
   done
}


# TODO:
# Error recovery. We have pretty solid places from which we can "recover" to if
# an `ERROR' token is encountered. The end of any list or block is a pretty easy
# candidate.
function syntax_error {
   local -n t=$1
   printf "[${t[lineno]}:${t[colno]}]There was an error.\n" 1<&2
   # TODO: use the proper, defined error code for syntax errors.
   exit -1
}


function check { echo -n '' ;}
function match { echo -n '' ;}
function munch { echo -n '' ;}

function parse {
   advance
   program
}

#═════════════════════════════╡ GRAMMAR FUNCTIONS ╞═════════════════════════════
function program {
   mk_section # create `%inline' section
}
# `program' should start with one top level section initially defined: %inline.
# Users cannot define headings with symbols, so there's no possibility of
# collision.

function section { echo -n '' ;}
function key { echo -n '' ;}
function type { echo -n '' ;}
function list { echo -n '' ;}
