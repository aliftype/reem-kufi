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
COLRv0 = Fun
COLRv1 = ${NAME}Ink

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
	${COLRv1}

TTF = $(FONTS:%=${FONTDIR}/%.ttf)
SVG = FontSample.svg

GLYPHSFILE = ${SOURCEDIR}/${NAME}.glyphspackage

export SOURCE_DATE_EPOCH ?= $(shell stat -c "%Y" ${GLYPHSFILE})

TAG = $(shell git describe --tags --abbrev=0)
VERSION = ${TAG:v%=%}
DIST = ${NAME}-${VERSION}


define generate_fonts
mkdir -p $(dir $(3));
${PYTHON} -m fontmake                                                          \
    --output $(1)                                                              \
    --output-path $(3)                                                         \
    --verbose WARNING                                                          \
    --overlaps-backend pathops                                                 \
    --flatten-components                                                       \
    --filter ...                                                               \
    --filter "alifTools.filters::ClearPlaceholdersFilter()"                    \
    --filter "alifTools.filters::FontVersionFilter(fontVersion=${VERSION})"    \
    $(2)                                                                       \
    ;
endef

.SECONDARY:
.ONESHELL:
.PHONY: all clean dist ttf doc

all: ttf doc
ttf: ${TTF}
doc: ${SVG}


.SECONDARY:

${FONTDIR}/${COLRv1}.ttf: ${SOURCEDIR}/${COLRv1}.glyphspackage
	$(info   MAKE   ${@F})
	$(call generate_fonts,variable,$<,$@)

${BUILDDIR}/${NAME}.ttf: ${SOURCEDIR}/${NAME}.glyphspackage
	$(info   MAKE   ${@F})
	$(call generate_fonts,variable,$<,$@)

${FONTDIR}/${NAME}.ttf: ${BUILDDIR}/${NAME}.ttf
	mkdir -p ${@D}
	${PYTHON} ${SCRIPTDIR}/mknocolr.py $< $@

${FONTDIR}/${NAME}${COLRv0}.ttf: ${BUILDDIR}/${NAME}.ttf
	$(info   MAKE   ${@F})
	mkdir -p ${@D}
	${PYTHON} ${SCRIPTDIR}/mkcolrv0.py $< $@ ${COLRv0}

${SVG}: ${FONTDIR}/${NAME}.ttf
	$(info   SVG    ${@F})
	${PYTHON} -m alifTools.sample $< \
				      --features="+cv01,-cv01[6],-cv01[32:36],+cv02[40],-cv01[45:]" \
				      --foreground=1F2328 \
				      --dark-foreground=D1D7E0 \
				      -o $@

dist: ${TTF}
	$(info   DIST   ${DIST}.zip)
	install -Dm644 -t ${DIST} ${TTF}
	install -Dm644 -t ${DIST} README.md
	install -Dm644 -t ${DIST} OFL.txt
	zip -rq ${DIST}.zip ${DIST}

clean:
	rm -rf ${TTF} ${SVG} ${BUILDDIR} ${DIST} ${DIST}.zip
