import argparse

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import otTables as ot


def axis_value(instance, name):
    v = ot.AxisValue()
    v.AxisIndex = 0
    v.Format = 1
    v.Flags = 0
    if name == "Regular":
        v.Format = 3
        v.LinkedValue = 700.0
        v.Flags = 2
    v.ValueNameID = instance.subfamilyNameID
    v.Value = list(instance.coordinates.values())[0]
    return v


def main():
    parser = argparse.ArgumentParser(description="Update STAT table.")
    parser.add_argument("input", metavar="FILE", help="input font to process")
    parser.add_argument("output", metavar="FILE", help="output font to save")

    args = parser.parse_args()

    font = TTFont(args.input)
    STAT = font["STAT"]
    fvar = font["fvar"]
    name = font["name"]
    if not STAT.table.AxisValueArray:
        STAT.table.AxisValueArray = ot.AxisValueArray()
        STAT.table.AxisValueArray.AxisValue = [
            axis_value(i, name.getDebugName(i.subfamilyNameID)) for i in fvar.instances
        ]
    name.names = [n for n in name.names if n.platformID == 3]
    for n in name.names:
        if n.nameID == 6:
            psname = str(n).split("-")[0]
            n.string = psname
        elif n.nameID == 3:
            n.string = str(n).split("-")[0]
        elif n.nameID == 4:
            n.string = str(n).replace(" Regular", "")
    for instance in fvar.instances:
        if instance.postscriptNameID == 0xFFFF:
            n = name.getDebugName(instance.subfamilyNameID)
            instance.postscriptNameID = name.addMultilingualName(
                {"en": f"{psname}-{n}"}, mac=False
            )

    font.save(args.output)


if __name__ == "__main__":
    main()
