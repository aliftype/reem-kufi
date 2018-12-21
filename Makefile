VERSION=0.7
NAME=ReemKufi
LATIN=JosefinSans

DIST=$(NAME)-$(VERSION)

BUILDDIR=build
TOOLDIR=tools

PYTHON ?= python3

PREPARE=$(TOOLDIR)/prepare.py
MKLATIN=$(TOOLDIR)/mklatin.py

FONTS=Regular

UFO=$(FONTS:%=$(BUILDDIR)/$(NAME)-%.ufo)
OTF=$(FONTS:%=$(NAME)-%.otf)
TTF=$(FONTS:%=$(NAME)-%.ttf)
PDF=$(NAME)-Table.pdf
PNG=$(NAME)-Sample.png

export SOURCE_DATE_EPOCH ?= 0

define generate_fonts
mkdir -p $(BUILDDIR)
pushd $(BUILDDIR) 1>/dev/null;                                                   \
fontmake --ufo $(abspath $(2))                                                 \
         --output $(1)                                                         \
         --verbose WARNING                                                     \
         ;                                                                     \
popd 1>/dev/null
endef

all: otf doc

otf: $(OTF)
ttf: $(TTF)
ufo: $(UFO)
doc: $(PDF) $(PNG)

SHELL=/usr/bin/env bash

.PRECIOUS: $(BUILDDIR)/master_otf/$(NAME)-%.otf $(BUILDDIR)/master_ttf/$(NAME)-%.ttf $(BUILDDIR)/$(LATIN)-%.ufo

$(NAME)-%.otf: $(BUILDDIR)/master_otf/$(NAME)-%.otf
	@cp $< $@

$(NAME)-%.ttf: $(BUILDDIR)/master_ttf/$(NAME)-%.ttf
	@cp $< $@

$(BUILDDIR)/master_otf/$(NAME)-%.otf: $(UFO)
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,otf,$<)

$(BUILDDIR)/master_ttf/$(NAME)-%.ttf: $(UFO)
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,ttf,$<)

$(BUILDDIR)/$(LATIN)-%.ufo: $(LATIN).glyphs
	@echo "   GEN	$(@F)"
	@$(PYTHON) $(MKLATIN) --out-file=$@ $<

$(BUILDDIR)/$(NAME)-%.ufo: $(NAME)-%.ufo $(BUILDDIR)/$(LATIN)-%.ufo
	@echo "   GEN	$(@F)"
	@$(PYTHON) $(PREPARE) --version=$(VERSION) --out-file=$@ $< $(word 2,$+)
	@$(call update_epoch,$<)

$(PDF): $(NAME)-Regular.otf
	@echo "   GEN	$(@F)"
	@fntsample --font-file $< --output-file $@.tmp                         \
		   --write-outline --use-pango                                 \
		   --style="header-font: Noto Sans Bold 12"                    \
		   --style="font-name-font: Noto Serif Bold 12"                \
		   --style="table-numbers-font: Noto Sans 10"                  \
		   --style="cell-numbers-font:Noto Sans Mono 8"
	@mutool clean -d -i -f -a $@.tmp $@
	@rm -f $@.tmp

$(PNG): $(NAME)-Regular.otf
	@echo "   GEN	$(@F)"
	@hb-view --font-file=$< \
		 --output-file=$@ \
		 --text="ريم على القــاع بين البــان و العـلم   أحل سفك دمي في الأشهر الحرم" \
		 --features="+cv01,-cv01[6],-cv01[32:36],+cv02[40],-cv01[45]"

dist: ttf
	@mkdir -p $(NAME)-$(VERSION)/ttf
	@cp $(OTF) $(PDF) $(NAME)-$(VERSION)
	@cp $(TTF) $(NAME)-$(VERSION)/ttf
	@cp OFL.txt $(NAME)-$(VERSION)
	@sed -e "/^!\[Sample\].*./d" README.md > $(NAME)-$(VERSION)/README.txt
	@zip -r $(NAME)-$(VERSION).zip $(NAME)-$(VERSION)

clean:
	@rm -rf $(OTF) $(TTF) $(PDF) $(PNG) $(BUILDDIR) $(NAME)-$(VERSION) $(NAME)-$(VERSION).zip
