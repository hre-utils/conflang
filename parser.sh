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
#  [ ] Tracebacks!
#      - What a good opportunity for me to work on that bash traceback nonsense
#        I was trying to figure out a while ago.
#  [ ] I hate how `munch()` works right now


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
                   | element

      element    -> identifier [type] [data] [validation] ';'

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
   ## psdudo.
   #> class Section:
   #>    name  : identifier = None
   #>    items : array      = []

   # 1) create parent
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   # 2) create list to hold the items within the section.
   (( _NODE_NUM++ ))
   local nname_items="NODE_${_NODE_NUM}"
   declare -ga $nname_items
   local   -n  node_items=$nname_items
   node_items=()

   # 3) assign child node to parent.
   node[name]=
   node[items]=$nname_items

   # 4) Meta information, for easier parsing.
   TYPEOF[$nname]='section'
}


function mk_element {
   ## psdudo.
   #> class Named:
   #>    name       : identifier = None
   #>    type       : Type       = None     (opt)
   #>    data       : Data       = None     (opt)
   #>    validation : Validation = None     (opt)
   #
   # $Data may be either an $Array or literal.

   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   node[name]=       # identifier
   node[type]=       # type
   node[data]=       # section, array, int, str, bool, path
   node[validation]=
   
   TYPEOF[$nname]='element'
}


function mk_array {
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -ga $nname
   declare -g  NODE=$nname

   local -n node=$nname
   node=()
}


