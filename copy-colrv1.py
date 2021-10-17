import copy
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.t2CharStringPen import T2CharStringPen


base_font = TTFont(sys.argv[1])
colr_font = TTFont(sys.argv[2])

base_go = base_font.getGlyphOrder()
colr_go = colr_font.getGlyphOrder()

glyphmap = {}
with open(sys.argv[3]) as fp:
    for line in fp.readlines():
        base_name, colr_name = line.strip().split(",")
        glyphmap[colr_name] = base_name


def glyph_name(n):
    if n in glyphmap:
        return glyphmap[n]
    if "." in n:
        b, e = n.split(".", 1)
        if b in glyphmap:
            return glyphmap[b] + ".colr" + e
    return n


# Rename color glyphs before copying
colr_go = [glyph_name(n) for n in colr_go]
colr_font = TTFont(sys.argv[2])
colr_font.setGlyphOrder(colr_go)
colr_topDict = colr_font["CFF "].cff.topDictIndex[0]
colr_topDict.charset = colr_go
colr_topDict.CharStrings.charStrings = {
    glyph_name(n): v for n, v in colr_topDict.CharStrings.charStrings.items()
}

# Copy new color glyphs
base_hmtx = base_font["hmtx"]
colr_hmtx = colr_font["hmtx"]
topDict = base_font["CFF "].cff.topDictIndex[0]
colr_gs = colr_font.getGlyphSet()
for name in colr_go:
    if not name[0] == "." and name not in base_go:
        glyph = colr_gs[name]
        pen = T2CharStringPen(glyph.width, colr_gs)
        glyph.draw(pen)
        topDict.charset.append(name)
        topDict.CharStrings.charStringsIndex.items.append(None)
        i = len(topDict.CharStrings.charStringsIndex) - 1
        topDict.CharStrings.charStringsIndex[i] = pen.getCharString(
            private=topDict.Private
        )
        topDict.CharStrings.charStrings[name] = i

        base_hmtx.metrics[name] = copy.deepcopy(colr_hmtx.metrics[name])

# Copy color tables
for tag in {"COLR", "CPAL"}:
    base_font[tag] = copy.deepcopy(colr_font[tag])


base_font.save(sys.argv[4])
