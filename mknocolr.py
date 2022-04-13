import argparse

from fontTools import subset
from fontTools.ttLib import TTFont


def rename(args):
    name = font["name"]
    for rec in name.names:
        if rec.nameID in (1, 4):
            rec.string = str(rec) + " " + args.suffix
        elif rec.nameID in (3, 6):
            rec.string = str(rec) + args.suffix
        elif "-" in str(rec):
            string = str(rec).split("-")
            rec.string = "-".join([string[0] + args.suffix] + string[1:])

    return font


def main():
    parser = argparse.ArgumentParser(description="Rename Reem Kufi color fonts.")
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
