import argparse

import svgutils.compose as sc
import svgutils.transform as sg
import xml.etree.ElementTree as ET
from io import BytesIO

HREF = "{http://www.w3.org/1999/xlink}href"
SYMBOL = "{http://www.w3.org/2000/svg}symbol"
USE = "{http://www.w3.org/2000/svg}use"
GROUP = "{http://www.w3.org/2000/svg}g"
RECT = "{http://www.w3.org/2000/svg}rect"


def fixid(value, i):
    return value.replace("glyph0", f"glyph{i}")


def main(args=None):
    parser = argparse.ArgumentParser(description="Combine SVG sample.")
    parser.add_argument("input", nargs="+", help="input SVGs")
    parser.add_argument("-o", "--output", help="output SVG", required=True)

    options = parser.parse_args(args)

    w = 0
    svgs = []
    for i, path in enumerate(options.input):
        xml = ET.parse(path)
        for elem in xml.iter(GROUP):
            elem.attrib.pop("id", None)
        for elem in xml.iter(SYMBOL):
            elem.set("id", fixid(elem.get("id"), i))
        for elem in xml.iter(USE):
            elem.set(HREF, fixid(elem.get(HREF), i))
        for elem in xml.findall(f".//{RECT}/.."):
            for rect in xml.iter(RECT):
                elem.remove(rect)

        f = BytesIO()
        xml.write(f)

        svg = sg.fromstring(f.getvalue().decode("us-ascii"))
        width = float(svg.width[:-2])
        w = max(w, width)
        svgs.append(svg)

    h = 0
    elems = []
    for svg in svgs:
        height = float(svg.height[:-2])
        width = float(svg.width[:-2])
        root = svg.getroot()
        root.moveto((w - width) / 2, h)
        h += height

        elems.append(root)

    fig = sg.SVGFigure(sc.Unit(f"{w}"), sc.Unit(f"{h}"))
    fig.append(elems)
    fig.save(options.output)


if __name__ == "__main__":
    import sys

    sys.exit(main())
