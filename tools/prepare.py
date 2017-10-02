#!/usr/bin/env python
# encoding: utf-8

import argparse

from datetime import datetime
from defcon import Font, Component
from fontTools.misc.transform import Transform

from placeholders import build as addPlaceHolders

MADA_UNICODES = "org.mada.subsetUnicodes"

def parseSubset(filename):
    unicodes = []
    with open(filename) as f:
        lines = f.read()
        lines = lines.split()
        unicodes = [int(c.lstrip('U+'), 16) for c in lines if c]
    return unicodes

def merge(args):
    arabic = Font(args.arabicfile)

    latin = Font(args.latinfile)

    addPlaceHolders(arabic)

    unicodes = parseSubset(args.latin_subset)
    for glyph in arabic:
        unicodes.extend(glyph.unicodes)

    latin_locl = ""
    for name in latin.glyphOrder:
        glyph = latin[name]
        if name in arabic:
            glyph.unicode = None
            glyph.name = name + ".latn"
            latin_locl += "sub %s by %s;" % (name, glyph.name)
        arabic.insertGlyph(glyph)

    for attr in ("xHeight", "capHeight"):
        value = getattr(latin.info, attr)
        if value is not None:
            setattr(arabic.info, attr, getattr(latin.info, attr))

    arabic.features.text += latin.features.text

    if latin_locl:
        arabic.features.text += """
feature locl {
  lookupflag IgnoreMarks;
  script latn;
  %s
} locl;
""" % latin_locl

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
        unicodes.append(arGlyph.unicode)

    arabic.lib[MADA_UNICODES] = unicodes

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
    parser.add_argument("--latin-subset", metavar="FILE", help="file containing Latin code points to keep", required=True)
    parser.add_argument("--version", metavar="version", help="version number", required=True)

    args = parser.parse_args()

    ufo = merge(args)
    ufo.save(args.out_file)

if __name__ == "__main__":
    main()