function mk_typedef {
   ## psdudo.
   #> class Typedef:
   #>    kind     : identifier = None
   #>    subtype  : Typedef    = None     (opt)
   #
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


function mk_function {
   ## psdudo.
   #> class Function:
   #>    name   : identifier = None
   #>    params : array      = []

   # 1) create parent
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   # 2) create list to hold the items within the section.
   (( _NODE_NUM++ ))
   local nname_params="NODE_${_NODE_NUM}"
   declare -ga $nname_params
   local   -n  node_params=$nname_params
   node_params=()

   # 3) assign child node to parent.
   node[name]=
   node[params]=$nname_params

   # 4) Meta information, for easier parsing.
   TYPEOF[$nname]='function'
}


function mk_binary {
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -ga $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   node[op]=
   node[left]=
   node[right]=

   TYPEOF[$nname]='binary'
}


function mk_unary {
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -ga $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   node[op]=
   node[right]=

   TYPEOF[$nname]='unary'
}


function mk_literal {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -g $nname
   declare -g NODE=$nname

   TYPEOF[$nname]='literal'
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


function mk_path {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -g $nname
   declare -g NODE=$nname

   TYPEOF[$nname]='identifier'
}


function mk_identifier {
   (( _NODE_NUM++ ))
   local nname="NODE_${_NODE_NUM}"
   declare -g $nname
   declare -g NODE=$nname

   TYPEOF[$nname]='identifier'
}


#═══════════════════════════════════╡ utils ╞═══════════════════════════════════
declare -i IDX=0
declare -- CURRENT  CURRENT_NAME
declare -- PEEK     PEEK_NAME
# Calls to `advance' both globally set the name of the current/next node(s),
# e.g., `TOKEN_1', as well as declaring a nameref to the variable itself.
#
# TODO:
# I could probably save myself pretty significant headache by also adding a
# PREVIOUS{,_NAME} var(s), such that I can just munch an identifier, and still
# access the data from it.


function advance { 
   #echo "CURRENT[$(declare -p $CURRENT_NAME)]"

   while [[ $IDX -lt ${#TOKENS[@]} ]] ; do
      declare -g  CURRENT_NAME=${TOKENS[IDX]}
      declare -gn CURRENT=$CURRENT_NAME

      declare -g  PEEK_NAME=${TOKENS[IDX+1]}
      if [[ -n $PEEK_NAME ]] ; then
         declare -gn PEEK=$PEEK_NAME
      fi

      if [[ ${CURRENT[type]} == 'ERROR' ]] ; then
         raise_syntax_error
      else
         break
      fi
   done

   (( ++IDX ))
}


# TODO:
# Error recovery. We have pretty solid places from which we can "recover" to if
# an `ERROR' token is encountered. The end of any list or block is a pretty easy
# candidate.
function raise_syntax_error {
   local -- tname=${1:-$CURRENT_NAME}
   local -n t=$tname

   printf "[${t[lineno]}:${t[colno]}] There was an error.\n" 1<&2
   # TODO: use the proper, defined error code for syntax errors.
   exit -1
}


function raise_parse_error {
   local -n t=$CURRENT_NAME
   local -- exp=$1
   local -- msg="${2:-Expected something else.}"

   printf "[${t[lineno]}:${t[colno]}] expected($exp) ${msg}\n" 1<&2
   declare -p $CURRENT_NAME
   exit -1
}


function check {
   [[ "${CURRENT[type]}" == $1 ]]
}


function match {
   if check $1 ; then
      advance
      return 0
   fi
   
   return 1
}


function munch {
   if ! check $1 ; then
      raise_parse_error "$1" "$2"
   fi
   
   advance
}


function parse {
   advance
   program
}

#═════════════════════════════╡ GRAMMAR FUNCTIONS ╞═════════════════════════════
function program {
   # TODO:
   # This is preeeeeeeeeeeeetty janky. I don't love it. Since this pseudo-
   # section doesn't actually exist in-code, it doesn't have any opening or
   # closing braces. So `section()` gets fucked up when trying to munch a
   # closing brace. Gotta just in-line stuff here all hacky-like.
   #
   # Creates a default top-level `section', allowing top-level key:value pairs,
   # wout requiring a dict (take that, JSON).
   mk_section
   local -n node=$NODE
   local -n items=${node[items]}

   declare -g NODE_0='%inline'
   node[name]=$NODE_0

   while ! check 'EOF' ; do
      named
      items+=( $NODE )
   done

   munch 'EOF'
}


function named {
   identifier
   munch 'IDENTIFIER' "expecting named element here: identifier is missing." 1>&2

   # Section:
   # If looks like:  `identifier { ... }`,  then it's a section
   if match 'L_BRACE' ; then
      section
   else
      element
   fi
}


function section {
   # Elements must be preceded by an identifier.
   local -- name=$NODE

   mk_section
   local -- save=$NODE
   local -n node=$NODE
   local -n items=${node[items]}

   node[name]=$name

   while ! check 'R_BRACE' ; do
      named
      items+=( $NODE )
   done

   munch 'R_BRACE' "expecting \`}' after section." 1>&2
   declare -g NODE=$save
}


function element {
   # Elements must be preceded by an identifier.
   local -- name=$NODE

   mk_element
   local -- save=$NODE
   local -n node=$NODE

   node[name]=$name

   if check 'IDENTIFIER' ; then
      typedef
      node[type]=$NODE
   fi

   if ! check ';' ; then
      data
      node[data]=$NODE
      munch 'SEMI' "expecting \`;' after element"
   fi

   declare -g NODE=$save
}


function typedef {
   # Store current `identifier' token. Reaching this method is contingent upon
   # the current token *being* an identifier, so we're safe.
   identifier ; advance
   local -- name=$NODE

   mk_typedef
   local -- save=$NODE
   local -n type_=$save

   type_[kind]=$name

   while match 'COLON' ; do
      typedef
      type_[subtype]=$NODE
   done

   declare -g NODE=$save
}


function validation {
   munch 'L_BRACE' "expecting \`{' to open validation block. Perhaps you forgot a \`;' closing the last element?"

   while ! check 'R_BRACE' ; do
      expr
   done

   munch 'R_BRACE' "expecting \`}' after validation block."
}


function data {
   case "${CURRENT[type]}" in
      'L_BRACKET')  advance ; array    ;;
      'INTEGER')    advance ; integer  ;;
      'STRING')     advance ; string   ;;
      'FALSE')      advance ; literal  ;;
      'TRUE')       advance ; literal  ;;
      'PATH')       advance ; path     ;;
   esac
}


function array {
   mk_array
   local -- save=$NODE
   local -n node=$NODE

   while ! check 'R_BRACKET' ; do
      data
      node+=( $NODE )
   done

   declare -g NODE=$save
   munch 'R_BRACKET' "expecting \`]' after array."
}


function identifier {
   mk_identifier
   local -n node=$NODE
   node=$CURRENT
}


function literal {
   mk_literal
   local -n node=$NODE
   node=$CURRENT
}


function integer {
   mk_integer
   local -n node=$NODE
   node=$CURRENT
}


function string {
   mk_string
   local -n node=$NODE
   node=$CURRENT
}


