import sys
import os

from defcon import Font, Component
from fontTools.misc.py23 import *
from fontTools.feaLib.parser import Parser

def parse(features):
    subs = {}
    featurefile = UnicodeIO(tounicode(features))
    fea = Parser(featurefile, []).parse()
    for statement in fea.statements:
        if getattr(statement, "name", None) in ("isol", "ccmp"):
            for substatement in statement.statements:
                if hasattr(substatement, "glyphs"):
                    # Single
                    originals = substatement.glyphs[0].glyphSet()
                    replacements = substatement.replacements[0].glyphSet()
                    subs.update(dict(zip(originals, replacements)))
                elif hasattr(substatement, "glyph"):
                    # Multiple
                    subs[substatement.glyph] = substatement.replacement

    return subs

def addComponent(glyph, name, xoff=0, yoff=0):
    component = glyph.instantiateComponent()
    component.baseGlyph = name
    component.move((xoff, yoff))
    glyph.appendComponent(component)

def build(font):
    subs = parse(font.features.text)

    for name, names in subs.items():
        if isinstance(names, (str, unicode)):
            names = [names]
        baseGlyph = font[names[0]]
        glyph = font.newGlyph(name)
        glyph.unicode = int(name.lstrip('uni'), 16)
        glyph.width = baseGlyph.width
        glyph.leftMargin = baseGlyph.leftMargin
        glyph.rightMargin = baseGlyph.rightMargin
        addComponent(glyph, baseGlyph.name)
        for partName in names[1:]:
            partGlyph = font[partName]
            partAnchors = [a.name.replace("_", "", 1) for a in partGlyph.anchors if a.name.startswith("_")]
            baseAnchors = [a.name for a in baseGlyph.anchors if not a.name.startswith("_")]
            anchorName = set(baseAnchors).intersection(partAnchors)
            assert len(anchorName) > 0, (names[0], partName, partAnchors, baseAnchors)
            anchorName = list(anchorName)[0]
            partAnchor = [a for a in partGlyph.anchors if a.name == "_" + anchorName][0]
            baseAnchor = [a for a in baseGlyph.anchors if a.name == anchorName][0]
            xoff = baseAnchor.x - partAnchor.x
            yoff = baseAnchor.y - partAnchor.y
            addComponent(glyph, partName, xoff, yoff)
