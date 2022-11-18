NAME=ReemKufi
LATIN=JosefinSans
COLRv0=Fun
COLRv1=Ink

SOURCEDIR=sources
SCRIPTDIR=scripts
FONTDIR=fonts
BUILDDIR=build
DIST=${NAME}-${VERSION}

FONTS = \
	${NAME} \
	${NAME}${COLRv0} \
	${NAME}${COLRv1}-Regular # ${NAME}${COLRv1}-Bold

OTF=$(FONTS:%=${FONTDIR}/%.otf)
TTF=$(FONTS:%=${FONTDIR}/%.ttf)
DOTF=$(OTF:%=${BUILDDIR}/dist/%)
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

all: otf doc

otf: ${OTF}
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
	python3 ${SCRIPTDIR}/mkglyphmap.py $< $(@D)

%/colr.otf: %/colr.toml %/glyphmap.csv %/colr.fea ${SVGS}
	echo "   MAKE	$(@F)"
	python3 -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --color_format cff_colr_1 \
		      --fea_file $*/colr.fea \
		      --output_file $@

%/colr.ttf: %/colr.toml %/glyphmap.csv %/colr.fea ${SVGS}
	echo "   MAKE	$(@F)"
	python3 -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --color_format glyf_colr_1 \
		      --fea_file $*/colr.fea \
		      --output_file $@

%/colr.ufo: %/colr.toml %/glyphmap.csv %/colr.fea ${SVGS}
	echo "   MAKE	$(@F)"
	python3 -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --fea_file $*/colr.fea \
		      --output_file $@

${FONTDIR}/${NAME}${COLRv1}-%.otf: ${BUILDDIR}/${NAME}.designspace ${COLRDIR}/%/colr.otf
	echo "   MAKE	$(@F)"
	$(call generate_fonts,otf,$<,$@,$(*F))
	python3 ${SCRIPTDIR}/mknocolr.py $@ $@
	python3 ${SCRIPTDIR}/mkcolrv1.py $@ ${COLRDIR}/$*/colr.otf $@

${FONTDIR}/${NAME}${COLRv1}-%.ttf: ${BUILDDIR}/${NAME}.designspace ${COLRDIR}/%/colr.ttf
	echo "   MAKE	$(@F)"
	$(call generate_fonts,ttf,$<,$@,$(*F))
	python3 ${SCRIPTDIR}/mknocolr.py $@ $@
	python3 ${SCRIPTDIR}/mkcolrv1.py $@ ${COLRDIR}/$*/colr.ttf $@

${FONTDIR}/${NAME}${COLRv0}.%: ${BUILDDIR}/${NAME}.%
	echo "   MAKE	$(@F)"
	mkdir -p $(@D)
	python3 ${SCRIPTDIR}/mkcolrv0.py $< $@ ${COLRv0}

${BUILDDIR}/${NAME}.otf: ${BUILDDIR}/${NAME}.designspace
	echo "   MAKE	$(@F)"
	$(call generate_fonts,variable-cff2,$<,$@)

${BUILDDIR}/${NAME}.ttf: ${BUILDDIR}/${NAME}.designspace
	echo "   MAKE	$(@F)"
	$(call generate_fonts,variable,$<,$@)

${FONTDIR}/${NAME}.otf: ${BUILDDIR}/${NAME}.otf
	mkdir -p $(@D)
	python3 ${SCRIPTDIR}/mknocolr.py $< $@

${FONTDIR}/${NAME}.ttf: ${BUILDDIR}/${NAME}.ttf
	mkdir -p $(@D)
	python3 ${SCRIPTDIR}/mknocolr.py $< $@

${BUILDDIR}/${NAME}.glyphs: ${SOURCEDIR}/${NAME}.glyphs ${SOURCEDIR}/${LATIN}.glyphs
	echo "   GEN	$(@F)"
	mkdir -p ${BUILDDIR}
	python3 ${SCRIPTDIR}/prepare.py --out-file=$@ $< $(word 2,$+)

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
	python3 ${SCRIPTDIR}/dist.py $< $@ ${VERSION}

${BUILDDIR}/dist/${FONTDIR}/%: ${FONTDIR}/%
	mkdir -p $(@D)
	python3 ${SCRIPTDIR}/dist.py $< $@ ${VERSION}

${SAMPLE}: ${FONTDIR}/${NAME}.otf
	echo "   SAMPLE    $(@F)"
	python3 ${SCRIPTDIR}/mksample.py $< \
	  --output=$@ \
	  --text="ريم على القــاع بين البــان و العـلم   أحل سفك دمي في الأشهر الحرم" \
          --features="+cv01,-cv01[6],-cv01[32:36],+cv02[40],-cv01[45]"

dist: ${DOTF} ${DTTF}
	echo "   DIST   ${DIST}"
	install -Dm644 -t ${DIST} ${DOTF}
	install -Dm644 -t ${DIST}/ttf ${DTTF}
	install -Dm644 -t ${DIST} OFL.txt
	install -Dm644 -t ${DIST} README.md
	echo "   ZIP    ${DIST}"
	zip -q -r ${DIST}.zip ${DIST}

clean:
	rm -rf ${OTF} ${TTF} ${SAMPLE} ${BUILDDIR} ${NAME}-${VERSION} ${NAME}-${VERSION}.zip
