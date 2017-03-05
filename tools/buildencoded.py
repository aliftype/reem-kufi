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

def build(font):
    subs = parse(font.features.text)

    for name, names in subs.items():
        if isinstance(names, (str, unicode)):
            names = [names]
        base = names[0]
        if base in font.layers["Marks"]:
            base = font.layers["Marks"][base]
        else:
            base = font[base]
        glyph = font.newGlyph(name)
        glyph.unicode = int(name.lstrip('uni'), 16)
        glyph.width = base.width
        glyph.leftMargin = base.leftMargin
        glyph.rightMargin = base.rightMargin
        component = Component()
        component.baseGlyph = names[0]
        glyph.appendComponent(component)
        for baseComponent in base.components:
            if baseComponent.baseGlyph in names[1:]:
                component = Component()
                component.transformation = baseComponent.transformation
                component.baseGlyph = baseComponent.baseGlyph
                glyph.appendComponent(component)
