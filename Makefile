NAME=ReemKufi
LATIN=JosefinSans
COLRv0=Fun
COLRv1=Ink

SOURCEDIR=sources
SCRIPTDIR=scripts
FONTDIR=fonts
BUILDDIR=build
DIST=${NAME}-${VERSION}

PY ?= python3

FONTS = \
	${NAME} \
	${NAME}${COLRv0} \
	${NAME}${COLRv1}-Regular # ${NAME}${COLRv1}-Bold

TTF=$(FONTS:%=${FONTDIR}/%.ttf)
DTTF=$(TTF:%=${BUILDDIR}/dist/%)
SAMPLE=Sample.svg

TAG=$(shell git describe --tags --abbrev=0)
VERSION=$(TAG:v%=%)

export SOURCE_DATE_EPOCH ?= $(shell stat -c "%Y" $(SOURCEDIR)/${NAME}.glyphs)

define generate_fonts
mkdir -p $(dir $(3));
fontmake --mm-designspace $(2)                                                 \
         --output $(1)                                                         \
         --output-path $(3)                                                    \
         $(if $(4),--interpolate '.* $(4)',)                                   \
         --verbose WARNING                                                     \
         --overlaps-backend pathops                                            \
         --optimize-cff 1                                                      \
         --flatten-components                                                  \
         ;
endef

all: ttf doc

ttf: ${TTF}
doc: ${SAMPLE}

SHELL=/usr/bin/env bash
MAKEFLAGS := -s -r

.SECONDARY:

SVGS_ = $(notdir $(wildcard $(SOURCEDIR)/svg/Regular/*.svg))
SVGS = $(SVGS_:%=\%/%)

COLRDIR = ${BUILDDIR}/colr


${COLRDIR}/%.svg: ${SOURCEDIR}/svg/%.svg
	echo "   PICO	$(@F)"
	mkdir -p $(@D)
	picosvg --output_file $@ $<

${COLRDIR}/%/colr.toml: colr.toml
	mkdir -p $(@D)
	cp $< $@

%/colr.fea:
	mkdir -p $(@D)
	touch $@

%/glyphmap.csv: ${SOURCEDIR}/${NAME}.glyphs
	mkdir -p $(@D)
	${PY} ${SCRIPTDIR}/mkglyphmap.py $< $(@D)

%/colr.ttf: %/colr.toml %/glyphmap.csv %/colr.fea ${SVGS}
	echo "   MAKE	$(@F)"
	${PY} -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --color_format glyf_colr_1 \
		      --fea_file $*/colr.fea \
		      --output_file $@

%/colr.ufo: %/colr.toml %/glyphmap.csv %/colr.fea ${SVGS}
	echo "   MAKE	$(@F)"
	${PY} -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --fea_file $*/colr.fea \
		      --output_file $@

${FONTDIR}/${NAME}${COLRv1}-%.ttf: ${BUILDDIR}/${NAME}.designspace ${COLRDIR}/%/colr.ttf
	echo "   MAKE	$(@F)"
	$(call generate_fonts,ttf,$<,$@,$(*F))
	${PY} ${SCRIPTDIR}/mknocolr.py $@ $@
	${PY} ${SCRIPTDIR}/mkcolrv1.py $@ ${COLRDIR}/$*/colr.ttf $@

${FONTDIR}/${NAME}${COLRv0}.ttf: ${BUILDDIR}/${NAME}.ttf
	echo "   MAKE	$(@F)"
	mkdir -p $(@D)
	${PY} ${SCRIPTDIR}/mkcolrv0.py $< $@ ${COLRv0}

${BUILDDIR}/${NAME}.ttf: ${BUILDDIR}/${NAME}.designspace
	echo "   MAKE	$(@F)"
	$(call generate_fonts,variable,$<,$@)

${FONTDIR}/${NAME}.ttf: ${BUILDDIR}/${NAME}.ttf
	mkdir -p $(@D)
	${PY} ${SCRIPTDIR}/mknocolr.py $< $@

${BUILDDIR}/${NAME}.glyphs: ${SOURCEDIR}/${NAME}.glyphs ${SOURCEDIR}/${LATIN}.glyphs
	echo "   GEN	$(@F)"
	mkdir -p ${BUILDDIR}
	${PY} ${SCRIPTDIR}/prepare.py --out-file=$@ $< $(word 2,$+)

${BUILDDIR}/${NAME}.designspace: ${BUILDDIR}/${NAME}.glyphs
	echo "   GEN	$(@F)"
	glyphs2ufo -m ${BUILDDIR} \
		    --minimal \
		    --generate-GDEF \
		    --write-public-skip-export-glyphs \
		    --no-preserve-glyphsapp-metadata \
		    --no-store-editor-state \
		    $<

${BUILDDIR}/dist/${FONTDIR}/%: ${FONTDIR}/%
	mkdir -p $(@D)
	${PY} ${SCRIPTDIR}/dist.py $< $@ ${VERSION}

${BUILDDIR}/dist/${FONTDIR}/%: ${FONTDIR}/%
	mkdir -p $(@D)
	${PY} ${SCRIPTDIR}/dist.py $< $@ ${VERSION}

${SAMPLE}: ${FONTDIR}/${NAME}.ttf
	echo "   SAMPLE    $(@F)"
	${PY} ${SCRIPTDIR}/mksample.py $< \
	  --output=$@ \
	  --text="ريم على القــاع بين البــان و العـلم   أحل سفك دمي في الأشهر الحرم" \
          --features="+cv01,-cv01[6],-cv01[32:36],+cv02[40],-cv01[45]"

dist: ${DTTF}
	echo "   DIST   ${DIST}"
	install -Dm644 -t ${DIST} ${DTTF}
	install -Dm644 -t ${DIST} OFL.txt
	install -Dm644 -t ${DIST} README.md
	echo "   ZIP    ${DIST}"
	zip -q -r ${DIST}.zip ${DIST}

clean:
	rm -rf ${TTF} ${SAMPLE} ${BUILDDIR} ${NAME}-${VERSION} ${NAME}-${VERSION}.zip
