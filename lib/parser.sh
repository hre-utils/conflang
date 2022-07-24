#!/bin/bash
#
# from ./lexer.sh import {
#  TOKENS[]             # Array of token names
#  TOKEN_$n             # Sequence of all token objects
#  FILE_LINES[]         # INPUT_FILE.readlines()
#  _FILES[]             # Array of imported files
#  _FILE                # Index of current file
# }

# THINKIES:
# The global variables need to not reset themselves when called again by
# constrained/imported functions. Maybe just wrap them in a:
#> [[ $_FILE -eq 0 ]]
#
# This will require scanning/parsing the included files. Probably easiests by
# wrapping the current `source <( source <( ... ))` w/ {lexer,parser}.sh into
# a function.
#
#> function pre_compile {
#>    source <(
#>       source <( source lexer.sh "$1" )
#>    )
#>    source parser.sh
#> }
#>
#> 
#> pre_compile
#> declare -- _root=$ROOT
#>
#> for parent_node_name in ${!INCLUDES[@]} ; do
#>    declare -n parent_node=$parent_node_name
#>    declare -n parent_items=${parent_node[items]}
#>
#>    declare -- path=${INCLUDES[$parent_node_name]
#>    for f in "${_FILES[@]}" ; do
#>       [[ "$path" == "$f" ]] && raise 'circular_dependency'
#>    done
#>
#>    _FILES+=( $path )
#>    _FILE=${#_FILES[@]}
#>
#>    pre_compile "$path"
#>    declare -- child_node_name=$ROOT
#>    declare -n child_node=$ROOT
#>
#>    declare -n items=${child_node[items]}
#>    for node in "${items[@]}" ; do
#>       parent_items+=( $node )
#>    done
#> done
#>
#> ROOT=$_root
#
#
# Turns out the above won't work. Even if you `declare -g` a variable, when
# dumping it with `declare -p`, it loses the global flag. Would need to regex
# every declaration to become global upon importing into the function.

# As I think more about it, there's no reason the user needs to source this file
# itself. Just the resulting data nodes, and the ./api.sh. Their program would
# begin something like:
#
#> conflang "config.cfg" > ./compiled.sh
#> source ./compiled.sh
#> source api.sh

#═════════════════════════════════╡ AST NODES ╞═════════════════════════════════
declare -g  ROOT  # Solely used to indicate the root of the AST. Imported by the
declare -g  NODE  #+compiler.
declare -gi _NODE_NUM=0

# `include` & `constrain` directives are handled by the parser. They don't
# actually create any "real" nodes. They leave sentinel values that are later
# resolved.
declare -g  INCLUDE         CONSTRAIN
declare -gi INCLUDE_NUM=0   CONSTRAIN_NUM=0
declare -gA INCLUDES=()     CONSTRAINTS=()
# These -----^ map a section node name to the path to the file they must parse.
#
# Example:
#> INCLUDES=([NODE_01]="./colors.conf"  [NODE_21]="./keybinds.conf")
#
# Iterate through the list of INCLUDES. Append all the children of the newly
# parsed ROOT.children to the key's .children. i.e.,
#
#> for parent, path in includes.items():
#>    root = parse(path)
#>    for node in root.children:
#>       parent.children.append(node)

# Saves us from a get_type() function call, or some equivalent.
declare -gA TYPEOF=()

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
   node[context]=
   
   TYPEOF[$nname]='decl_variable'
}


function mk_include {
   (( INCLUDE_NUM++ ))
   local   -- iname="INCLUDE_${INCLUDE_NUM}"
   declare -g $iname

   INCLUDES+=( $iname )
   declare -g INCLUDE=$iname
}


function mk_constrain {
   (( CONSTRAIN_NUM++ ))
   local   -- cname="CONSTRAIN_${CONSTRAIN_NUM}"
   declare -g $cname

   CONSTRAINTS+=( $cname )
   declare -g CONSTRAIN=$cname
}


function mk_context_block {
   (( _NODE_NUM++ ))
   local   --  nname="NODE_${_NODE_NUM}"
   declare -ga $nname
   declare -g  NODE=$nname

   local -n node=$nname
   node=()

   TYPEOF[$nname]='context_block'
}


function mk_context_test {
   (( _NODE_NUM++ ))
   local   -- nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   node[name]=

   TYPEOF[$nname]='context_test'
}


