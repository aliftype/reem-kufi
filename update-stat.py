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
    parser.add_argument("output", metavar="FILE", help="output font to svae")

    args = parser.parse_args()

    font = TTFont(args.input)
    STAT = font["STAT"]
    if not STAT.table.AxisValueArray:
        fvar = font["fvar"]
        name = font["name"]
        STAT.table.AxisValueArray = ot.AxisValueArray()
        STAT.table.AxisValueArray.AxisValue = [
            axis_value(i, name.getDebugName(i.subfamilyNameID)) for i in fvar.instances
        ]

    font.save(args.output)


if __name__ == "__main__":
    main()
