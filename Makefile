SHELL=/usr/bin/env bash

FAMILY=Reem Kufi
NAME=ReemKufi
COLR=Fun
COLRv1=Ink
LATIN=JosefinSans

DIST=$(NAME)-$(VERSION)

BUILDDIR=build

FONTS=Regular Medium SemiBold Bold

BASE=$(FONTS:%=$(NAME)-%.otf)

OTF=$(FONTS:%=$(NAME)-%.otf) $(NAME).otf $(NAME)$(COLR).otf $(NAME)$(COLRv1)-Regular.otf #$(NAME)$(COLRv1)-Bold.otf
TTF=$(FONTS:%=$(NAME)-%.ttf) $(NAME).ttf $(NAME)$(COLR).ttf $(NAME)$(COLRv1)-Regular.ttf #$(NAME)$(COLRv1)-Bold.ttf
SVG=$(FONTS:%=$(BUILDDIR)/$(NAME)-%.svg)
SAMPLE=Sample.svg

TAG=$(shell git describe --tags --abbrev=0)
VERSION=$(TAG:v%=%)

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

.SECONDARY:

SVGS_ = $(notdir $(wildcard Images/Regular/*.svg))
SVGS = $(SVGS_:%=\%/%)

COLRDIR = $(BUILDDIR)/colr


$(COLRDIR)/%.svg: Images/%.svg
	@echo "   PICO	$(@F)"
	@mkdir -p $(@D)
	@picosvg --output_file $@ $<

$(COLRDIR)/%/colr.toml: colr.toml
	@mkdir -p $(@D)
	@cp $< $@

%/colr.fea:
	@mkdir -p $(@D)
	@touch $@

%/glyphmap.csv: $(NAME).glyphs
	@mkdir -p $(@D)
	@python3 mkglyphmap.py $< $(@D)

%/colr.otf: %/colr.toml %/glyphmap.csv %/colr.fea $(SVGS)
	@echo "   MAKE	$(@F)"
	@python3 -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --color_format cff_colr_1 \
		      --fea_file $*/colr.fea \
		      --output_file $@

%/colr.ttf: %/colr.toml %/glyphmap.csv %/colr.fea $(SVGS)
	@echo "   MAKE	$(@F)"
	@python3 -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --color_format glyf_colr_1 \
		      --fea_file $*/colr.fea \
		      --output_file $@

%/colr.ufo: %/colr.toml %/glyphmap.csv %/colr.fea $(SVGS)
	@echo "   MAKE	$(@F)"
	@python3 -m nanoemoji.write_font -v -1 \
		      --config_file $< \
		      --glyphmap_file $*/glyphmap.csv \
		      --fea_file $*/colr.fea \
		      --output_file $@

$(NAME)$(COLRv1)-%.otf: $(NAME)-%.otf $(COLRDIR)/%/colr.otf
	@echo "   MAKE	$(@F)"
	@python3 mkcolrv1.py $< $(COLRDIR)/$*/colr.otf \
			     "$(FAMILY)" "$(COLRv1)" \
			     $@

$(NAME)$(COLRv1)-%.ttf: $(NAME)-%.ttf $(COLRDIR)/%/colr.ttf
	@echo "   MAKE	$(@F)"
	@python3 mkcolrv1.py $< $(COLRDIR)/$*/colr.ttf \
			     "$(FAMILY)" "$(COLRv1)" \
			     $@

$(NAME)-%.otf: $(BUILDDIR)/$(NAME).designspace
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,otf,$<,$@,$*)
	@python3 mknocolr.py $@ $@

$(BUILDDIR)/$(NAME).otf: $(BUILDDIR)/$(NAME).designspace
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,variable-cff2,$<,$@)

$(NAME).otf: $(BUILDDIR)/$(NAME).otf
	@python3 update-stat.py $< $@
	@python3 mknocolr.py $@ $@

$(NAME)$(COLR).%: $(BUILDDIR)/$(NAME).%
	@echo "   MAKE	$(@F)"
	@python3 update-stat.py $< $@
	@python3 mkcolrv0.py $@ $@ $(COLR)

$(NAME)-%.ttf: $(BUILDDIR)/$(NAME).designspace
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,ttf,$<,$@,$*)
	@python3 mknocolr.py $@ $@

$(BUILDDIR)/$(NAME).ttf: $(BUILDDIR)/$(NAME).designspace
	@echo "   MAKE	$(@F)"
	@$(call generate_fonts,variable,$<,$@)

$(NAME).ttf: $(BUILDDIR)/$(NAME).ttf
	@python3 update-stat.py $< $@
	@python3 mknocolr.py $@ $@

$(BUILDDIR)/$(NAME).glyphs: $(NAME).glyphs $(LATIN).glyphs
	@echo "   GEN	$(@F)"
	@mkdir -p $(BUILDDIR)
	@python3 prepare.py --version=$(VERSION) --out-file=$@ $< $(word 2,$+)

$(BUILDDIR)/$(NAME).designspace: $(BUILDDIR)/$(NAME).glyphs
	@echo "   GEN	$(@F)"
	@glyphs2ufo -m $(BUILDDIR)                                             \
		    --minimal                                                  \
		    --generate-GDEF                                            \
		    --write-public-skip-export-glyphs                          \
		    --no-preserve-glyphsapp-metadata                           \
		    --no-store-editor-state                                    \
		    $<

$(SAMPLE): $(BASE)
	@echo "   SAMPLE    $(@F)"
	@python3 mksample.py $+ \
	  --output=$@ \
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
