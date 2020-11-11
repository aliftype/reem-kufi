VERSION=0.9
NAME=ReemKufi
LATIN=JosefinSans

DIST=$(NAME)-$(VERSION)

BUILDDIR=build
TOOLDIR=tools

PYTHON ?= python3

PREPARE=$(TOOLDIR)/prepare.py

FONTS=Regular Medium Semibold Bold

OTF=$(FONTS:%=$(NAME)-%.otf) $(NAME)-VF.otf
TTF=$(FONTS:%=$(NAME)-%.ttf) $(NAME)-VF.ttf
SAMPLE=Sample.svg

export SOURCE_DATE_EPOCH ?= 0

define generate_fonts
PYTHONPATH=$(5):${PYTHONMATH}                                                  \
fontmake --glyphs $(2)                                                         \
         --output $(1)                                                         \
         --output-path $(3)                                                    \
         $(if $(4),--interpolate '.* $(4)',)                                   \
         --verbose WARNING                                                     \
         --feature-writer KernFeatureWriter                                    \
         --feature-writer markFeatureWriter::MarkFeatureWriter                 \
         --subroutinizer cffsubr                                               \
         --overlaps-backend pathops                                            \
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
	@$(call generate_fonts,otf,$<,$@,$*,$(abspath $(TOOLDIR)))

$(NAME)-VF.otf: $(BUILDDIR)/$(NAME).glyphs
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,variable-cff2,$<,$@,,$(abspath $(TOOLDIR)))

$(NAME)-%.ttf: $(BUILDDIR)/$(NAME).glyphs
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,ttf,$<,$@,$*,$(abspath $(TOOLDIR)))

$(NAME)-VF.ttf: $(BUILDDIR)/$(NAME).glyphs
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,variable,$<,$@,,$(abspath $(TOOLDIR)))

$(BUILDDIR)/$(NAME).glyphs: $(NAME).glyphs $(LATIN).glyphs $(BUILDDIR)
	@echo "   GEN	$(@F)"
	@$(PYTHON) $(PREPARE) --version=$(VERSION) --out-file=$@ $< $(word 2,$+)

$(SAMPLE): $(NAME)-Regular.otf
	@echo "   GEN	$(@F)"
	@hb-view --font-file=$< \
		 --output-file=$@ \
		 --text="ريم على القــاع بين البــان و العـلم   أحل سفك دمي في الأشهر الحرم" \
		 --features="+cv01,-cv01[6],-cv01[32:36],+cv02[40],-cv01[45]"

dist: ttf
	@mkdir -p $(NAME)-$(VERSION)/ttf
	@cp $(OTF) $(NAME)-$(VERSION)
	@cp $(TTF) $(NAME)-$(VERSION)/ttf
	@cp OFL.txt $(NAME)-$(VERSION)
	@sed -e "/^!\[Sample\].*./d" README.md > $(NAME)-$(VERSION)/README.txt
	@zip -r $(NAME)-$(VERSION).zip $(NAME)-$(VERSION)

clean:
	@rm -rf $(OTF) $(TTF) $(SAMPLE) $(BUILDDIR) $(NAME)-$(VERSION) $(NAME)-$(VERSION).zip
