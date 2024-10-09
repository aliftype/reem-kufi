# Copyright (c) 2020-2024 Khaled Hosny
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

NAME = ReemKufi
LATIN = JosefinSans
COLRv0 = Fun
COLRv1 = Ink

SHELL = bash
MAKEFLAGS := -srj
PYTHON := venv/bin/python3

SOURCEDIR = sources
SCRIPTDIR = scripts
FONTDIR = fonts
BUILDDIR = build

FONTS = \
	${NAME} \
	${NAME}${COLRv0} \
	${NAME}${COLRv1}-Regular # ${NAME}${COLRv1}-Bold

TTF = $(FONTS:%=${FONTDIR}/%.ttf)
DTTF = $(TTF:%=${BUILDDIR}/dist/%)
SVG = Sample.svg

GLYPHSFILE = ${SOURCEDIR}/${NAME}.glyphspackage

define SAMPLE
ريم على القــاع بين البــان و العـلم   أحل سفك دمي في الأشهر الحرم
endef

export SOURCE_DATE_EPOCH ?= $(shell stat -c "%Y" ${GLYPHSFILE})

TAG = $(shell git describe --tags --abbrev=0)
VERSION = ${TAG:v%=%}
DIST = ${NAME}-${VERSION}


define generate_fonts
mkdir -p $(dir $(3));
${PYTHON} -m fontmake                                                          \
    --mm-designspace $(2)                                                      \
    --output $(1)                                                              \
    --output-path $(3)                                                         \
    $(if $(4),--interpolate '.* $(4)',)                                        \
    --verbose WARNING                                                          \
    --overlaps-backend pathops                                                 \
    --optimize-cff 1                                                           \
    --flatten-components                                                       \
    --filter ...                                                               \
    --filter "alifTools.filters::FontVersionFilter(fontVersion=${VERSION})"    \
    ;
endef

.SECONDARY:
.ONESHELL:
.PHONY: all clean dist ttf doc

all: ttf doc
ttf: ${TTF}
doc: ${SVG}

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

%/glyphmap.csv: ${SOURCEDIR}/${NAME}.glyphspackage
	mkdir -p $(@D)
	${PYTHON} ${SCRIPTDIR}/mkglyphmap.py $< $(@D)

%/colr.ttf: %/colr.toml %/glyphmap.csv %/colr.fea ${SVGS}
	echo "   MAKE	$(@F)"
	${PYTHON} -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --color_format glyf_colr_1 \
		      --fea_file $*/colr.fea \
		      --output_file $@

%/svg.ttf: %/colr.toml %/glyphmap.csv %/colr.fea ${SVGS}
	echo "   MAKE	$(@F)"
	${PYTHON} -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --color_format untouchedsvg \
		      --fea_file $*/colr.fea \
		      --output_file $@

%/colr.ufo: %/colr.toml %/glyphmap.csv %/colr.fea ${SVGS}
	echo "   MAKE	$(@F)"
	${PYTHON} -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --fea_file $*/colr.fea \
		      --output_file $@

${FONTDIR}/${NAME}${COLRv1}-%.ttf: ${BUILDDIR}/${NAME}.designspace ${COLRDIR}/%/colr.ttf ${COLRDIR}/%/svg.ttf
	echo "   MAKE	$(@F)"
	$(call generate_fonts,ttf,$<,$@,$(*F))
	${PYTHON} ${SCRIPTDIR}/mknocolr.py $@ $@
	${PYTHON} ${SCRIPTDIR}/mkcolrv1.py $@ ${COLRDIR}/$*/colr.ttf ${COLRDIR}/$*/svg.ttf $@

${FONTDIR}/${NAME}${COLRv0}.ttf: ${BUILDDIR}/${NAME}.ttf
	echo "   MAKE	$(@F)"
	mkdir -p $(@D)
	${PYTHON} ${SCRIPTDIR}/mkcolrv0.py $< $@ ${COLRv0}

${BUILDDIR}/${NAME}.ttf: ${BUILDDIR}/${NAME}.designspace
	echo "   MAKE	$(@F)"
	$(call generate_fonts,variable,$<,$@)

${FONTDIR}/${NAME}.ttf: ${BUILDDIR}/${NAME}.ttf
	mkdir -p $(@D)
	${PYTHON} ${SCRIPTDIR}/mknocolr.py $< $@

${BUILDDIR}/${NAME}.glyphs: ${SOURCEDIR}/${NAME}.glyphspackage ${SOURCEDIR}/${LATIN}.glyphspackage
	echo "   GEN	$(@F)"
	mkdir -p ${BUILDDIR}
	${PYTHON} ${SCRIPTDIR}/prepare.py --out-file=$@ $< $(word 2,$+)

${BUILDDIR}/${NAME}.designspace: ${BUILDDIR}/${NAME}.glyphs
	echo "   GEN	$(@F)"
	${PYTHON} -m glyphsLib glyphs2ufo \
		    -m ${BUILDDIR} \
		    --minimal \
		    --generate-GDEF \
		    --write-public-skip-export-glyphs \
		    --no-preserve-glyphsapp-metadata \
		    --no-store-editor-state \
		    $<

${BUILDDIR}/dist/${FONTDIR}/%: ${FONTDIR}/%
	mkdir -p $(@D)
	${PYTHON} ${SCRIPTDIR}/dist.py $< $@

${SVG}: ${FONTDIR}/${NAME}.ttf
	$(info   SVG    $(@F))
	${PYTHON} -m alifTools.sample $< \
				      -t "${SAMPLE}" \
                                      --features="+cv01,-cv01[6],-cv01[32:36],+cv02[40],-cv01[45]" \
				      --foreground=1F2328 \
				      --dark-foreground=D1D7E0 \
				      -o $@

dist: ${DTTF}
	echo "   DIST   ${DIST}"
	install -Dm644 -t ${DIST} ${DTTF}
	install -Dm644 -t ${DIST} OFL.txt
	install -Dm644 -t ${DIST} README.md
	echo "   ZIP    ${DIST}"
	zip -q -r ${DIST}.zip ${DIST}

clean:
	rm -rf ${TTF} ${SVG} ${BUILDDIR} ${NAME}-${VERSION} ${NAME}-${VERSION}.zip
