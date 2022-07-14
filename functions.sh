#!/bin/bash
#
# Create dicts required to make functions, as well as the standard by which
# they should all adhere.
#
# Mostly at this point this is just thinkies and drafts.
#
# THINKIES:
# User must be able to create & import their own functions. Probably going to
# need to extend the syntax somewhat. Maybe some pre-determined "internal"
# sections, to control the behavior of `conflang` itself.


# Hmmm. Having trouble thinking through how a user would easily provide their
# created functions.
#
# Maybe if each file is structured like:
#> $ cat ./$FUNC_NAME
#>
#> function $FUNC_NAME {
#>    ...
#> }
#>
#> declare -A meta (
#>    [arity]= 
#>    [returns]= 
#> )
