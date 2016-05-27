NAME=ReemKufi
VERSION=0.1
EXT=otf
LATIN=JosefinSans

SRCDIR=sources
DOCDIR=documentation
LATIN_SUBSET=$(SRCDIR)/latin-subset.txt
TOOLDIR=tools
TESTDIR=tests
DIST=$(NAME)-$(VERSION)

PY=python2
PY3=python3
BUILD=$(TOOLDIR)/build.py
RUNTEST=$(TOOLDIR)/runtest.py
SFDLINT=$(TOOLDIR)/sfdlint.py

FONTS=Regular #Bold
#TESTS=wb yeh-ragaa

UFO=$(FONTS:%=$(SRCDIR)/$(NAME)-%.ufo)
OTF=$(FONTS:%=$(NAME)-%.$(EXT))
PDF=$(DOCDIR)/$(NAME)-table.pdf

#TST=$(TESTS:%=$(TESTDIR)/%.txt)
#SHP=$(TESTS:%=$(TESTDIR)/%.shp)
#RUN=$(TESTS:%=$(TESTDIR)/%.run)
LNT=$(FONTS:%=$(TESTDIR)/$(NAME)-%.lnt)

#all: lint otf doc
all: otf doc

otf: $(OTF)
ufo: $(UFO)
doc: $(PDF)
lint: $(LNT)
check: lint # $(RUN)

$(NAME)-%.$(EXT): $(SRCDIR)/$(NAME)-%.ufo $(SRCDIR)/$(LATIN)-%.ufo $(SRCDIR)/$(NAME).fea Makefile $(BUILD)
	@echo "   GEN	$@"
	@FILES=($+); $(PY3) $(BUILD) --version=$(VERSION) --out-file=$@ --feature-file=$${FILES[2]} --latin-subset=$(LATIN_SUBSET) $< $${FILES[1]}

#$(TESTDIR)/%.run: $(TESTDIR)/%.txt $(TESTDIR)/%.shp $(NAME)-Regular.$(EXT)
#	@echo "   TST	$*"
#	@$(PY3) $(RUNTEST) $(NAME)-Regular.$(EXT) $(@D)/$*.txt $(@D)/$*.shp $(@D)/$*.run

$(TESTDIR)/%.lnt: $(SRCDIR)/%.sfdir $(SFDLINT)
	@echo "   LNT	$<"
	@mkdir -p $(TESTDIR)
	@$(PY) $(SFDLINT) $< $@

$(DOCDIR)/$(NAME)-table.pdf: $(NAME)-Regular.$(EXT)
	@echo "   GEN	$@"
	@mkdir -p $(DOCDIR)
	@fntsample --font-file $< --output-file $@.tmp --print-outline > $@.txt
	@pdfoutline $@.tmp $@.txt $@.comp
	@pdftk $@.comp output $@ uncompress
	@rm -f $@.tmp $@.comp $@.txt

dist:
	@mkdir -p $(NAME)-$(VERSION)
	@cp $(OTF) $(PDF) $(NAME)-$(VERSION)
	@cp OFL.txt $(NAME)-$(VERSION)
	@markdown README.md | w3m -dump -T text/html | sed -e "/^Sample$$/d" > $(NAME)-$(VERSION)/README.txt
	@zip -r $(NAME)-$(VERSION).zip $(NAME)-$(VERSION)

clean:
	@rm -rf $(OTF) $(PDF) $(NAME)-$(VERSION) $(NAME)-$(VERSION).zip
