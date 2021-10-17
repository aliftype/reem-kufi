import sys
from glyphsLib import GSFont

codepointmap_csv = ""
glyphnamemap_csv = ""

pua = 0xE000
font = GSFont(sys.argv[1])
for glyph in font.glyphs:
    if not glyph.export:
        continue
    c = glyph.unicode and int(glyph.unicode, 16) or pua
    n = f"{c:x}"
    if not n[0].isalpha():
        n = "g_" + n
    codepointmap_csv += f"{glyph.name}.svg,{c:x}\n"
    glyphnamemap_csv += f"{glyph.name},{n.lower()}\n"
    if not glyph.unicode:
        pua += 1

with open(f"{sys.argv[2]}/glyphnamemap.csv", "w") as fp:
    fp.write(glyphnamemap_csv)

with open(f"{sys.argv[2]}/codepointmap.csv", "w") as fp:
    fp.write(codepointmap_csv)
