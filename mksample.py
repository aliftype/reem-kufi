import argparse

from fontTools.ttLib import TTFont

import uharfbuzz as hb


def move_to(x, y, c):
    c["p"] += f"M{x},{-y}"


def line_to(x, y, c):
    c["p"] += f"L{x},{-y}"


def cubic_to(c1x, c1y, c2x, c2y, x, y, c):
    c["p"] += f"C{c1x},{-c1y} {c2x},{-c2y} {x},{-y}"


def quadratic_to(c1x, c1y, x, y, c):
    c["p"] += f"Q{c1x},{-c1y} {x},{-y}"


def close_path(c):
    c["p"] += "Z"


def buf_to_svg(buf, font, funcs, name, ttfont, x, y):
    ascender = ttfont["OS/2"].sTypoAscender
    descender = ttfont["OS/2"].sTypoDescender
    fullheight = ascender - descender

    x_cursor = x
    y_cursor = y + ascender

    svg = f'<g id="{name}">\n'
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        container = {"p": ""}
        funcs.draw_glyph(font, info.codepoint, container)
        if container["p"]:
            dx, dy = pos.position[0], pos.position[1]
            d = container["p"]
            svg += f'<path d="{d}" transform="translate({x_cursor + dx} {y_cursor - dy})"/>\n'
        x_cursor += pos.position[2]
        y_cursor -= pos.position[3]
    svg += "</g>\n"

    return svg, x_cursor, fullheight


def main(args=None):
    parser = argparse.ArgumentParser(description="Create SVG sample.")
    parser.add_argument("fonts", nargs="+", help="input fonts")
    parser.add_argument("-t", "--text", help="input text", required=True)
    parser.add_argument("-f", "--features", help="input features", required=True)
    parser.add_argument("-o", "--output", help="output SVG", required=True)

    options = parser.parse_args(args)

    funcs = hb.DrawFuncs()
    funcs.set_move_to_func(move_to)
    funcs.set_line_to_func(line_to)
    funcs.set_cubic_to_func(cubic_to)
    funcs.set_quadratic_to_func(quadratic_to)
    funcs.set_close_path_func(close_path)

    features = {}
    for feature in options.features.split(","):
        value = 1
        start = 0
        end = -1
        if feature[0] == "-":
            value = 0
        if feature[0] in ("+", "-"):
            feature = feature[1:]
        tag = feature
        if "[" in feature:
            tag, extra = feature.split("[")
            if "=" in extra:
                extra, value = extra.split("=")
            if extra[-1] == "]":
                extra = extra[:-1]
                start = end = extra
                if ":" in extra:
                    start, end = extra.split(":")
        features[tag] = [[int(value), int(start), int(end)]]

    w = 0
    y = 0
    svg = ""
    for path in options.fonts:
        blob = hb.Blob.from_file_path(path)
        face = hb.Face(blob)
        font = hb.Font(face)

        buf = hb.Buffer()
        buf.add_str(options.text)
        buf.guess_segment_properties()
        hb.shape(font, buf, features)

        ttfont = TTFont(path)
        paths, width, height = buf_to_svg(buf, font, funcs, path, ttfont, 0, y)
        y += height
        w = max(w, width)
        svg += paths

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {y}">
{svg}
</svg>"""

    with open(options.output, "w") as fp:
        fp.write(svg)


if __name__ == "__main__":
    import sys

    sys.exit(main())
