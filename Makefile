VERSION=0.4
NAME=ReemKufi
LATIN=JosefinSans

DIST=$(NAME)-$(VERSION)

SRCDIR=sources
BLDDIR=build
DOCDIR=documentation
TOOLDIR=tools

PREPARE=$(TOOLDIR)/prepare.py

FONTS=Regular

UFO=$(FONTS:%=$(BLDDIR)/$(NAME)-%.ufo)
OTF=$(FONTS:%=$(NAME)-%.otf)
TTF=$(FONTS:%=$(NAME)-%.ttf)
PDF=$(DOCDIR)/$(NAME)-Table.pdf
PNG=$(DOCDIR)/$(NAME)-Sample.png

LATIN_SUBSET=$(SRCDIR)/latin-subset.txt

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

define get_unicodes
$(shell
python -c "from defcon import Font;                                            \
           font = Font('$(UFO)');                                              \
           unicodes = font.lib['org.mada.subsetUnicodes'];                     \
           print(' '.join(['U+%04X' % u for u in unicodes]));                  \
")
endef

define subset_fonts
echo "   SUB	$(2)"
pyftsubset $(1)                                                                \
           --unicodes='$(call get_unicodes)'                                   \
           --layout_features='*'                                               \
           --name-IDs='*'                                                      \
           --notdef-outline                                                    \
           --glyph-names                                                       \
           --recalc-average-width                                              \
           --output-file=$(2)                                                  \
           ;
endef

all: otf doc

otf: $(OTF)
ttf: $(TTF)
ufo: $(UFO)
doc: $(PDF) $(PNG)

SHELL=/usr/bin/env bash

$(NAME)-%.otf: $(BLDDIR)/master_otf/$(NAME)-%.otf
	@$(call subset_fonts,$<,$@)

$(NAME)-%.ttf: $(BLDDIR)/master_ttf/$(NAME)-%.ttf
	@$(call subset_fonts,$<,$@)

$(BLDDIR)/master_otf/$(NAME)-%.otf: $(UFO)
	@$(call generate_fonts,otf,$<)

$(BLDDIR)/master_ttf/$(NAME)-%.ttf: $(UFO)
	@$(call generate_fonts,ttf,$<)

$(BLDDIR)/$(NAME)-%.ufo: $(SRCDIR)/$(NAME)-%.ufo $(SRCDIR)/$(LATIN)-%.ufo
	@echo "   GEN	$@"
	@python $(PREPARE) --version=$(VERSION) --latin-subset=$(LATIN_SUBSET) --out-file=$@ $< $(word 2,$+)
	@$(call update_epoch,$<)

$(PDF): $(NAME)-Regular.otf
	@echo "   GEN	$@"
	@mkdir -p $(DOCDIR)
	@fntsample --font-file $< --output-file $@.tmp --write-outline
	@mutool clean -d -i -f -a $@.tmp $@
	@rm -f $@.tmp

$(PNG): $(NAME)-Regular.otf
	@echo "   GEN	$@"
	@hb-view --font-file=$< \
		 --output-file=$@ \
		 --text="ريم على القــاع بين البــان و العـلم   أحل سفك دمي في الأشهر الحرم" \
		 --features="+cv01,-cv01[6],-cv01[32:36],-cv01[45]"

dist: ttf
	@mkdir -p $(NAME)-$(VERSION)/ttf
	@cp $(OTF) $(PDF) $(NAME)-$(VERSION)
	@cp $(TTF) $(NAME)-$(VERSION)/ttf
	@cp OFL.txt $(NAME)-$(VERSION)
	@sed -e "/^!\[Sample\].*./d" README.md > $(NAME)-$(VERSION)/README.txt
	@zip -r $(NAME)-$(VERSION).zip $(NAME)-$(VERSION)

clean:
	@rm -rf $(OTF) $(TTF) $(PDF) $(PNG) $(BLDDIR) $(NAME)-$(VERSION) $(NAME)-$(VERSION).zip
