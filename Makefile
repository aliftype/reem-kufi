VERSION=0.3
NAME=ReemKufi
LATIN=JosefinSans

DIST=$(NAME)-$(VERSION)

SRCDIR=sources
DOCDIR=documentation
TOOLDIR=tools

BUILD=$(TOOLDIR)/build.py

FONTS=Regular

UFO=$(FONTS:%=$(SRCDIR)/$(NAME)-%.ufo)
OTF=$(FONTS:%=$(NAME)-%.otf)
TTF=$(FONTS:%=$(NAME)-%.ttf)
PDF=$(DOCDIR)/$(NAME)-Table.pdf

LATIN_SUBSET=$(SRCDIR)/latin-subset.txt

all: otf doc

otf: $(OTF)
ttf: $(TTF)
ufo: $(UFO)
doc: $(PDF)

$(NAME)-%.otf $(NAME)-%.ttf: $(SRCDIR)/$(NAME)-%.ufo $(SRCDIR)/$(LATIN)-%.ufo Makefile $(BUILD)
	@echo "   GEN	$@"
	@FILES=($+); python $(BUILD) --version=$(VERSION) --out-file=$@ --latin-subset=$(LATIN_SUBSET) $< $${FILES[1]}

$(DOCDIR)/$(NAME)-Table.pdf: $(NAME)-Regular.otf
	@echo "   GEN	$@"
	@mkdir -p $(DOCDIR)
	@fntsample --font-file $< --output-file $@.tmp --print-outline > $@.txt
	@pdfoutline $@.tmp $@.txt $@.comp
	@pdftk $@.comp output $@ uncompress
	@rm -f $@.tmp $@.comp $@.txt

dist: ttf
	@mkdir -p $(NAME)-$(VERSION)/ttf
	@cp $(OTF) $(PDF) $(NAME)-$(VERSION)
	@cp $(TTF) $(NAME)-$(VERSION)/ttf
	@cp OFL.txt $(NAME)-$(VERSION)
	@markdown README.md | w3m -dump -T text/html | sed -e "/^Sample$$/d" > $(NAME)-$(VERSION)/README.txt
	@zip -r $(NAME)-$(VERSION).zip $(NAME)-$(VERSION)

clean:
	@rm -rf $(OTF) $(TTF) $(PDF) $(NAME)-$(VERSION) $(NAME)-$(VERSION).zip
