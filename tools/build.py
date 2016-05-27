#!/usr/bin/env python
# encoding: utf-8

import argparse
import math

from cu2qu.ufo import font_to_quadratic
from datetime import datetime
from defcon import Font, Component
from fontTools import subset
from fontTools.feaLib import builder as feabuilder
from fontTools.misc.transform import Transform
from fontTools.ttLib import TTFont
from tempfile import NamedTemporaryFile
from ufo2ft.outlineOTF import OutlineOTFCompiler as OTFCompiler
from ufo2ft.outlineOTF import OutlineTTFCompiler as TTFCompiler
from ufo2ft.otfPostProcessor import OTFPostProcessor

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

def generateArabicFeatures(font, feafilename):
    fea = ""
    with open(feafilename) as feafile:
        fea += feafile.read()
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
            if not latin_locl:
                latin_locl = "feature locl {lookupflag IgnoreMarks; script latn;"
            latin_locl += "sub %s by %s;" % (name, glyph.name)
        arabic.insertGlyph(glyph)

    for attr in ("xHeight", "capHeight"):
        value = getattr(latin.info, attr)
        if value is not None:
            setattr(arabic.info, attr, getattr(latin.info, attr))
    fea = "include(../%s)\n" % (args.latinfile + "/features.fea")
    fea += generateArabicFeatures(arabic, args.feature_file)
    if latin_locl:
        latin_locl += "} locl;"
        fea += latin_locl

    arabic.lib[MADA_UNICODES] = unicodes

    # Set metadata
    arabic.versionMajor, arabic.versionMinor = map(int, args.version.split("."))

    copyright = 'Copyright © 2015-%s The Reem Kufi Project Authors.' % datetime.now().year

    arabic.info.copyright = copyright

    arabic.info.openTypeNameDesigner = "Khaled Hosny"
    arabic.info.openTypeNameLicenseURL = "http://scripts.sil.org/OFL"
    arabic.info.openTypeNameLicense = "This Font Software is licensed under the SIL Open Font License, Version 1.1. This license is available with a FAQ at: http://scripts.sil.org/OFL"
    arabic.info.openTypeNameDescription = "Reem Kufi is a Fatimid-style decorative Kufic typeface as seen in the historical mosques of Cairo. Reem Kufi is based on the Kufic designs of the great Arabic calligrapher Mohammed Abdul Qadir who revived this art in the 20th century and formalised its rules."
    arabic.info.openTypeNameSampleText = "ريم على القاع بين البان و العلم   أحل سفك دمي في الأشهر الحرم"

    return arabic, fea

def applyFeatures(otf, fea, feafilename):
    try:
        feabuilder.addOpenTypeFeaturesFromString(otf, fea, feafilename)
    except:
        with NamedTemporaryFile(delete=False) as feafile:
            feafile.write(fea.encode("utf-8"))
            print("Failed to apply features, saved to %s" % feafile.name)
        raise
    return otf

def postProcess(otf, ufo):
    postProcessor = OTFPostProcessor(otf, ufo)
    otf = postProcessor.process(optimizeCff=True)
    return otf

def subsetGlyphs(otf, ufo):
    options = subset.Options()
    options.set(layout_features='*', name_IDs='*', notdef_outline=True)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=ufo.lib.get(MADA_UNICODES))
    subsetter.subset(otf)
    return otf

def build(args):
    ufo, fea = merge(args)
    if args.out_file.endswith(".ttf"):
        font_to_quadratic(ufo)
        otfCompiler = TTFCompiler(ufo)
    else:
        otfCompiler = OTFCompiler(ufo)
    otf = otfCompiler.compile()

    otf = applyFeatures(otf, fea, args.feature_file)
    otf = postProcess(otf, ufo)
    otf = subsetGlyphs(otf, ufo)

    return otf

def main():
    parser = argparse.ArgumentParser(description="Build Reem Kufi fonts.")
    parser.add_argument("arabicfile", metavar="FILE", help="input font to process")
    parser.add_argument("latinfile", metavar="FILE", help="input font to process")
    parser.add_argument("--out-file", metavar="FILE", help="output font to write", required=True)
    parser.add_argument("--feature-file", metavar="FILE", help="output font to write", required=True)
    parser.add_argument("--latin-subset", metavar="FILE", help="file containing Latin code points to keep", required=True)
    parser.add_argument("--version", metavar="version", help="version number", required=True)

    args = parser.parse_args()

    otf = build(args)
    otf.save(args.out_file)

if __name__ == "__main__":
    main()
