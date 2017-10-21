import argparse

from designSpaceDocument import DesignSpaceDocument
from glyphsLib import build_masters
from mutatorMath.ufo import build
from tempfile import TemporaryDirectory

def main():
    parser = argparse.ArgumentParser(description="Build Reem Kufi fonts.")
    parser.add_argument("file", metavar="FILE", help="input font to process")
    parser.add_argument("--out-file", metavar="FILE", help="output font to write", required=True)

    args = parser.parse_args()

    with TemporaryDirectory() as tempdir:
        ufos, designspace, _ = build_masters(args.file, tempdir, tempdir)
        
        doc = DesignSpaceDocument()
        doc.read(designspace)
        doc.instances = [i for i in doc.instances if i.styleName == "Regular"]
        assert len(doc.instances) == 1
        instance = doc.instances[0]
        instance.location = dict(weight=108)
        instance.path = args.out_file
        doc.write(designspace)

        build(designspace, outputUFOFormatVersion=3)

if __name__ == "__main__":
    main()
