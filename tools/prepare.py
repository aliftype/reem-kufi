import argparse

from datetime import datetime
from io import StringIO
from operator import attrgetter

from ufoLib2 import Font
from fontTools.feaLib import ast, parser


def merge(args):
    arabic = Font(args.arabicfile)
    latin = Font(args.latinfile)

    unicodes = set()
    for glyph in arabic:
        unicodes.update(glyph.unicodes)

    for name in latin.glyphOrder:
        if name in ("space", "nbspace", "CR", "NULL", ".notdef"):
            continue
        glyph = latin[name]
        assert glyph.name not in arabic, glyph.name
        assert not (
            glyph.unicodes and set(glyph.unicodes).issubset(unicodes)
        ), glyph.unicodes
        # Strip anchors from f_ ligatures, there are broken.
        # See https://github.com/googlei18n/glyphsLib/issues/313
        if name.startswith("f_"):
            glyph.anchors = {}
        arabic.addGlyph(glyph)

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
        featurefile = StringIO(font.features.text)
        fea = parser.Parser(featurefile, font.glyphOrder).parse()
        for statement in fea.statements:
            if isinstance(statement, ast.LanguageSystemStatement):
                langsys.append(statement)
            elif not isinstance(statement, ast.TableBlock):
                statements.append(statement)
    # Make sure DFLT is the first.
    langsys = sorted(langsys, key=attrgetter("script"))
    fea.statements = langsys + statements
    arabic.features.text = fea.asFea()

    glyphOrder = arabic.glyphOrder + latin.glyphOrder

    # Make sure we have a fixed glyph order by using the original Arabic and
    # Latin glyph order, not whatever we end up with after adding glyphs.
    arabic.glyphOrder = sorted(glyphOrder, key=glyphOrder.index)

    # Set metadata
    arabic.info.versionMajor, arabic.info.versionMinor = map(
        int, args.version.split(".")
    )
    arabic.info.copyright = (
        u"Copyright © 2015-%s The Reem Kufi Project Authors." % datetime.now().year
    )

    # Merge production names
    arabic.lib["public.postscriptNames"].update(latin.lib["public.postscriptNames"])

    return arabic


def main():
    parser = argparse.ArgumentParser(description="Build Reem Kufi fonts.")
    parser.add_argument("arabicfile", metavar="FILE", help="input font to process")
    parser.add_argument("latinfile", metavar="FILE", help="input font to process")
    parser.add_argument(
        "--out-file", metavar="FILE", help="output font to write", required=True
    )
    parser.add_argument(
        "--version", metavar="version", help="version number", required=True
    )

    args = parser.parse_args()

    ufo = merge(args)
    ufo.save(args.out_file, overwrite=True)


if __name__ == "__main__":
    main()
