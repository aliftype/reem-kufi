VERSION=1.0
NAME=ReemKufi
LATIN=JosefinSans

DIST=$(NAME)-$(VERSION)

BUILDDIR=build

PYTHON ?= python3

FONTS=Regular Medium SemiBold Bold

OTF=$(FONTS:%=$(NAME)-%.otf) $(NAME).otf
TTF=$(FONTS:%=$(NAME)-%.ttf) $(NAME).ttf
SVG=$(FONTS:%=$(BUILDDIR)/$(NAME)-%.svg)
SAMPLE=Sample.svg

export SOURCE_DATE_EPOCH ?= $(shell stat -c "%Y" $(NAME).glyphs)

define generate_fonts
fontmake --glyphs $(2)                                                         \
         --output $(1)                                                         \
         --output-path $(3)                                                    \
         $(if $(4),--interpolate '.* $(4)',)                                   \
         --verbose WARNING                                                     \
         --overlaps-backend pathops                                            \
         --optimize-cff 1                                                      \
         --flatten-components                                                  \
         --master-dir '{tmp}'                                                  \
         --instance-dir '{tmp}'                                                \
         ;
endef

all: otf doc

otf: $(OTF)
ttf: $(TTF)
doc: $(SAMPLE)

SHELL=/usr/bin/env bash

$(BUILDDIR):
	@mkdir -p $(BUILDDIR)

$(NAME)-%.otf: $(BUILDDIR)/$(NAME).glyphs
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,otf,$<,$@,$*)

$(NAME).otf: $(BUILDDIR)/$(NAME).glyphs
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,variable-cff2,$<,$@)

$(NAME)-%.ttf: $(BUILDDIR)/$(NAME).glyphs
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,ttf,$<,$@,$*)

$(NAME).ttf: $(BUILDDIR)/$(NAME).glyphs
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,variable,$<,$@)

$(BUILDDIR)/$(NAME).glyphs: $(NAME).glyphs $(LATIN).glyphs $(BUILDDIR)
	@echo "   GEN	$(@F)"
	@$(PYTHON) prepare.py --version=$(VERSION) --out-file=$@ $< $(word 2,$+)

$(BUILDDIR)/$(NAME)-%.svg: $(NAME)-%.otf $(BUILDDIR)
	@echo "   GEN	$(@F)"
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
