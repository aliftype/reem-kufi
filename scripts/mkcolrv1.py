import argparse
import copy
import re
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.ttGlyphPen import TTGlyphPen


def copy_CFF_glyphs(colr_font, base_font):
    colr_go = colr_font.getGlyphOrder()
    colr_gs = colr_font.getGlyphSet()
    base_go = base_font.getGlyphOrder()
    topDict = base_font["CFF "].cff.topDictIndex[0]
    base_hmtx = base_font["hmtx"]
    colr_hmtx = colr_font["hmtx"]
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

            base_hmtx.metrics[name] = colr_hmtx.metrics[name]


def copy_glyf_glyphs(colr_font, base_font):
    colr_go = colr_font.getGlyphOrder()
    colr_gs = colr_font.getGlyphSet()
    base_go = base_font.getGlyphOrder()
    base_glyf = base_font["glyf"]
    base_hmtx = base_font["hmtx"]
    colr_hmtx = colr_font["hmtx"]
    for name in colr_go:
        if not name[0] == "." and name not in base_go:
            glyph = colr_gs[name]
            pen = TTGlyphPen(colr_gs)
            glyph.draw(pen)
            base_glyf[name] = pen.glyph()

            base_hmtx.metrics[name] = colr_hmtx.metrics[name]


def make(args):
    base_font = TTFont(args.base)
    colr_font = TTFont(args.colr)
    svg_font = TTFont(args.svg)

    base_go = base_font.getGlyphOrder()
    colr_go = colr_font.getGlyphOrder()

    # Copy new color glyphs
    if "CFF " in colr_font:
        copy_CFF_glyphs(colr_font, base_font)
    else:
        copy_glyf_glyphs(colr_font, base_font)

    # Copy color tables
    for tag in {"COLR", "CPAL"}:
        base_font[tag] = copy.deepcopy(colr_font[tag])
    for tag in {"SVG "}:
        base_font[tag] = copy.deepcopy(svg_font[tag])

    color_map = {
        "#404040FF": "#8E0B14FF", # reddish ink
        "#808080FF": "#C7060AFF", # same ink, 25% lighter
    }

    # Add alternate default palette.
    palettes = base_font["CPAL"].palettes
    palettes.append([])
    for color in palettes[0]:
        if color.hex() in color_map:
            palettes[-1].append(color.fromHex(color_map[color.hex()]))
        else:
            palettes[-1].append(color)
    base_font["CPAL"].palettes = [palettes[1], palettes[0]]

    for doc in base_font["SVG "].docList:
        for old, new in color_map.items():
            print(old[:-2], new[:-2])
            doc.data = doc.data.replace(old[:-2], new[:-2])

    name = base_font["name"]
    psname = args.output.stem
    family = re.sub("([A-Z])", r" \1", psname.split("-")[0]).strip()
    old_psname = str(name.getName(6, 3, 1))
    old_family = str(name.getName(1, 3, 1))
    for rec in name.names:
        if rec.nameID in (1, 3, 4, 6):
            rec.string = (
                str(rec).replace(old_family, family).replace(old_psname, psname)
            )

    return base_font


def main():
    from pathlib import Path

    parser = argparse.ArgumentParser(description="Rename Reem Kufi color fonts.")
    parser.add_argument("base", metavar="FILE", help="input font to process")
    parser.add_argument("colr", metavar="FILE", help="COLRv1 font to copy tables from")
    parser.add_argument("svg", metavar="FILE", help="SVG font to copy tables from")
    parser.add_argument("output", type=Path, help="output font to write")

    args = parser.parse_args()

    font = make(args)
    font.save(args.output)


if __name__ == "__main__":
    main()
