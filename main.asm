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

word:       
   .byte 0,0,0,0,0
   
start:
   lda #10
   sta $fd                    //loop counter

   lda #<dict                 //get pointer to dict
   sta $fb
   lda #>dict
   sta $fc

   lda #<word+2               //get pointer to wordlet result
   sta unpack_wordlet_result
   lda #>word+2
   sta unpack_wordlet_result+1

@start_loop:      
   ldy #0
!: lda ($fb),y                //get wordlet
   sta unpack_wordlet_wordlet,y
   iny
   cpy #3
   bne !-
   
   jsr unpack_wordlet         //unpack the wordlet
   ldy #0                     //print the wordlet
!: lda word+2,y
   jsr $ffd2
   iny
   cpy #3
   bne !-
   lda #$0d
   jsr $ffd2

   clc            	          //add 2 to dict pointer
   lda $fb
   adc #2
   sta $fb
   lda $fc
   adc #0
   sta $fc

   dec $fd
   bne @start_loop   
   rts                        //cannot reach


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
