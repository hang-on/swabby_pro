echo off
REM import_pico_sheet.bat

SET filename=spritesheet.png

:: Copy from pico-8 cart folder to this folder.
copy c:\users\ansj\dropbox\pico-8\carts\swabby_pro\%filename%


:: Use ImageMagick to convert the image to 16 colors.
convert -colors 16 %filename% %filename%

bmp2tile.exe %filename% -savetiles %filename%_tiles.inc -noremovedupes -nomirror -tileoffset 128 -exit 
