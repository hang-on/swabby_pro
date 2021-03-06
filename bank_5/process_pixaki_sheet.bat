echo off
:: process_pixaki_sheet.bat
:: This tool is used to grab an exported spritesheet from pixaki and convert
:: it to tiles for GG programming. Adjust the folder and/or filename below as
:: appropriate.
:: NOTE: Depends on a special pico-8 colormap.png being present in the folder.

SET folder=c:\users\ansj\dropbox\_SMS\pixaki\
SET filename=spritesheet3.png

:: Copy from pixaki folder to this folder.
copy %folder%%filename%

:: Use ImageMagick to insert the 16 pico-8 colors as the first 16 tiles of the
:: image (in order to preserve the correct palette in the tile conversion.)
convert colormap.png  %filename% -append %filename%

:: Use ImageMagick to convert the image to 16 colors.
convert %filename% -quantize RGB -remap colormap.png  %filename%


:: Use bmp2tile to make tiles out of the appended image.
bmp2tile.exe %filename% -savetiles %filename%_tiles.inc -fullpalette -spritepalette -noremovedupes -nomirror -tileoffset 128 -exit
