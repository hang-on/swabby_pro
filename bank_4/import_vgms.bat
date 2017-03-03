echo off
:: import_vgms.bat
::

SET folder=C:\Users\ANSJ\Documents\SMS\DefleMask2016\songs\Output\SMS\swabby_pro


:: Copy from deflemask folder to this folder.
copy %folder%\*.vgm

for /f %%f in ('dir /b %folder%\*.vgm') do call :loopbody %%f

goto :EOF

:loopbody
  set mystring=%1
  set mystring=%mystring:~0,-4%

  vgm2psg %mystring%.vgm %mystring%.psg
goto :eof


:EOF
