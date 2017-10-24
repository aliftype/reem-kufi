#!/usr/bin/env python
# encoding: utf-8

import argparse

from datetime import datetime
from operator import attrgetter

from defcon import Font, Component
from fontTools.feaLib import ast, parser
from fontTools.misc.py23 import *
from fontTools.misc.transform import Transform

from placeholders import build as addPlaceHolders

def merge(args):
    arabic = Font(args.arabicfile)

    latin = Font(args.latinfile)

    addPlaceHolders(arabic)

    unicodes = []
    for glyph in arabic:
        unicodes.extend(glyph.unicodes)

    for name in latin.glyphOrder:
        if name in ("space", "nbspace", "CR", "NULL", ".notdef"):
            continue
        glyph = latin[name]
        assert glyph.name not in arabic, glyph.name
        assert glyph.unicode not in unicodes
        arabic.insertGlyph(glyph)

    # Copy kerning and groups.
    arabic.groups.update(latin.groups)
    arabic.kerning.update(latin.kerning)

    for attr in ("xHeight", "capHeight"):
        value = getattr(latin.info, attr)
        if value is not None:
            setattr(arabic.info, attr, getattr(latin.info, attr))

    # Merge Arabic and Latin features, making sure languagesystem statements
    # come first.
    langsys = []
    statements = []
    for font in (arabic, latin):
        featurefile = UnicodeIO(tounicode(font.features.text))
        fea = parser.Parser(featurefile, []).parse()
        langsys += [s for s in fea.statements if isinstance(s, ast.LanguageSystemStatement)]
        statements += [s for s in fea.statements if not isinstance(s, ast.LanguageSystemStatement)]
    # Drop GDEF table, we want to generate one based on final features.
    statements = [s for s in statements if not isinstance(s, ast.TableBlock)]
    # Make sure DFLT is the first.
    langsys = sorted(langsys, key=attrgetter("script"))
    fea.statements = langsys + statements
    arabic.features.text = fea.asFea()

    for ch in [(ord(u'؟'), "question")]:
        arGlyph = arabic.newGlyph("uni%04X" %ch[0])
        arGlyph.unicode = ch[0]
        enGlyph = arabic[ch[1]]
        component = Component()
        component.transformation = tuple(Transform().scale(-1, 1))
        component.baseGlyph = enGlyph.name
        arGlyph.appendComponent(component)
        arGlyph.leftMargin = enGlyph.rightMargin
        arGlyph.rightMargin = enGlyph.leftMargin

    glyphOrder = arabic.glyphOrder + latin.glyphOrder

    # Make sure we have a fixed glyph order by using the original Arabic and
    # Latin glyph order, not whatever we end up with after adding glyphs.
    arabic.glyphOrder = sorted(arabic.glyphOrder, key=glyphOrder.index)

    # Set metadata
    arabic.info.versionMajor, arabic.info.versionMinor = map(int, args.version.split("."))

    copyright = u"Copyright © 2015-%s The Reem Kufi Project Authors." % datetime.now().year

    arabic.info.copyright = copyright

    arabic.info.openTypeNameDesigner = u"Khaled Hosny"
    arabic.info.openTypeNameLicenseURL = u"http://scripts.sil.org/OFL"
    arabic.info.openTypeNameLicense = u"This Font Software is licensed under the SIL Open Font License, Version 1.1. This license is available with a FAQ at: http://scripts.sil.org/OFL"
    arabic.info.openTypeNameDescription = u"Reem Kufi is a Fatimid-style decorative Kufic typeface as seen in the historical mosques of Cairo. Reem Kufi is based on the Kufic designs of the great Arabic calligrapher Mohammed Abdul Qadir who revived this art in the 20th century and formalised its rules."
    arabic.info.openTypeNameSampleText = u"ريم على القاع بين البان و العلم   أحل سفك دمي في الأشهر الحرم"

    return arabic

def main():
    parser = argparse.ArgumentParser(description="Build Reem Kufi fonts.")
    parser.add_argument("arabicfile", metavar="FILE", help="input font to process")
    parser.add_argument("latinfile", metavar="FILE", help="input font to process")
    parser.add_argument("--out-file", metavar="FILE", help="output font to write", required=True)
    parser.add_argument("--version", metavar="version", help="version number", required=True)

    args = parser.parse_args()

    ufo = merge(args)
    ufo.save(args.out_file)

if __name__ == "__main__":
    main()
