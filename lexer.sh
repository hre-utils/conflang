#!/bin/bash
#
# NOTES:
# I've opted to putting globally declared variables under each section to which
# they principally belong. Example CHARRAY (array of characters from the input
# file) and FILE_LINES (each line of the source file) are declared under the
# `SCANNER' section. The exception are vars used throughout the entire file,
# such as the TOKENS array.

set -e

#══════════════════════════════════╡ GLOBALS ╞══════════════════════════════════
INPUT_FILE="${1:-/dev/stdin}"

PROGDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" ; pwd )
source "${PROGDIR}/errors.sh"

declare -a ERRORS=()
declare -A COMPILE_ERROR=(
   # All errors are defined in the ./errors.sh file. Easier to define them in a
   # single place, both for lookup, and ensuring the same exit status isn't used
   # twice.
   [SYNTAX_ERROR]=${COMPILE_ERROR__SYNTAX_ERROR}
)

declare -a TOKENS=()
declare -i TOKEN_NUM=0

# `Cursor' object to track our position when iterating through the input.
# `Freeze' saves the position at the start of each scanner loop, recording the
# start position of each Token.
declare -A FREEZE CURSOR=(
   [offset]=-1    # Starts at -1, as the first call to advance increments to 0.
   [lineno]=1
   [colno]=1
)


function Token {
   local type=$1  value=$2
   
   # Realistically we can just do "TOKEN_$(( ${#TOKEN_NUM[@]} + 1 ))". Feel like
   # that add visual complexity here, despite removing slight complexity of yet
   # another global variable.
   local tname="TOKEN_${TOKEN_NUM}"
   declare -gA "${tname}"

   # Nameref to newly created global token.
   declare -n t="$tname"
   t[type]="$type"
   t[value]="$value"

   # TODO:
   # Cursor information. Not sure if I'm going to actually use this at first.
   # Feels like it's adding initlaly unneeded complexity.
   #t[offset]=${FREEZE[offset]}
   #t[lineno]=${FREEZE[lineno]}
   #t[colno]=${FREEZE[colno]}

   TOKENS+=( "$tname" ) ; (( TOKEN_NUM++ ))
}

                                     
#══════════════════════════════════╡ SCANNER ╞══════════════════════════════════
declare -- CURRENT PEEK
declare -a CHARRAY=()      # Array of each character in the file.
declare -a FILE_LINES=()   # The input file lines, for better error reporting.

function advance {
   # Advance cursor position, pointing to each sequential character. Also incr.
   # the column number indicator. If we go to a new line, it's reset to 0.
   #
   # NOTE: So this has some of the silliest garbage of all time. In bash, using
   # ((...)) for arithmetic has a non-0 return status if the result is 0. E.g.,
   #> (( 1 )) ; echo $?    #  0
   #> (( 2 )) ; echo $?    #  0
   #> (( 0 )) ; echo $?    #  1
   # So the stupid way around this... add an `or true`. This is the short form:
   (( ++CURSOR[offset] )) ||:
   (( ++CURSOR[colno]  ))

   # This is a real dumb use of bash's confusing array indexing.
   CURRENT=${CHARRAY[CURSOR[offset]]}
   PEEK=${CHARRAY[CURSOR[offset]+1]}

   if [[ CURRENT == $'\n' ]] ; then
      ((CURSOR[lineno]++))
      CURSOR[colno]=0
   fi
}


function scan {
   # For easier lookahead, read all characters first into an array. Allows us
   # to seek/index very easily.
   while read -rN1 character ; do
      CHARRAY+=( "$character" )
   done < "$INPUT_FILE"

   while [[ ${CURSOR[offset]} -lt ${#CHARRAY[@]} ]] ; do
      advance
      [[ -z "$CURSOR" ]] && break

      # Save current cursor information.
      FREEZE[offset]=CURSOR[offset]
      FREEZE[lineno]=CURSOR[lineno]
      FREEZE[colno]=CURSOR[colno]

      # Skip comments.
      if [[ "$CURRENT" == '#' ]] ; then
         comment ; continue
      fi

      # Skip whitespace.
      if [[ "$CURRENT" =~ [[:space:]] ]] ; then
         continue
      fi

      # Symbols.
      case "$CURRENT" in
         ':')  Token      'COLON' "$CURRENT"  && continue ;;
         '(')  Token    'L_PAREN' "$CURRENT"  && continue ;;
         ')')  Token    'R_PAREN' "$CURRENT"  && continue ;;
         '[')  Token    'L_BRACE' "$CURRENT"  && continue ;;
         ']')  Token    'R_BRACE' "$CURRENT"  && continue ;;
         '{')  Token  'L_BRACKET' "$CURRENT"  && continue ;;
         '}')  Token  'R_BRACKET' "$CURRENT"  && continue ;;
         '<')  Token       'LESS' "$CURRENT"  && continue ;;
         '>')  Token    'GREATER' "$CURRENT"  && continue ;;
      esac

      # Can do a dedicated error pass, scanning for error tokens, and assembling
      # the context to print useful debug messages.
      Token 'ERROR' "$CURRENT"
   done

   Token 'EOF'
}


function comment {
   echo -n #pass
}



scan
