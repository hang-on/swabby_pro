echo off
::
:: NOTE: Depends on a special pico-8 colormap_cube.png being present in the folder.

SET folder="C:\Users\ANSJ\Dropbox\Apps\Sprite Something\"
SET filename1=spritesheet_1.png
SET filename2=spritesheet_2.png
SET output=spritesheet.png

:: Copy to this folder.
copy %folder%%filename1%
copy %folder%%filename2%

:: Use ImageMagick to insert the 16 pico-8 colors as the first 16 tiles of the
:: image (in order to preserve the correct palette in the tile conversion.)
convert colormap_cube.png  %filename1% -append %filename1%

:: Use ImageMagick to convert the image to 16 colors.
convert %filename1% -quantize RGB -remap colormap_cube.png  %filename1%

:: Crop away the colormap_cube.
:: convert %filename1% -crop 32x208+0+32 +repage %filename1%
:: convert %filename1% -map colormap_cube.png %filename1%

:: Append 8x8 sprites.
convert -append %filename1% %filename2% %output%


:: Use bmp2tile to make tiles out of the appended image.
bmp2tile.exe %output% -savetiles %output%_tiles.inc -fullpalette -spritepalette -noremovedupes -nomirror -tileoffset 128 -exit

:: Remove the comments and the first 32 lines (thus removing the tiles of the
:: color map).
for /f "skip=32 delims=*" %%a in (%output%_tiles.inc) do (
echo %%a >>newfile.txt
)
xcopy newfile.txt %output%_tiles.inc /y
del newfile.txt /f /q
del %filename1%
del %filename2%
del %output%
