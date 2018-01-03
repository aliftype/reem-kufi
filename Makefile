VERSION=0.6
NAME=ReemKufi
LATIN=JosefinSans

DIST=$(NAME)-$(VERSION)

SRCDIR=sources
BLDDIR=build
DOCDIR=documentation
TOOLDIR=tools

PYTHON ?= python3

PREPARE=$(TOOLDIR)/prepare.py
MKLATIN=$(TOOLDIR)/mklatin.py

FONTS=Regular

UFO=$(FONTS:%=$(BLDDIR)/$(NAME)-%.ufo)
OTF=$(FONTS:%=$(NAME)-%.otf)
TTF=$(FONTS:%=$(NAME)-%.ttf)
PDF=$(DOCDIR)/FontTable.pdf
PNG=$(DOCDIR)/FontSample.png

define generate_fonts
echo "   MAKE  $(1)"
mkdir -p $(BLDDIR)
export SOURCE_DATE_EPOCH=$(EPOCH);                                             \
pushd $(BLDDIR) 1>/dev/null;                                                   \
fontmake --ufo $(abspath $(2))                                                 \
         --autohint                                                            \
         --output $(1)                                                         \
         --verbose WARNING                                                     \
         ;                                                                     \
popd 1>/dev/null
endef

EPOCH = 0
define update_epoch
if [ `stat -c "%Y" $(1)` -gt $(EPOCH) ]; then                                  \
    true;                                                                      \
    $(eval EPOCH := $(shell stat -c "%Y" $(1)))                                \
fi
endef

all: otf doc

otf: $(OTF)
ttf: $(TTF)
ufo: $(UFO)
doc: $(PDF) $(PNG)

SHELL=/usr/bin/env bash

.PRECIOUS: $(BLDDIR)/master_otf/$(NAME)-%.otf $(BLDDIR)/master_ttf/$(NAME)-%.ttf $(BLDDIR)/$(LATIN)-%.ufo

$(NAME)-%.otf: $(BLDDIR)/master_otf/$(NAME)-%.otf
	@cp $< $@

$(NAME)-%.ttf: $(BLDDIR)/master_ttf/$(NAME)-%.ttf
	@cp $< $@

$(BLDDIR)/master_otf/$(NAME)-%.otf: $(UFO)
	@$(call generate_fonts,otf,$<)

$(BLDDIR)/master_ttf/$(NAME)-%.ttf: $(UFO)
	@$(call generate_fonts,ttf,$<)

$(BLDDIR)/$(LATIN)-%.ufo: $(SRCDIR)/$(LATIN).glyphs
	@echo "   GEN	$@"
	@$(PYTHON) $(MKLATIN) --out-file=$@ $<

$(BLDDIR)/$(NAME)-%.ufo: $(SRCDIR)/$(NAME)-%.ufo $(BLDDIR)/$(LATIN)-%.ufo
	@echo "   GEN	$@"
	@$(PYTHON) $(PREPARE) --version=$(VERSION) --out-file=$@ $< $(word 2,$+)
	@$(call update_epoch,$<)

$(PDF): $(NAME)-Regular.otf
	@echo "   GEN	$@"
	@mkdir -p $(DOCDIR)
	@fntsample --font-file $< --output-file $@.tmp --write-outline --use-pango
	@mutool clean -d -i -f -a $@.tmp $@
	@rm -f $@.tmp

$(PNG): $(NAME)-Regular.otf
	@echo "   GEN	$@"
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
	@rm -rf $(OTF) $(TTF) $(PDF) $(PNG) $(BLDDIR) $(NAME)-$(VERSION) $(NAME)-$(VERSION).zip
