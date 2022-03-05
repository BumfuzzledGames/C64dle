/* C64dle, by Bumfuzzled Games
 * A totally original word game not based on any other
 * work at all. No siree, totally my idea. Not Josh Wardle or
 * anyone else. Nope, nothing to see here, move along.
 *
 * But no, really, this is a Wordle clone.
 */

BasicUpstart2(start)

hello:
   .text "HELLO, WORLD!"
   .byte 0

buffer:
   .byte 0,0,0
   
start:
   lda dict+2
   sta unpack_wordlet_wordlet
   lda dict+3
   sta unpack_wordlet_wordlet+1
   lda #<buffer
   sta unpack_wordlet_result
   lda #>buffer
   sta unpack_wordlet_result+1
   jsr unpack_wordlet

   ldy #0
!: lda buffer,y
   jsr $ffd2
   iny
   cpy #3
   bne !-
   rts


/* unpacks a wordlet
   parameters:
     unpack_wordlet_wordlet = wordlet
     unpack_wordlet_result = address of result
*/
unpack_wordlet:
   ldy #0
@loop:
   lda unpack_wordlet_wordlet
   and #%00011111             //get lower 5 bits
   clc
   adc #'A'                   //and add 'A'
   sta unpack_wordlet_result:$ffff,y
   ldx #5                     //shift by 5 bits
!: clc
   ror unpack_wordlet_wordlet+1
   ror unpack_wordlet_wordlet
   dex
   bne !-
   iny
   cpy #3
   bne @loop
   rts
unpack_wordlet_wordlet:           .byte 0,0
#import "dict.asm"
