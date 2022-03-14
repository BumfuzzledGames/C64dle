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

.function scrpos(x,y) {
  .return 1024+y*40+x
}
.function clrpos(x,y) {
  .return $d800+y*40+x
}