function mk_context_directive {
   (( _NODE_NUM++ ))
   local   -- nname="NODE_${_NODE_NUM}"
   declare -gA $nname
   declare -g  NODE=$nname
   local   -n  node=$nname

   node[name]=

   TYPEOF[$nname]='context_directive'
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


function mk_func_call {
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
   TYPEOF[$nname]='func_call'
}


#function mk_binary {
#   (( _NODE_NUM++ ))
#   local   --  nname="NODE_${_NODE_NUM}"
#   declare -ga $nname
#   declare -g  NODE=$nname
#   local   -n  node=$nname
#
#   node[op]=
#   node[left]=
#   node[right]=
#
#   TYPEOF[$nname]='binary'
#}


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
   node[file]=

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
   node[file]=

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
   node[file]=

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
   node[file]=

   TYPEOF[$nname]='path'
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
   node[file]=

   TYPEOF[$nname]='identifier'
}


#═══════════════════════════════════╡ utils ╞═══════════════════════════════════
declare -gi IDX=0
declare -g  CURRENT  CURRENT_NAME
declare -g  PEEK     PEEK_NAME
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
         declare -p $CURRENT_NAME 1>&2
         raise_syntax_error
      else
         break
      fi
   done

   (( ++IDX ))
}


function raise_syntax_error {
   local -- tname=${1:-$CURRENT_NAME}
   local -n t=$tname

   declare -p $CURRENT_NAME
   printf "[${t[lineno]}:${t[colno]}] There was an error.\n" 1<&2
   exit -1
}


function raise_parse_error {
   local -n t=$CURRENT_NAME
   local -- exp=$1
   local -- msg="${2:-Expected something else.}"

   declare -p $CURRENT_NAME
   printf "[${t[lineno]}:${t[colno]}] ${msg}\n" 1<&2
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
   name[file]="${_FILE}"

   mk_decl_section
   declare -g ROOT=$NODE
   local   -n node=$NODE
   local   -n items=${node[items]}

   node[name]=$nname

   while ! check 'EOF' ; do
      statement
      items+=( $NODE )
   done

   munch 'EOF'
}


function statement {
   if match 'PERCENT' ; then
      parser_directive
   else
      declaration
   fi
}


function parser_directive {
   if match 'INCLUDE' ; then
      include
   elif match 'CONSTRAIN' ; then
      constrain
   else
      # TODO: error reporting
      echo "${CURRENT[value]} is not a parser directive." 1>&2
      exit -1
   fi

   munch 'SEMI' "expecting \`;' after parser directive."
}


function include {
   mk_include
   local -n include=$NODE
   
   path
   munch 'PATH' "expecting path after %include."

   include=$NODE
   declare -g NODE=
   # Section declarations loop & append $NODEs to their .items. `include`/
   # `constrain` directives are technically children of a section, but they
   # do not live past the parser. Need to explicitly set $NODE to an empty
   # string, so they are not appended to the parent's .items[].
}


function constrain {
   mk_constrain
   local -n constrain=$NODE

   while ! check 'R_BRACKET' ; do
      path
      munch 'PATH' "expecting an array of paths."
      constrain+=( $NODE )
   done

   munch 'R_BRACKET' "expecting \`]' after constrain block."
   declare -g NODE=
   # Section declarations loop & append $NODEs to their .items. `include`/
   # `constrain` directives are technically children of a section, but they
   # do not live past the parser. Need to explicitly set $NODE to an empty
   # string, so they are not appended to the parent's .items[].
}


function declaration {
   identifier
   munch 'IDENTIFIER' "expecting variable declaration."

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
      statement
      items+=( $NODE )
   done

   munch 'R_BRACE' "expecting \`}' after section."
   declare -g NODE=$save
}


function decl_variable {
   # Variable declaration must be preceded by an identifier.
   local -- name=$NODE

   mk_decl_variable
   local -- save=$NODE
   local -n node=$NODE
   node[name]=$name

   # Typedefs.
   if check 'IDENTIFIER' ; then
      typedef
      node[type]=$NODE
   fi

   # Expressions.
   if ! check 'L_BRACE' ; then
      expression
      node[expr]=$NODE
   fi

   # Context blocks.
   if match 'L_BRACE' ; then
      context_block
      node[context]=$NODE
   fi

   # TODO: error reporting
   munch 'SEMI' "expecting \`;' after declaration."

   declare -g NODE=$save
}


