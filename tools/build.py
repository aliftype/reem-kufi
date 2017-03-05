#!/usr/bin/env python
# encoding: utf-8

import argparse
import math

from booleanOperations import BooleanOperationManager
from datetime import datetime
from defcon import Font, Component
from fontTools import subset
from fontTools.misc.transform import Transform
from fontTools.ttLib import TTFont
from ufo2ft import compileOTF, compileTTF

from buildencoded import build as buildEncoded

MADA_UNICODES = "org.mada.subsetUnicodes"
FONTFORGE_GLYPHCLASS = "org.fontforge.glyphclass"

def findClones(font, name):
    clones = []
    for glyph in font:
        if glyph.markColor and tuple(glyph.markColor) == (1, 0, 1, 1):
            assert len(glyph.components) > 0, glyph
            base = font.layers["Marks"][glyph.components[0].baseGlyph]
            marks = font.layers["Marks"].newGlyph(glyph.name)
            for baseComponent in base.components:
                component = Component()
                component.transformation = baseComponent.transformation
                component.baseGlyph = baseComponent.baseGlyph
                marks.appendComponent(component)
            if base.name == name:
                clones.append(glyph.name)
    return clones

def isMark(glyph):
    glyphClass = glyph.lib.get(FONTFORGE_GLYPHCLASS)
    return glyphClass == "mark"

def generateAnchor(font, glyph, marks):
    fea = ""
    layer = font.layers["Marks"]
    if glyph.name not in layer or not layer[glyph.name].components:
        return fea

    bases = [glyph.name]
    for clone in findClones(font, glyph.name):
        bases.append(clone)
        bases.extend(findClones(font, clone))
    bases = " ".join(bases)
    kind = "base"
    if isMark(glyph):
        kind = "mark"
    fea += "position %s [%s]" % (kind, bases)
    for component in layer[glyph.name].components:
        name = component.baseGlyph
        x = component.transformation[-2]
        y = component.transformation[-1]
        assert name in marks, name
        fea += " <anchor %d %d> mark @%s" % (x, y, name.upper())
    fea += ";"

    return fea

def generateAnchors(font):
    marks = [g.name for g in font if isMark(g)]

    fea = ""
    for mark in marks:
        fea += "markClass [%s] <anchor 0 0> @%s;" % (mark, mark.upper())

    fea += "feature mark {"
    for glyph in font:
        if not isMark(glyph):
            fea += generateAnchor(font, glyph, marks)
    fea += "} mark;"

    fea += "feature mkmk {"
    for glyph in font:
        if isMark(glyph):
            fea += generateAnchor(font, glyph, marks)
    fea += "} mkmk;"

    return fea

def generateGlyphclasses(font):
    marks = []
    bases = []
    for glyph in font:
        glyphClass = glyph.lib.get(FONTFORGE_GLYPHCLASS)
        if glyphClass == "mark":
            marks.append(glyph.name)
        elif glyphClass == "baseglyph":
            bases.append(glyph.name)

    fea = ""
    fea += "table GDEF {"
    fea += "GlyphClassDef "
    fea += "[%s]," % " ".join(bases)
    fea += ","
    fea += "[%s]," % " ".join(marks)
    fea += ";"
    fea += "} GDEF;"

    return fea

def generateArabicFeatures(font):
    fea = font.features.text
    fea += generateAnchors(font)
    fea += generateGlyphclasses(font)

    return fea

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

    buildEncoded(arabic)

    unicodes = parseSubset(args.latin_subset)
    for glyph in arabic:
        unicodes.extend(glyph.unicodes)

    latin_locl = ""
    for glyph in latin:
        if glyph.name in arabic:
            name = glyph.name
            glyph.unicode = None
            glyph.name = name + ".latn"
            latin_locl += "sub %s by %s;" % (name, glyph.name)
        arabic.insertGlyph(glyph)

    for attr in ("xHeight", "capHeight"):
        value = getattr(latin.info, attr)
        if value is not None:
            setattr(arabic.info, attr, getattr(latin.info, attr))
    fea = generateArabicFeatures(arabic)
    fea += latin.features.text

    if latin_locl:
        fea += """
feature locl {
  lookupflag IgnoreMarks;
  script latn;
  %s
} locl;
""" % latin_locl

    arabic.features.text = fea

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

    copyright = 'Copyright © 2015-%s The Reem Kufi Project Authors.' % datetime.now().year

    arabic.info.copyright = copyright

    arabic.info.openTypeNameDesigner = "Khaled Hosny"
    arabic.info.openTypeNameLicenseURL = "http://scripts.sil.org/OFL"
    arabic.info.openTypeNameLicense = "This Font Software is licensed under the SIL Open Font License, Version 1.1. This license is available with a FAQ at: http://scripts.sil.org/OFL"
    arabic.info.openTypeNameDescription = "Reem Kufi is a Fatimid-style decorative Kufic typeface as seen in the historical mosques of Cairo. Reem Kufi is based on the Kufic designs of the great Arabic calligrapher Mohammed Abdul Qadir who revived this art in the 20th century and formalised its rules."
    arabic.info.openTypeNameSampleText = "ريم على القاع بين البان و العلم   أحل سفك دمي في الأشهر الحرم"

    return arabic

def subsetGlyphs(otf, ufo):
    options = subset.Options()
    options.set(layout_features='*', name_IDs='*', notdef_outline=True)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=ufo.lib.get(MADA_UNICODES))
    subsetter.subset(otf)
    return otf

def decomposeGlyphs(ufo, isTTF):
    for glyph in ufo:
        if not glyph.components or (isTTF and not bool(glyph)):
            continue
        glyph.decomposeAllComponents()

    return ufo

def removeOverlap(ufo):
    manager = BooleanOperationManager()
    for glyph in ufo:
        contours = list(glyph)
        glyph.clearContours()
        manager.union(contours, glyph.getPointPen())
    return ufo

def build(args):
    isTTF = args.out_file.endswith(".ttf")
    ufo = merge(args)
    ufo = decomposeGlyphs(ufo, isTTF)
    ufo = removeOverlap(ufo)

    otf = compileTTF(ufo) if isTTF else compileOTF(ufo)
    otf = subsetGlyphs(otf, ufo)

    return otf

def main():
    parser = argparse.ArgumentParser(description="Build Reem Kufi fonts.")
    parser.add_argument("arabicfile", metavar="FILE", help="input font to process")
    parser.add_argument("latinfile", metavar="FILE", help="input font to process")
    parser.add_argument("--out-file", metavar="FILE", help="output font to write", required=True)
    parser.add_argument("--latin-subset", metavar="FILE", help="file containing Latin code points to keep", required=True)
    parser.add_argument("--version", metavar="version", help="version number", required=True)

    args = parser.parse_args()

    otf = build(args)
    otf.save(args.out_file)

if __name__ == "__main__":
    main()
