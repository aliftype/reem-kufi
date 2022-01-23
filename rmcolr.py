import argparse

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
    del font["COLR"]
    del font["CPAL"]
    font.save(args.output)


if __name__ == "__main__":
    main()
