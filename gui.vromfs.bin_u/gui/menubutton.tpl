menu_button<<#isInactive>>_inactive<</isInactive>>
{
  id:t='<<buttonId>>'
  text:t='<<buttonText>>'
  _on_click:t='<<onClick>><<^isFlightMenu>>_<</isFlightMenu>>'
  <<#isFocus>>focus:t='yes'<</isFocus>>
  <<#brBefore>>margin-top:t='@flightMenuBrHeight'<</brBefore>>
  <<#brAfter>>margin-bottom:t='@flightMenuBrHeight'<</brAfter>>
  menu_button_img{}
  <<#timer>>
  behavior:t='Timer'
  timer_handler_func:t='<<timerFunc>>'
  timer_interval_msec:t='<<timerDelay>>'
  <</timer>>
}
