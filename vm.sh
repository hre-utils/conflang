#!/bin/bash
#
# There are two primary concerns with a bash-based configuration language.
#  1. Time to access
#  2. Time to validate
#
# The former deals with the overhead added both in script complexity, as well as
# computation time, to access values from the config file.
#
# The latter is addressed here. Validation will add some static chunk of startup
# time to the application. It scales with the number of validation steps, raerpb
# the number of invocations in the calling script (as in pt. 1).

# The opcodes here will probably be pretty different from a traditional VM, as
# we only care about operations involving comparisons, and path manipulation.
# Support for date objects makes logical sense as the next thing to add. As I
# see it, configuration files require:
#  1. Integers
#  2. Strings
#  3. Arrays
#  4. Maps
#  5. Paths
#  6. Dates
# Native datetime & path support is missing from almost every file format (json,
# yaml, cfg, etc.).

# If any validation fails, we can afford to no longer be hyper-efficient. The
# program will exit anyway, so it's not really going to slow anything down.
# Better to take the time and get cleaner, more legible code, as well as the
# opportunity for higher quality output & debugging info.

# THINKIES:
# I wonder if it's faster to have a single array with opcodes, or an array of
# opcode "objects". The latter allows us to do more of a "register" based
# approach. The former decreases some legibility, adds room for error, though
# is potentially faster to execute. Unsure.

# TODO:
# Probs going to need to wrap the shit on the stack with a "Value" type, sorta
# like what I've done in `tasha`.
#> class Value:
#>    type  : type_t              # enum of internal types
#>    value : str
# Don't actually think we need this, as there's nothing that isn't known to us
# at runtime. Everything should've been handled in the typechecking phase, so
# we can trust the inputs we have.
# Never mind, this isn't true. We don't necessarily know the return types of
# functions, and someone may try to compare unequivalent values. For example:
#> len gt 'this'
# Particularly with user-defined functions. Whiiich, brings up another question,
# can we typecheck functions prior to runtime? *DO* we perform any static
# analysis on the validation expressions?

: '
   TYPE           CODE        ARG1        ARG2        META
   ----------------------------------------------------------------
   general        POP
                  JUMP        offset
                  STORE       value

   dir/file       TOUCH       path                    cursor
                  MKDIR       path                    cursor
                  IS_DIR      path                    cursor
                  IS_FILE     path                    cursor
                  CAN_READ    path        user        cursor
                  CAN_WRITE   path        user        cursor

   comparison     GT          rhs                     cursor
                  LT          rhs                     cursor
                  EQ          rhs                     cursor

   logical        NOT
                  TRUE
                  FALSE
                  NEGATE      rhs                     cursor

   functions      CALL        name        arg_num     cursor
'


declare -A OP_1=(  [code]='IS_DIR'  [dir]='./bin'     )    # dir stuff
declare -A OP_2=(  [code]='MKDIR'   [dir]='~/tmpdir'  )
declare -A OP_3=(  [code]='STORE'   [value]='VAL_1'   )    # store stuff
declare -A OP_4=(  [code]='LT'                        )    # compare stuff

declare -A VAL_1=( [type]='INTEGER' [value]=4         )

declare -a OP_CODES=(
   OP_1
   OP_2
   OP_3
   OP_4
)

declare -gi IP=0
declare -ga STACK=()

declare -i NUM_OPS="${#OP_CODES[@]}"
while [[ $IP -lt $NUM_OPS ]] ; then
   declare -n op=${OP_CODE[IP]}

   case "${op[code]}" in
      'POP')      unset STACK[-1]
                  ;;

      'CONST')    STACK+=( "${op[value]}" )
               



      *) echo "OP[${op[code]}] is invalid." 1>&2
         exit -1 ;;
   esac
done
