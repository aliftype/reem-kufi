import argparse

from glyphsLib import to_designspace
from glyphsLib.classes import GSFont


def main():
    parser = argparse.ArgumentParser(description="Build Reem Kufi fonts.")
    parser.add_argument("file", metavar="FILE", help="input font to process")
    parser.add_argument(
        "--out-file", metavar="FILE", help="output font to write", required=True
    )

    args = parser.parse_args()

    font = GSFont(args.file)
    designspace = to_designspace(font)
    for source in designspace.sources:
        if source.font.info.styleName == "Regular":
            source.font.save(args.out_file, overwrite=True)


if __name__ == "__main__":
    main()
