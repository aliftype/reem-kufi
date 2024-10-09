import argparse

from fontTools.ttLib import TTFont


def main():
    parser = argparse.ArgumentParser(description="Post process font for distribution.")
    parser.add_argument("input", metavar="FILE", help="input font to process")
    parser.add_argument("output", metavar="FILE", help="output font to save")

    args = parser.parse_args()

    font = TTFont(args.input)

    if "fvar" in font:
        from axisregistry import build_stat

        for n in font["name"].names:
            if n.nameID == 6:
                psname = str(n).split("-")[0]
                n.string = psname
            elif n.nameID == 3:
                n.string = str(n).split("-")[0]
            elif n.nameID == 4:
                n.string = str(n).replace(" Regular", "")

        build_stat(font, [])

    # Drop glyph names from TTF fonts.
    if "glyf" in font:
        font["post"].formatType = 3

    font.save(args.output)


if __name__ == "__main__":
    main()
