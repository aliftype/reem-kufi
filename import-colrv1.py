import sys
import math

from contextlib import contextmanager

from blackrenderer.font import BlackRendererFont
from blackrenderer.backends.base import Canvas

from fontTools.misc.transform import Transform
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib.tables.otTables import ExtendMode, PaintFormat

from glyphsLib import GSFont, GSLayer

def toGlyphsColor(color):
    return [int(c * 255) for c in color]


class GCanvas(Canvas):
    def __init__(self, name, transform):
        self.name = name
        self.currentTransform = transform
        self.paths = []

    @staticmethod
    def newPath():
        return RecordingPen()

    @contextmanager
    def savedState(self):
        prevTransform = self.currentTransform
        yield
        self.currentTransform = prevTransform

    @contextmanager
    def compositeMode(self, compositeMode):
        raise NotImplementedError

    def transform(self, transform):
        self.currentTransform = self.currentTransform.transform(transform)

    def clipPath(self, path):
        raise NotImplementedError

    def _radius(self, x, y, width, height):
        center = (width * x, height * y)
        distances = []
        for pt in ((0, 0), (width, 0), (0, height), (width, height)):
            distances.append(math.dist(center, pt))
        return max(distances)

    def _pathBounds(self, path):
        pen = BoundsPen(None)
        tpen = TransformPen(pen, self.currentTransform)
        path.replay(tpen)
        return pen.bounds

    def _addPaths(self, path, attributes):
        layer = GSLayer()
        pen = TransformPen(layer.getPen(), self.currentTransform)
        path.replay(pen)
        for path in layer.paths:
            path.attributes = dict(attributes)
        self.paths.extend(layer.paths)

    def drawPathSolid(self, path, color):
        self._addPaths(path, {"fillColor": toGlyphsColor(color)})

    def drawPathLinearGradient(
        self, path, colorLine, pt1, pt2, extendMode, gradientTransform
    ):
        if extendMode != ExtendMode.PAD:
            raise NotImplementedError

        if gradientTransform:
            print(f"Unhandled LinearGradien transform in {self.name}")

        gradient = {}
        xMin, yMin, xMax, yMax = self._pathBounds(path)
        width = xMax - xMin
        height = yMax - yMin
        x0 = (pt1[0] - xMin) / width
        x1 = (pt2[0] - xMin) / width
        y0 = (pt1[1] - yMin) / height
        y1 = (pt2[1] - yMin) / height
        gradient["start"] = [x0, y0]
        gradient["end"] = [x1, y1]

        gradient["colors"] = colors = []
        for stop, color in colorLine:
            colors.append([toGlyphsColor(color), stop])

        self._addPaths(path, {"gradient": gradient})

    def drawPathRadialGradient(
        self,
        path,
        colorLine,
        startCenter,
        startRadius,
        endCenter,
        endRadius,
        extendMode,
        gradientTransform,
    ):
        if extendMode != ExtendMode.PAD:
            raise NotImplementedError

        if gradientTransform:
            print(f"Unhandled RadialGradien transform in {self.name}")

        gradient = {"type": "circle"}
        xMin, yMin, xMax, yMax = self._pathBounds(path)
        width = xMax - xMin
        height = yMax - yMin
        x0 = (startCenter[0] - xMin) / width
        x1 = (endCenter[0] - xMin) / width
        y0 = (startCenter[1] - yMin) / height
        y1 = (endCenter[1] - yMin) / height

        gradient["start"] = [x0, y0]
        gradient["end"] = [x1, y1]

        gradient["colors"] = colors = []
        for stop, color in colorLine:
            colors.append([toGlyphsColor(color), stop])

        self._addPaths(path, {"gradient": gradient})

    def drawPathSweepGradient(
        self,
        path,
        colorLine,
        center,
        startAngle,
        endAngle,
        extendMode,
        gradientTransform,
    ):
        raise NotImplementedError


font = GSFont(sys.argv[1])
otf = BlackRendererFont(sys.argv[2])
for name in otf.colrV1GlyphNames:
    glyph = font.glyphs[name]
    layer = GSLayer()
    layer.attributes["color"] = 1
    layer.associatedMasterId = font.masters[0].id
    layer.width = glyph.layers[font.masters[0].id].width
    glyph.layers.append(layer)

    canvas = GCanvas(name, Transform())
    otf.drawGlyph(name, canvas)
    layer.paths = canvas.paths

for glyph in font.glyphs:
    for layer in glyph.layers:
        if "colorPalette" in layer.attributes:
            del layer.attributes["colorPalette"]

font.save(sys.argv[3])