function path {
   mk_path
   local -n node=$NODE
   node=$CURRENT
}

#───────────────────────────────( expressions )─────────────────────────────────
# Thanks daddy Pratt.

#declare -gA prefix_binding_power=(
#   [NOT]='13'
#   [BANG]='13'
#   [MINUS]='13'
#)
#
#declare -gA NUD=(
#   [NOT]='expr_unary'
#   [BANG]='expr_unary'
#   [MINUS]='expr_unary'
#   [PATH]='expr_path'
#   [TRUE]='expr_boolean'
#   [FALSE]='expr_boolean'
#   [STRING]='expr_string'
#   [INTEGER]='expr_integer'
#   [IDENTIFIER]='expr_identifier'
#   [L_PAREN]='expr_group'
#)
#
#
#declare -gA LED=(
#   [OR]='expr_compop'
#   [AND]='expr_compop'
#   [EQ]='expr_binary'
#   [NE]='expr_binary'
#   [LT]='expr_binary'
#   [LE]='expr_binary'
#   [GT]='expr_binary'
#   [GE]='expr_binary'
#   [PLUS]='expr_binary'
#   [MINUS]='expr_binary'
#   [STAR]='expr_binary'
#   [SLASH]='expr_binary'
#   [L_PAREN]='expr_function'
#)
#
#declare -gA infix_binding_power=(
#   [OR]='3'
#   [AND]='3'
#   [EQ]='5'
#   [NE]='5'
#   [LT]='7'
#   [LE]='7'
#   [GT]='7'
#   [GE]='7'
#   [PLUS]='9'
#   [MINUS]='9'
#   [STAR]='11'
#   [SLASH]='11'
#   [L_PAREN]='13'
#)
#
#
#function expr {
#   local -i min_bp=${1:-1}
#
#   local -- fn=${nud[${CURRENT[type]}]}
#   if [[ -z $fn ]] ; then
#      echo "No NUD defined for ${CURRENT[type]}." 1>&2
#      exit -1 # TODO: Real escape codes here.
#   fi
#
#   local lhs="$NODE"
#   advance
#
#   while :; do
#      local -- op=$CURRENT ot=${CURRENT[type]}
#
#      local -i  rbp  lbp=${infix_binding_power[ot]:-0}
#      (( rbp = lbp + 1 )) 
#
#      if [[ $rbp -lt $min_bp ]] ; then
#         break
#      fi
#
#      advance
#
#      fn=${led[${CURRENT[type]}]}
#      $fn  "$lhs"  "$op"  "$rbp"
#
#      lhs=$NODE
#   done
#
#   declare -g NODE=$lhs
#}
#
#
#function expr_group {
#   parse 
#   munch 'R_PAREN' "expecting \`)' after group"
#}
#
#function expr_binary {
#   local -- lhs="$1" op="$2" rbp="$3"
#
#   mk_binary
#   local -- save=$NODE
#   local -n node=$NODE
#
#   expr "$rbp"
#
#   node[op]="$op"
#   node[left]="$lhs"
#   node[right]="$NODE"
#
#   declare -g NODE=$save
#}
#
#
#function expr_unary {
#   local -- op="$2" rbp="$3"
#
#   mk_binary
#   local -- save=$NODE
#   local -n node=$NODE
#
#   expr "$rbp"
#
#   node[op]="$op"
#   node[right]="$NODE"
#
#   declare -g NODE=$save
#}
#
#
#function expr_integer {
#   mk_integer
#   local -n node=$NODE
#   node=${CURRENT[value]}
#}
#
#
#function expr_literal {
#   mk_boolean
#   local -n node=$NODE
#   node=${CURRENT[value]}
#}
#
#
#function expr_path {
#   mk_boolean
#   local -n node=$NODE
#   node=${CURRENT[value]}
#}
#
#
#function expr_string {
#   mk_boolean
#   local -n node=$NODE
#   node=${CURRENT[value]}
#}
#
#
#function expr_identifier {
#   mk_identifier
#   local -n node=$NODE
#   node=${CURRENT[value]}
#}


#════════════════════════════════════╡ GO ╞═════════════════════════════════════
parse

(
   declare -p TYPEOF
   [[ -n ${!NODE_*} ]] && declare -p ${!NODE_*}
) | sort -V -k3