function typedef {
   identifier
   munch 'IDENTIFIER' 'expecting identifier for typedef.'

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


# THINKIES: I believe a context block can potentially be a postfix expression.
# Though for now, as it only takes single directives and not expressions or
# function calls, it lives here.
function context_block {
   mk_context_block
   local -- save=$NODE
   local -n node=$NODE

   while ! check 'R_BRACE' ; do
      context
      node+=( $NODE )
   done

   munch 'R_BRACE' "expecting \`}' after context block."
   declare -g NODE=$save
}


function context {
   identifier
   munch 'IDENTIFIER' 'expecting identifier in context block.'

   local -- ident=$NODE

   if check 'QUESTION' ; then
      mk_context_test
   else
      mk_context_directive
   fi

   local -n node=$NODE
   node[name]=$ident
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
   node[file]=${CURRENT[file]}
}


function boolean {
   mk_boolean
   local -n node=$NODE
   node[value]=${CURRENT[value]}
   node[offset]=${CURRENT[offset]}
   node[lineno]=${CURRENT[lineno]}
   node[colno]=${CURRENT[colno]}
   node[file]=${CURRENT[file]}
}


function integer {
   mk_integer
   local -n node=$NODE
   node[value]=${CURRENT[value]}
   node[offset]=${CURRENT[offset]}
   node[lineno]=${CURRENT[lineno]}
   node[colno]=${CURRENT[colno]}
   node[file]=${CURRENT[file]}
}


function string {
   mk_string
   local -n node=$NODE
   node[value]=${CURRENT[value]}
   node[offset]=${CURRENT[offset]}
   node[lineno]=${CURRENT[lineno]}
   node[colno]=${CURRENT[colno]}
   node[file]=${CURRENT[file]}
}


function path {
   mk_path
   local -n node=$NODE
   node[value]=${CURRENT[value]}
   node[offset]=${CURRENT[offset]}
   node[lineno]=${CURRENT[lineno]}
   node[colno]=${CURRENT[colno]}
   node[file]=${CURRENT[file]}
}

#───────────────────────────────( expressions )─────────────────────────────────
# Thanks daddy Pratt.
#
# Had to do a little bit of tomfoolery with the binding powers. Shifted
# everything up by 1bp (+2), so the lowest is lbp=3 rbp=4.

declare -gA prefix_binding_power=(
   [NOT]=10
   [BANG]=10
   [MINUS]=10
)
declare -gA NUD=(
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


declare -gA infix_binding_power=(
   [OR]=3
   [AND]=3
   #[EQ]=5
   #[NE]=5
   #[LT]=7
   #[LE]=7
   #[GT]=7
   #[GE]=7
   #[PLUS]=9
   #[MINUS]=9
   #[STAR]=11
   #[SLASH]=11
   [L_PAREN]=13
)
declare -gA LED=(
   [OR]='compop'
   [AND]='compop'
   #[EQ]='binary'
   #[NE]='binary'
   #[LT]='binary'
   #[LE]='binary'
   #[GT]='binary'
   #[GE]='binary'
   #[PLUS]='binary'
   #[MINUS]='binary'
   #[STAR]='binary'
   #[SLASH]='binary'
   [L_PAREN]='func_call'
)


#declare -gA postfix_binding_power=(
#   [L_BRACE]=3
#   [QUESTION]=15
#)
#declare -gA RID=(
#   [L_BRACE]='context_block'
#   [QUESTION]='context_test'
#)


function expression {
   local -i min_bp=${1:-1}

   local -- lhs rhs op
   local -i lbp rbp

   local -- fn=${NUD[${CURRENT[type]}]}

   if [[ -z $fn ]] ; then
      echo "No NUD defined for ${CURRENT[type]}." 1>&2
      exit -1 # TODO: issue#6
   fi

   $fn ; lhs=$NODE

   # THINKIES:
   # I feel like there has to be a more elegant way of handling a semicolon
   # ending expressions.
   check 'SEMI' && return
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
   munch 'R_PAREN' "expecting \`)' after group."
}

function binary {
   local -- lhs="$1" op="$2" rbp="$3"

   mk_binary
   local -- save=$NODE
   local -n node=$NODE

   expression "$rbp"

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

   expression "$rbp"

   node[op]="$op"
   node[right]="$NODE"

   declare -g NODE=$save
}


#════════════════════════════════════╡ GO ╞═════════════════════════════════════
parse

(
   declare -p TYPEOF  ROOT
   declare -p _FILES  _FILE
   [[ -n ${!NODE_*} ]] && declare -p ${!NODE_*}
) | sort -V -k3 | sed -E 's;^declare -(-)?;declare -g;'
# It is possible to not use `sed`, and instead read all the sourced declarations
# into an array, and parameter substation them with something like:
#> shopt -s extglob
#> ${declarations[@]/declare -?(-)/declare -g}
