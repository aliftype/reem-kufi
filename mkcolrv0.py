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
        elif "-" in str(rec):
            string = str(rec).split("-")
            rec.string = "-".join([string[0] + args.suffix] + string[1:])

    mapping = {}
    gsub = font["GSUB"].table
    for rec in gsub.FeatureList.FeatureRecord:
        if rec.FeatureTag == args.feature:
            for idx in rec.Feature.LookupListIndex:
                lookup = gsub.LookupList.Lookup[idx]
                for subtable in lookup.SubTable:
                    if not hasattr(subtable, "mapping"):
                        continue
                    m = dict(zip(subtable.mapping.values(), subtable.mapping.keys()))
                    mapping.update(m)

    colr = font["COLR"]
    for layer in dict(colr.ColorLayers):
        if layer in mapping:
            colr.ColorLayers[mapping[layer]] = colr.ColorLayers[layer]

    return font


def main():
    parser = argparse.ArgumentParser(description="Rename Reem Kufi color fonts.")
    parser.add_argument("input", metavar="FILE", help="input font to process")
    parser.add_argument("output", metavar="FILE", help="output font to write")
    parser.add_argument("suffix", metavar="STR", help="suffix to add to family name")
    parser.add_argument("feature", metavar="TAG", help="color feature tag")

    args = parser.parse_args()

    font = rename(args)
    font.save(args.output)


if __name__ == "__main__":
    main()
