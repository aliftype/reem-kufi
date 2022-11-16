NAME=ReemKufi
COLR=Fun
COLRv1=Ink
LATIN=JosefinSans

SOURCEDIR=sources
SCRIPTDIR=scripts
FONTDIR=fonts
STATICDIR=${FONTDIR}/static
VARIABLEDIR=${FONTDIR}/variable
BUILDDIR=build
DIST=${NAME}-${VERSION}

STATIC = \
	${NAME}-Regular \
	${NAME}-Medium \
	${NAME}-SemiBold \
	${NAME}-Bold \
	${NAME}${COLRv1}-Regular # ${NAME}${COLRv1}-Bold

VARIABLE = \
	${NAME} \
	${NAME}${COLR}

OTF=$(STATIC:%=${STATICDIR}/%.otf) $(VARIABLE:%=${VARIABLEDIR}/%.otf)
TTF=$(STATIC:%=${STATICDIR}/%.ttf) $(VARIABLE:%=${VARIABLEDIR}/%.ttf)
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

${STATICDIR}/${NAME}${COLRv1}-%.otf: ${STATICDIR}/${NAME}-%.otf ${COLRDIR}/%/colr.otf
	echo "   MAKE	$(@F)"
	python3 ${SCRIPTDIR}/mkcolrv1.py $< ${COLRDIR}/$*/colr.otf $@

${STATICDIR}/${NAME}${COLRv1}-%.ttf: ${STATICDIR}/${NAME}-%.ttf ${COLRDIR}/%/colr.ttf
	echo "   MAKE	$(@F)"
	python3 ${SCRIPTDIR}/mkcolrv1.py $< ${COLRDIR}/$*/colr.ttf $@

${STATICDIR}/${NAME}-%.otf: ${BUILDDIR}/${NAME}.designspace
	echo "   MAKE	$(@F)"
	$(call generate_fonts,otf,$<,$@,$(*F))
	python3 ${SCRIPTDIR}/mknocolr.py $@ $@

${BUILDDIR}/${NAME}.otf: ${BUILDDIR}/${NAME}.designspace
	echo "   MAKE	$(@F)"
	$(call generate_fonts,variable-cff2,$<,$@)

${VARIABLEDIR}/${NAME}.otf: ${BUILDDIR}/${NAME}.otf
	mkdir -p $(@D)
	python3 ${SCRIPTDIR}/mknocolr.py $< $@

${VARIABLEDIR}/${NAME}${COLR}.%: ${BUILDDIR}/${NAME}.%
	echo "   MAKE	$(@F)"
	mkdir -p $(@D)
	python3 ${SCRIPTDIR}/mkcolrv0.py $< $@ ${COLR}

${STATICDIR}/${NAME}-%.ttf: ${BUILDDIR}/${NAME}.designspace
	echo "   MAKE	$(@F)"
	$(call generate_fonts,ttf,$<,$@,$(*F))
	python3 ${SCRIPTDIR}/mknocolr.py $@ $@

${BUILDDIR}/${NAME}.ttf: ${BUILDDIR}/${NAME}.designspace
	echo "   MAKE	$(@F)"
	$(call generate_fonts,variable,$<,$@)

${VARIABLEDIR}/${NAME}.ttf: ${BUILDDIR}/${NAME}.ttf
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

${BUILDDIR}/dist/${STATICDIR}/%: ${STATICDIR}/%
	mkdir -p $(@D)
	python3 ${SCRIPTDIR}/dist.py $< $@ ${VERSION}

${BUILDDIR}/dist/${VARIABLEDIR}/%: ${VARIABLEDIR}/%
	mkdir -p $(@D)
	python3 ${SCRIPTDIR}/dist.py $< $@ ${VERSION}

${SAMPLE}: ${VARIABLEDIR}/${NAME}.otf
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
