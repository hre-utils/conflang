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
#  [ ] Tracebacks!
#      - What a good opportunity for me to work on that bash traceback nonsense
#        I was trying to figure out a while ago.
#  [x] I hate how `munch()` works right now
#  [x] OOPS I forgot booleans
#      - Just going to use true/false, not yaml's yes/no/1/0 nonsense
#
#---


:<<'COMMENT'
CURRENT.
   Seemingly getting an offset for variable declaration nodes. Haven't spent the
   time to figure out which values are wrong, and what the right ones should be,
   but it's definitely jumbly as shit.


GRAMMAR.
   program        -> decl EOF

   declaration    -> decl_sec
                   | decl_var

   decl_section   -> identifier '{' declaration* '}'

   decl_variable  -> identifier [type] [expression] [';' | validation]

   type           -> identifier (':' identifier)*

   validation     -> '{' expr_list '}'

   expr_list      -> expression (';' expression)*

   expression     -> array
                   | literal

   array          -> '[' expr_list ']'

   literal        -> string
                   | integer
                   | path
                   | boolean
COMMENT


#═════════════════════════════════╡ AST NODES ╞═════════════════════════════════
declare -- ROOT  # Solely used to indicate the root of the AST. Imported by the
declare -- NODE  #+compiler.
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


function mk_decl_section {
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
   TYPEOF[$nname]='decl_section'
}


function mk_decl_variable {
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   node[name]=       # identifier
   node[type]=       # type
   node[expr]=       # section, array, int, str, bool, path
   #node[validation]=
   
   TYPEOF[$nname]='decl_variable'
}


function mk_array {
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -ga $nname
   declare -g  NODE=$nname

   local -n node=$nname
   node=()

   TYPEOF[$nname]='array'
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

   TYPEOF[$nname]='typedef'
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
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   node[op]=
   node[right]=

   TYPEOF[$nname]='unary'
}


function mk_boolean {
   (( _NODE_NUM++ ))
   local   -- nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   # Copied over, so we can ditch the raw tokens after the parser.
   node[value]=
   node[offset]=
   node[lineno]=
   node[colno]=

   TYPEOF[$nname]='boolean'
}


function mk_integer {
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   # Copied over, so we can ditch the raw tokens after the parser.
   node[value]=
   node[offset]=
   node[lineno]=
   node[colno]=

   TYPEOF[$nname]='integer'
}


function mk_string {
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   # Copied over, so we can ditch the raw tokens after the parser.
   node[value]=
   node[offset]=
   node[lineno]=
   node[colno]=

   TYPEOF[$nname]='string'
}


function mk_path {
   (( _NODE_NUM++ ))
   local   -- nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   # Copied over, so we can ditch the raw tokens after the parser.
   node[value]=
   node[offset]=
   node[lineno]=
   node[colno]=

   TYPEOF[$nname]='identifier'
}


function mk_identifier {
   (( _NODE_NUM++ ))
   local   -- nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   # Copied over, so we can ditch the raw tokens after the parser.
   node[value]=
   node[offset]=
   node[lineno]=
   node[colno]=

   TYPEOF[$nname]='identifier'
}


#═══════════════════════════════════╡ utils ╞═══════════════════════════════════
declare -i IDX=0
declare -- CURRENT  CURRENT_NAME
declare -- PEEK     PEEK_NAME
# Calls to `advance' both globally set the name of the current/next node(s),
# e.g., `TOKEN_1', as well as declaring a nameref to the variable itself.


