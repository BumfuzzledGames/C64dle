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
encoded_word:
   .byte 0,0,0,0

buffer:     .fill 6,0
.const buffer_len = *-buffer

start: {
   sei                        //disable BASIC ROM
   lda $1
   and #%11111110
   sta $1
   cli

   //jsr load_dictionary
   //bcs done

   mov #5:read_string._buffer_len
   m16 #buffer:read_string._buffer
   jsr read_string
   m16 #buffer:print._string
   jsr print

done:      
!: sei                        //enable BASIC ROM
   lda $1
   ora #%00000001
   sta $1
   cli

   rts
}


load_dictionary: {
   m16 #str_loading:print._string
   jsr print
   lda #10                    //SETNAM DICTIONARY
   ldx #<str_dictionary_filename
   ldy #>str_dictionary_filename
   jsr KERNAL_SETNAM
   lda #1                     //SETLFS
   ldx $ba                    //last used device
   bne !+
   lda #8                     //default drive 8
!: ldy #0                     //load to new address
   jsr KERNAL_SETLFS
   ldx #<dict                 //LOAD
   ldy #>dict
   lda #0
   jsr KERNAL_LOAD
   bcs error
   m16 #str_done:print._string
   jsr print
   clc
   rts
error:
   m16 #str_error:print._string
   jsr print
   sec
   rts
str_loading:
   .text "LOADING "
str_dictionary_filename:
   .text "DICTIONARY...   "
   .byte 0
str_done:
   .text "DONE"
   .byte $0d, 0
str_error:
   .text "ERROR"
   .byte $0d, 0
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

            
// Decode next word into next_word:_word
next_word: {
   ldx #3                     //copy word into scratch
!: lda _dict:dict,x
   sta scratch,x
   dex
   bpl !-

   ldy #0                     //letter counter
next_letter:
   ldx #5                     //5 bits
   lda #0
next_bit:
   rol scratch+3
   rol scratch+2
   rol scratch+1
   rol scratch
   rol
   dex
   bne next_bit
   cmp #%00011111             //terminator? I hardly know 'er!
   beq endword
   adc #'A'                   //baudot to PETSCII
   sta _word:word,y           //store letter
   iny
   cpy #5                     //produce 5 letters
   bne next_letter
   clc                        //advance to next word
   lda _dict
   adc #4
   sta _dict
   bcc !+
   inc _dict+1
!: clc
   rts
endword:
   sec
   rts
scratch:
   .byte 0,0,0,0
}              

            
// Print zero-terminated print:_string using print:_printer
print: {
   ldx #0
!: lda _string:$ffff,x
   beq !+
   jsr _printer:KERNAL_CHROUT
   inx
   jmp !-
!: rts
}                      


// Read a string using _getin
read_string: {
   ldx #0                     //initialize idx
loop:
   txa                        //preserve x (no phx? really?)
   pha
!: jsr _getin:KERNAL_GETIN
   beq !-
   tay                        //restore x, don't mangle a
   pla
   tax
   tya

   cmp #$0d                   //done when return is pressed ...
   bne !+
   cpx _buffer_len            //and at end of buffer
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

!: jmp _check_mode:check_mode_check
check_mode_check:
   ldy #0                     //idx into check string
!: cpy _check_string_len:#26
   beq loop                   //end of check string, bail
   cmp _check_string:alpha,y
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
   cpx _buffer_len:#$ff       //end of buffer?
   beq !+
force_store:
   sta _buffer:$ffff,x        //store character
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
alpha:
   .text "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
}



dict:                           //dict is at end of program
