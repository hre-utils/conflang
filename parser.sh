#!/bin/bash
#
# from ./lexer.sh import {
#  TOKENS[]             # Array of token names
#  TOKEN_$n             # Sequence of all token objects
#  INPUT_FILE           # Name of input file
#  FILE_LINES[]         # INPUT_FILE.readlines()
# }
#
#---
# TODO:
#  [ ] OOPS I forgot booleans
#      - Just going to use true/false, not yaml's yes/no/1/0 nonsense


# Need to think through the structure of the file a little more. Both to write a
# grammer, but also to make something that can be used to parse the programmer's
# .cfg, as well as the user's. Still not 100% on how I want that split to work.
# It very well may end up being such that they're the same thing. The user's is
# sourced second, and only settings in direct conflict supersede prior ones.
#
# List items are separated by any whitespace.
:<<'COMMENT'
   SECTION_NAME {
      # Key/value pairs.
      key type:subtype default_value {
         assert_1;
         assert_2;
         assert_3;
      }

      # Lists.
      key type:subtype [
         item_1
         item_2
         item_3
      ] {
         assert_1;
         assert_2;
         assert_3;
      }

      # Boils down to.
      identifier  identifier[:identifier]*  [data]  ['{' expr_list '}']  ';'
   }

   EBNF-ish
      # Not entirely accurate, as we implicitly create an %inline section as
      # the root.
      program     -> section EOF

      # Within a section can only be named-elements. Can't have a section with a
      # raw array, for example, as there's no way to reference it.
      section     -> identifier '{' named* '}'

      # Can easily identify if we're opening a section block, or an
      # array/literal, as the former is differentiated by an opening '{'.
      named       -> section
                   | identifier [type] [data] [validation] ';'

      # Data has to be separate from section & named, to differentiate what can
      # be typed, and which element requires an identifier.
      data        -> array
                   | literal

      array       -> type '[' data* ']' asserts

      # The final expression does not require 
      asserts     -> '{' expr_list '}'

      expr_list   -> expr_list ';'
                   | expression

      type        -> identifier [':' identifier]*

      validation  -> '{' expr* '}'

      expr_list   -> expr ';'

      literal     -> string
                   | integer
                   | path
                   | boolean


   # Default top-level section created by the parser.
   %inline {
      # Only "named" elements can go here.
      key "data";

      key [
         "data"
         "data2"
      ];
      # Arrays are separated by whitespace, and terminated by a closing ']'.
      # Arrays and named literals must be terminated with a ';'.

      section { }
      # Sections do not need to end in an 
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
   # An array declared with only `declare -a NODE`, but no value, will not be
   # printed by `declare -p ${!NODE*}`. Requires to be set to at least an empty
   # array.
   node=()

   TYPEOF[$nname]='section'
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

   TYPEOF[$nname]='section'
}


function mk_type_decl {
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

   TYPEOF[$nname]='type'
}


function mk_integer {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -gi $nname
   declare -g  NODE=$nname

   TYPEOF[$nname]='integer'
}


function mk_string {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -g $nname
   declare -g NODE=$nname

   TYPEOF[$nname]='string'
}


function mk_identifier {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -g $nname
   declare -g NODE=$nname

   TYPEOF[$nname]='identifier'
}


#═══════════════════════════════════╡ utils ╞═══════════════════════════════════
declare -i IDX
declare -- CURRENT PEEK

function advance { 
   # TODO: So I don't need to potentially declare namerefs in every single
   # function for the ${CURRENT,PEEK} tokens, might as well just make global
   # pointers like so:
   #> declare -g  CURRENT_NAME=${TOKENS[IDX+1]}
   #> declare -gn CURRENT=$CURRENT_NAME
   # Thus, we can always access either the name of the current/peek tokens, or
   # the underlying token itself. Thought about making it ONLY the poionter,
   # except we do actually need the names in the `mk_` functions.

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


function check {
   local -n t=$CURRENT
   [[ "${t[type]}" == $1 ]]
}


function match {
   local -n t=$CURRENT
   [[ "${t[type]}" == $1 ]] || raise_parse_error
}


function munch {
   local -n t=$CURRENT
   [[ "${t[type]}" == $1 ]] || raise_parse_error
   advance
}


function parse {
   advance
   program
}

#═════════════════════════════╡ GRAMMAR FUNCTIONS ╞═════════════════════════════
function program {
   mk_section # create top-level, anonymous, `inline' section.
   sect_name='%inline'

   # Store newly created section node before we overwrite.
   local store=$NODE

   while [[ -n $PEEK ]] ; do
      key_or_section
   done

   # Restore.
   declare -g NODE=$store
   munch 'EOF'
}
# `program' should start with one top level section initially defined: %inline.
# Users cannot define headings with symbols, so there's no possibility of
# collision.

function key_or_section {
   match 'IDENTIFIER'
   mk_identifier

   local -n key=$NODE
   local -n curr=$CURRENT

   # Save the value of the current identifier token to the Identifier Node.
   # Token(value: "...") -> Identifier("...")
   node="${curr[value]}"

   # Move past identifier.
   advance

   local -n curr=$CURRENT
   if check 'L_PAREN' ; then
      mk_type_decl
   fi
   local type=$NODE
   
   case "${curr[type]}" in
   esac
}


function section {
}


function key {

}


function type_decl {
}


function list {
   # Set aside current global $NODE pointer.
   local store=$NODE

   # Restore.
   declare -g NODE=$store
}

#════════════════════════════════════╡ GO ╞═════════════════════════════════════
parse
(
   declare -p TYPEOF
   [[ -n ${!NODE_*} ]] && declare -p ${!NODE_*}
)
