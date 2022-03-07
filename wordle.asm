/* C64dle, by Bumfuzzled Games
 * A totally original word game not based on any other
 * work at all. No siree, totally my idea. Not Josh Wardle or
 * anyone else. Nope, nothing to see here, move along.
 *
 * But no, really, this is a Wordle clone.
 */

BasicUpstart2(start)
#import "kernal.inc"

.pseudocommand mov a1:a2 { lda a1; sta a2 }
.pseudocommand m16 src:tar {
  lda src
  sta tar
  lda _16bit_nextArgument(src)
  sta _16bit_nextArgument(tar)
}

.function _16bit_nextArgument(arg) {
  .if (arg.getType()==AT_IMMEDIATE) .return CmdArgument(arg.getType(),>arg.getValue())
  .return CmdArgument(arg.getType(),arg.getValue()+1)
}

word:       
   .byte 0,0,0,0,0,0

buffer:     .fill 8,0
.const buffer_len = *-buffer

str_alpha:
str_alpha_numeric:            
   .text "abcdefghijklmnopqrstuvwxyz"
   .text "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
.const str_alpha_len = *-str_alpha
str_numeric:
   .text "0123456789"
.const str_numeric_len = *-str_numeric
.const str_alpha_numeric_len = *-str_alpha

str_end_word:
   .text "AAAAA"
.const str_end_word_len = *-str_end_word

str_loading:
   .text "LOADING "      
str_dictionary_filename:
   .text "DICTIONARY...  "
   .byte 0
str_done:
   .text "DONE"
   .byte $0d, 0
str_not_same:
   .text "NOT "
str_same:
   .text "SAME"
   .byte 0


start: {
       /*
   m16 #str_end_word:string_compare.stra
   m16 #str_end_word:string_compare.strb
   mov #5:string_compare.length
   m16 #str_same:print.string
   jsr string_compare
   beq !+
   m16 #str_not_same:print.string
!: jsr print
   rts
*/

   sei                        //disable BASIC ROM
   lda $1
   and #%11111110
   sta $1
   cli
   
   m16 #str_loading:print.string
   jsr print

   lda #10                    //SETNAM DICTIONARY
   ldx #<str_dictionary_filename
   ldy #>str_dictionary_filename
   jsr KERNAL_SETNAM
   lda #1                     //SETLFS
   ldx $ba                    //last device used
   bne !+
   ldx #8                     //default to drive 8
!: ldy #0                     //load to new address
   jsr KERNAL_SETLFS
   ldx #<dict                 //LOAD
   ldy #>dict
   lda #0
   jsr KERNAL_LOAD
   bcs done

   m16 #str_done:print.string
   jsr print

   /*
   ldx #0                     //decode 5 letters

!: lda #0
   ldy #5                     //gimme 5 bits
!: rol dict+3
   rol dict+2
   rol dict+1
   rol dict
   rol
   dey
   bne !-
   clc
   adc #'A'
   sta word,x
   inx
   cpx #5
   bne !--
    */

   m16 #str_end_word:string_compare.stra
   m16 #word:string_compare.strb
   mov #5:string_compare.length

!: jsr next_word
   jsr string_compare
   beq !+
   m16 #word:print.string
   jsr print
   lda #' '
   jsr KERNAL_CHROUT
   jsr KERNAL_CHROUT
   jsr KERNAL_CHROUT
   jmp !-
   
!: sei                        //enable BASIC ROM
   lda $1
   ora #%00000001
   sta $1
   cli

done:      
   rts
}


string_compare: {
   ldx #0
!: lda stra:$ffff,x
   cmp strb:$ffff,x
   bne !+
   inx
   cpx length:#0
   bne !-
!: rts
}             

next_word: {
   ldy #0                     //5 letters
next_letter:   
   tya
   pha                        //store x
   ldy #5                     //shift 5 bits
   clc
   lda #0
next_bit:      
   ldx #3                     //through 4 characters
   jmp !++                    //don't restore carry first time
!: plp                        //restore carry bit
!: rol _dict:dict,x
   php                        //save carry bit
   dex
   cpx #$ff
   bne !--
   plp                        //pop carry
   rol                        //into accumulator
   dey
   bne next_bit
   adc #'A'
   tax
   pla                        //restore outer loop counter
   tay
   txa
   sta _word:word,y
   iny
   cpy #5
   bne next_letter
   clc                        //advance to next word
   lda _dict
   adc #4
   sta _dict
   bcc !+
   inc _dict+1
!: rts
}              
   
   


print: {
   ldx #0
!: lda string:$ffff,x
   beq !+
   jsr printer:KERNAL_CHROUT
   inx
   jmp !-
!: rts
}                      
            
/*
start:
   :mov #alphanumeric_len:read_string.check_string_len
   :m16 #alpha:read_string.check_string
   :mov #read_string.check_mode_check:read_string.check_mode
   :mov #buffer_len-1:read_string.max_string_len
   :m16 #buffer:read_string.buffer
   jsr read_string
   lda #$0d
   jsr KERNAL_CHROUT
   ldx #0
!: lda sentry,x               
   cmp #0
   beq !+
   jsr KERNAL_CHROUT
   inx
   jmp !-
!: rts
*/

/*   
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
*/

/* unpacks a wordlet
   parameters:
     unpack_wordlet_wordlet = wordlet
     unpack_wordlet_result = address of result
*/
unpack_wordlet: {
   ldy #0
@loop:
   lda wordlet
   and #%00011111             //get lower 5 bits
   clc
   adc #'A'                   //and add 'A'
   sta result:$ffff,y
   ldx #5                     //shift by 5 bits
!: clc
   ror wordlet+1
   ror wordlet
   dex
   bne !-
   iny
   cpy #3
   bne @loop
   rts
wordlet:
   .word 0
}


read_string: {
   ldx #0                     //initialize idx

loop:
   txa                        //preserve x (no phx? really?)
   pha
!: jsr getin:KERNAL_GETIN
   beq !-
   tay                        //restore x, don't mangle a
   pla
   tax
   tya

   cmp #$0d                   //done when return is pressed
   bne !+
   lda #0                     //store a nul
   jsr force_store
   rts

!: cmp #$14                   //handle delete specially
   bne !+
   cpx #0                     //do nothing if at begin
   beq loop
   jsr echo
   dex                        //move tail back and store nul
   lda #0
   jsr store
   dex                        //move tail back again
   jmp loop

!: jmp check_mode:check_mode_no_check
check_mode_check:
   ldy #0                     //idx into check string
!: cpy check_string_len:#$ff
   beq loop                   //end of check string, bail
   cmp check_string:$ffff,y
   beq check_ok
   iny
   jmp !-
check_mode_no_check:        
check_ok:
   jsr store
   cpy #0                     //did it store?
   beq !+
   jsr echo
!: jmp loop

store:                        //returns success in y
   ldy #0
   cpx max_string_len:#$ff    //end of buffer?
   beq !+
force_store:
   sta buffer:$ffff,x         //store character
   inx
   ldy #1                     //success
!: rts                        

echo:
   cmp #$14                   //pass delete through
   beq force_echo
   jmp echo_mode:echo_mode_read_char
echo_mode_fixed_char:         
   lda echo_char:#'*'
echo_mode_read_char:          
force_echo:      
   jsr chrout:KERNAL_CHROUT
   rts
}

dict:                           //dict is at end of program
