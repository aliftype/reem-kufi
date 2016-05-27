import sys
import os

from defcon import Font, Component
from feaTools.parser import parseFeatures, FeaToolsParserSyntaxError
from feaTools.writers.baseWriter import AbstractFeatureWriter

class FeatureWriter(AbstractFeatureWriter):
    def __init__(self):
        super(FeatureWriter).__init__()
        self.subs = {}
        self.name = ""

    def feature(self, name):
        self.name = name
        return self

    def lookup(self, name):
        self.name = ""
        return self

    def gsubType1(self, target, replacement):
        if self.name == "isol":
            self.subs[target] = [replacement]

    def gsubType2(self, target, replacement):
        if self.name == "isol":
            self.subs[target] = replacement

def build(font):
    path = os.path.splitext(font.path)
    path = path[0].split("-")
    path = path[0] + ".fea"
    with open(path) as f:
        fea = f.read()
    writer = FeatureWriter()
    try:
        parseFeatures(writer, fea)
    except FeaToolsParserSyntaxError:
        pass
    subs = writer.subs

    for name, names in subs.items():
        base = names[0]
        if base in font.layers["Marks"]:
            base = font.layers["Marks"][base]
        else:
            base = font[base]
        glyph = font.newGlyph(name)
        glyph.unicode = int(name.lstrip('uni'), 16)
        glyph.width = base.width
        glyph.leftMargin = base.leftMargin
        glyph.rightMargin = base.rightMargin
        component = Component()
        component.baseGlyph = names[0]
        glyph.appendComponent(component)
        for baseComponent in base.components:
            if baseComponent.baseGlyph in names[1:]:
                component = Component()
                component.transformation = baseComponent.transformation
                component.baseGlyph = baseComponent.baseGlyph
                glyph.appendComponent(component)
