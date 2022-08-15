import argparse

from fontTools.ttLib import TTFont


def rename(args):
    font = TTFont(args.input)
    name = font["name"]
    for rec in name.names:
        if rec.nameID in (1, 4):
            rec.string = str(rec) + " " + args.suffix
        elif rec.nameID in (3, 6):
            rec.string = str(rec) + args.suffix
        elif rec.nameID == 0:
            rec.string = str(rec).replace("Kufi", f"Kufi {args.suffix}")
        elif "-" in str(rec):
            string = str(rec).split("-")
            rec.string = "-".join([string[0] + args.suffix] + string[1:])

    return font


def main():
    parser = argparse.ArgumentParser(description="Rename Reem Kufi color fonts.")
    parser.add_argument("input", metavar="FILE", help="input font to process")
    parser.add_argument("output", metavar="FILE", help="output font to write")
    parser.add_argument("suffix", metavar="STR", help="suffix to add to family name")

    args = parser.parse_args()

    font = rename(args)
    font.save(args.output)


if __name__ == "__main__":
    main()
