VERSION=1.2
NAME=ReemKufi
COLOR=Fun
LATIN=JosefinSans

DIST=$(NAME)-$(VERSION)

BUILDDIR=build

PYTHON ?= python3

FONTS=Regular Medium SemiBold Bold

OTF=$(FONTS:%=$(NAME)-%.otf) $(NAME).otf $(NAME)$(COLOR).otf
TTF=$(FONTS:%=$(NAME)-%.ttf) $(NAME).ttf $(NAME)$(COLOR).ttf
SVG=$(FONTS:%=$(BUILDDIR)/$(NAME)-%.svg)
SAMPLE=Sample.svg

export SOURCE_DATE_EPOCH ?= $(shell stat -c "%Y" $(NAME).glyphs)

define generate_fonts
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

otf: $(OTF)
ttf: $(TTF)
doc: $(SAMPLE)

SHELL=/usr/bin/env bash


$(NAME)-%.otf: $(BUILDDIR)/$(NAME).designspace
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,otf,$<,$@,$*)

$(BUILDDIR)/$(NAME).otf: $(BUILDDIR)/$(NAME).designspace
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,variable-cff2,$<,$@)

$(NAME).otf: $(BUILDDIR)/$(NAME).otf
	@$(PYTHON) update-stat.py $< $@

$(NAME)$(COLOR).%: $(NAME).%
	@echo "   MAKE	$(@F)"
	@$(PYTHON) rename-color.py $< $@ $(COLOR) ss02

$(NAME)-%.ttf: $(BUILDDIR)/$(NAME).designspace
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,ttf,$<,$@,$*)

$(BUILDDIR)/$(NAME).ttf: $(BUILDDIR)/$(NAME).designspace
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,variable,$<,$@)

$(NAME).ttf: $(BUILDDIR)/$(NAME).ttf
	@$(PYTHON) update-stat.py $< $@

$(BUILDDIR)/$(NAME).glyphs: $(NAME).glyphs $(LATIN).glyphs
	@echo "   GEN	$(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PYTHON) prepare.py --version=$(VERSION) --out-file=$@ $< $(word 2,$+)

$(BUILDDIR)/$(NAME).designspace: $(BUILDDIR)/$(NAME).glyphs
	@echo "   GEN	$(@F)"
	@glyphs2ufo -m $(BUILDDIR)                                             \
		    --minimal                                                  \
		    --generate-GDEF                                            \
		    --write-public-skip-export-glyphs                          \
		    --no-preserve-glyphsapp-metadata                           \
		    --no-store-editor-state                                    \
		    $<

$(BUILDDIR)/$(NAME)-%.svg: $(NAME)-%.otf
	@echo "   GEN	$(@F)"
	@mkdir -p $(BUILDDIR)
	@hb-view --font-file=$< \
		 --output-file=$@ \
		 --text="ريم على القــاع بين البــان و العـلم   أحل سفك دمي في الأشهر الحرم" \
		 --features="+cv01,-cv01[6],-cv01[32:36],+cv02[40],-cv01[45]"

$(SAMPLE): $(SVG)
	@echo "   SAMPLE    $(@F)"
	@$(PYTHON) mksample.py -o $@ $+

dist: ttf
	@mkdir -p $(NAME)-$(VERSION)/ttf
	@cp $(OTF) $(NAME)-$(VERSION)
	@cp $(TTF) $(NAME)-$(VERSION)/ttf
	@cp OFL.txt $(NAME)-$(VERSION)
	@sed -e "/^!\[Sample\].*./d" README.md > $(NAME)-$(VERSION)/README.txt
	@zip -r $(NAME)-$(VERSION).zip $(NAME)-$(VERSION)

clean:
	@rm -rf $(OTF) $(TTF) $(SAMPLE) $(BUILDDIR) $(NAME)-$(VERSION) $(NAME)-$(VERSION).zip
