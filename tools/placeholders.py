import sys
import os

from fontTools.misc.py23 import *
from fontTools.feaLib.parser import Parser

def parse(features):
    names = set()
    featurefile = UnicodeIO(tounicode(features))
    fea = Parser(featurefile, []).parse()
    for statement in fea.statements:
        if getattr(statement, "name", None) in ("isol", "ccmp"):
            for substatement in statement.statements:
                if hasattr(substatement, "glyphs"):
                    # Single
                    names.update(substatement.glyphs[0].glyphSet())
                elif hasattr(substatement, "glyph"):
                    # Multiple
                    names.add(substatement.glyph)

    return names

def build(font):
    names = parse(font.features.text)

    for name in sorted(names):
        glyph = font.newGlyph(name)
        glyph.unicode = int(name.lstrip('uni'), 16)
        glyph.width = glyph.leftMargin = glyph.rightMargin = 0
        # TODO, remove this once FontConfig is updated
        pen = glyph.getPen()
        pen.moveTo((-1, -1))
        pen.lineTo(( 1, -1))
        pen.lineTo(( 1,  1))
        pen.lineTo((-1,  1))
        pen.closePath()
