/* C64dle, by Bumfuzzled Games
 * A totally original word game not based on any other
 * work at all. No siree, totally my idea. Not Josh Wardle or
 * anyone else. Nope, nothing to see here, move along.
 *
 * But no, really, this is a Wordle clone.
 */

BasicUpstart2(start)

hello:      .text "HELLO, WORLD!"; .byte 0

start:      
   rts

#import "dict.asm"
