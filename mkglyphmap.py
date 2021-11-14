import sys
from glyphsLib import GSFont
from pathlib import Path

builddir = Path(sys.argv[2])
glyphmap_csv = ""

pua = 0xE000
font = GSFont(sys.argv[1])
for glyph in font.glyphs:
    if not glyph.export:
        continue
    style = Path(builddir.name)
    if not ("Images" / style / f"{glyph.name}.svg").is_file():
        continue
    if not glyph.unicode:
        uni = pua
        pua += 1
    else:
        uni = int(glyph.unicode, 16)
    glyphmap_csv += f"{builddir / glyph.name}.svg,{glyph.name},{uni:x}\n"

with open(f"{builddir / 'glyphmap.csv'}", "w") as fp:
    fp.write(glyphmap_csv)
