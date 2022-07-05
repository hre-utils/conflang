#!/bin/bash
#
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

function advance { echo -n '' ;}

function munch { echo -n '' ;}