function advance { 
   while [[ $IDX -lt ${#TOKENS[@]} ]] ; do
      declare -g  CURRENT_NAME=${TOKENS[IDX]}
      declare -gn CURRENT=$CURRENT_NAME

      declare -g  PEEK_NAME=${TOKENS[IDX+1]}
      if [[ -n $PEEK_NAME ]] ; then
         declare -gn PEEK=$PEEK_NAME
      else
         declare -g PEEK=
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
   mk_identifier
   local -- nname=$NODE
   local -n name=$nname
   name[value]='%inline'
   name[offset]=0
   name[lineno]=0
   name[colno]=0

   mk_decl_section
   declare -g ROOT=$NODE
   local   -n node=$NODE
   local   -n items=${node[items]}

   node[name]=$nname

   while ! check 'EOF' ; do
      declaration
      items+=( $NODE )
   done

   munch 'EOF'
}


function declaration {
   identifier
   munch 'IDENTIFIER' "expecting variable declaration: identifier is missing." 1>&2

   if match 'L_BRACE' ; then
      decl_section
   else
      decl_variable
   fi
}


function decl_section {
   local -- name=$NODE

   mk_decl_section
   local -- save=$NODE
   local -n node=$NODE
   local -n items=${node[items]}

   node[name]=$name

   while ! check 'R_BRACE' ; do
      declaration
      items+=( $NODE )
   done

   munch 'R_BRACE' "expecting \`}' after section." 1>&2
   declare -g NODE=$save
}


function decl_variable {
   # Variable declaration must be preceded by an identifier.
   local -- name=$NODE

   mk_decl_variable
   local -- save=$NODE
   local -n node=$NODE

   node[name]=$name

   if check 'IDENTIFIER' ; then
      typedef
      node[type]=$NODE
   fi

   if ! check ';' ; then
      expression
      node[expr]=$NODE
      #munch 'SEMI' "expecting \`;' after variable declaration"
   #else validate
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
   munch 'L_BRACE' "expecting \`{' to open validation block. Perhaps you forgot a \`;' closing the last expression?"

   while ! check 'R_BRACE' ; do
      expr
   done

   munch 'R_BRACE' "expecting \`}' after validation block."
}


function array {
   munch 'L_BRACKET'

   mk_array
   local -- save=$NODE
   local -n node=$NODE

   while ! check 'R_BRACKET' ; do
      expression
      node+=( $NODE )
   done

   munch 'R_BRACKET' "expecting \`]' after array."
   declare -g NODE=$save
}


function identifier {
   mk_identifier
   local -n node=$NODE
   node[value]=${CURRENT[value]}
   node[offset]=${CURRENT[offset]}
   node[lineno]=${CURRENT[lineno]}
   node[colno]=${CURRENT[colno]}
}


function boolean {
   mk_boolean
   local -n node=$NODE
   node[value]=${CURRENT[value]}
   node[offset]=${CURRENT[offset]}
   node[lineno]=${CURRENT[lineno]}
   node[colno]=${CURRENT[colno]}
}


function integer {
   mk_integer
   local -n node=$NODE
   node[value]=${CURRENT[value]}
   node[offset]=${CURRENT[offset]}
   node[lineno]=${CURRENT[lineno]}
   node[colno]=${CURRENT[colno]}
}


function string {
   mk_string
   local -n node=$NODE
   node[value]=${CURRENT[value]}
   node[offset]=${CURRENT[offset]}
   node[lineno]=${CURRENT[lineno]}
   node[colno]=${CURRENT[colno]}
}


function path {
   mk_path
   local -n node=$NODE
   node[value]=${CURRENT[value]}
   node[offset]=${CURRENT[offset]}
   node[lineno]=${CURRENT[lineno]}
   node[colno]=${CURRENT[colno]}
}

#───────────────────────────────( expressions )─────────────────────────────────
# Thanks daddy Pratt.
#
# Had to do a little bit of tomfoolery with the binding powers. Shifted
# everything up by 1bp (+2), so the lowest is lbp=3 rbp=4.

declare -gA prefix_binding_power=(
   [NOT]='12'
   [BANG]='12'
   [MINUS]='12'
)

declare -gA NUD=(
   [EOF]='return'
   [SEMI]='return'
   # Ugh is this some silly shit. Ensures that we return from expression parsing
   # if we hit a ';', or an EOF. Don't think this is the best way of doing it,
   # but there's a certain perverse elegance I guess.

   [NOT]='unary'
   [BANG]='unary'
   [MINUS]='unary'
   [PATH]='path'
   [TRUE]='boolean'
   [FALSE]='boolean'
   [STRING]='string'
   [INTEGER]='integer'
   [IDENTIFIER]='identifier'
   [L_PAREN]='group'
   [L_BRACKET]='array'
)


declare -gA LED=(
   [OR]='compop'
   [AND]='compop'
   [EQ]='binary'
   [NE]='binary'
   [LT]='binary'
   [LE]='binary'
   [GT]='binary'
   [GE]='binary'
   [PLUS]='binary'
   [MINUS]='binary'
   [STAR]='binary'
   [SLASH]='binary'
   [L_PAREN]='function'
)

declare -gA infix_binding_power=(
   [OR]='3'
   [AND]='3'
   [EQ]='5'
   [NE]='5'
   [LT]='7'
   [LE]='7'
   [GT]='7'
   [GE]='7'
   [PLUS]='9'
   [MINUS]='9'
   [STAR]='11'
   [SLASH]='11'
   [L_PAREN]='13'
)


function expression {
   local -i min_bp=${1:-1}

   local -- lhs rhs op
   local -i lbp rbp

   local -- fn=${NUD[${CURRENT[type]}]}
   if [[ -z $fn ]] ; then
      echo "No NUD defined for ${CURRENT[type]}." 1>&2
      exit -1 # TODO: Real escape codes here.
   fi

   $fn ; lhs=$NODE
   advance

   while :; do
      op=$CURRENT ot=${CURRENT[type]}

      # If not unset, or explicitly set to 0, `rbp` remains set through each
      # pass of the loop. They are local to the function, but while loops do not
      # have lexical scope. I should've known this. Have done an entire previous
      # project on the premise of lexical scoping in bash.
      rbp=0 ; lbp=${infix_binding_power[ot]:-0}
      (( rbp = (lbp == 0 ? 0 : lbp+1) ))

      if [[ $rbp -lt $min_bp ]] ; then
         break
      fi

      advance

      fn=${LED[${CURRENT[type]}]}
      if [[ -z $fn ]] ; then
         echo "No LED defined for ${CURRENT[type]}." 1>&2
         exit -2 # TODO: Real escape codes here.
      fi
      $fn  "$lhs"  "$op"  "$rbp"

      lhs=$NODE
   done

   declare -g NODE=$lhs
}


function group {
   expression 
   munch 'R_PAREN' "expecting \`)' after group"
}

function binary {
   local -- lhs="$1" op="$2" rbp="$3"

   mk_binary
   local -- save=$NODE
   local -n node=$NODE

   expr "$rbp"

   node[op]="$op"
   node[left]="$lhs"
   node[right]="$NODE"

   declare -g NODE=$save
}


function unary {
   local -- op="$2" rbp="$3"

   mk_binary
   local -- save=$NODE
   local -n node=$NODE

   expr "$rbp"

   node[op]="$op"
   node[right]="$NODE"

   declare -g NODE=$save
}


#════════════════════════════════════╡ GO ╞═════════════════════════════════════
parse

(
   declare -p ROOT
   declare -p TYPEOF
   [[ -n ${!NODE_*} ]] && declare -p ${!NODE_*}
) | sort -V -k3
