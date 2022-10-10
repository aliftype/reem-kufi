import argparse

from fontTools import subset
from fontTools.ttLib import TTFont


def main():
    parser = argparse.ArgumentParser(description="Create Reem Kufi fonts.")
    parser.add_argument("input", metavar="FILE", help="input font to process")
    parser.add_argument("output", metavar="FILE", help="output font to write")

    args = parser.parse_args()

    font = TTFont(args.input)

    unicodes = font.getBestCmap().keys()
    options = subset.Options()
    options.set(
        layout_features="*",
        layout_scripts="*",
        name_IDs="*",
        name_languages="*",
        drop_tables=["COLR", "CPAL"],
        notdef_outline=True,
        recalc_average_width=True,
        glyph_names=True,
    )
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)

    font.save(args.output)


if __name__ == "__main__":
    main()
