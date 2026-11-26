GUILE ?= guile
GUILE_FLAGS = --fresh-auto-compile -L .

TESTS = $(wildcard tests/*.scm)

.PHONY: check check-emacs clean golden images manual manual-figures manual-serve

check:
	@status=0; \
	for t in $(TESTS); do \
	  echo "== $$t"; \
	  $(GUILE) $(GUILE_FLAGS) $$t || status=1; \
	done; \
	exit $$status

# The Emacs package (editors/emacs/, 08): its ERT tests, byte-compiling
# with warnings as errors, checkdoc and package-lint.  Not part of
# `make check`, which doesn't need Emacs.  EMACS is `emacs`, or the
# macOS app when `emacs` isn't on the PATH.  package-lint is installed
# from MELPA into build/emacs-packages/ the first time.
EMACS ?= $(or $(shell command -v emacs 2>/dev/null),$(wildcard /Applications/Emacs.app/Contents/MacOS/Emacs),emacs)
EMACS_BATCH = $(EMACS) -Q --batch
EMACS_DIR = editors/emacs

check-emacs:
	$(EMACS_BATCH) -L $(EMACS_DIR) -l ert -l $(EMACS_DIR)/notasi-mode-tests.el \
	  -f ert-run-tests-batch-and-exit
	@mkdir -p build/emacs
	cp $(EMACS_DIR)/notasi-mode.el build/emacs/
	$(EMACS_BATCH) -L build/emacs --eval '(setq byte-compile-error-on-warn t)' \
	  -f batch-byte-compile build/emacs/notasi-mode.el
	$(EMACS_BATCH) -l $(EMACS_DIR)/check.el -f notasi-check-checkdoc \
	  $(EMACS_DIR)/notasi-mode.el
	$(EMACS_BATCH) -l $(EMACS_DIR)/check.el -f notasi-check-package-lint \
	  $(EMACS_DIR)/notasi-mode.el

# Rewrite tests/golden/ from examples/ after an intended output change.
golden:
	$(GUILE) $(GUILE_FLAGS) tests/golden.scm --update

# The committed drawings (07, ADR 0052): every score of every gallery
# file into examples/gallery/images/, and each image a manual page links
# (figures/NAME.png for the example's first score, figures/NAME_SCORE.png
# for its score SCORE) into examples/manual/images/.  Each folder is
# emptied first.  Needs Guile and Typst.  The committed images are the
# ones CI draws on Linux; images drawn elsewhere are for looking only.
IMAGES_PPI = 144
NOTASI = scripts/notasi
MANUAL_SRC = doc/manual/src
MANUAL_EXAMPLES = examples/manual

images:
	@mkdir -p examples/gallery/images $(MANUAL_EXAMPLES)/images
	@rm -f examples/gallery/images/*.png $(MANUAL_EXAMPLES)/images/*.png
	@for f in examples/gallery/*.nts; do \
	  $(NOTASI) render $$f --all --format png --ppi $(IMAGES_PPI) \
	    -o examples/gallery/images/ >/dev/null || exit 1; \
	done
	@for f in $$(grep -oh 'figures/[a-z0-9_-]*\.png' $(MANUAL_SRC)/*.md | sed 's|figures/||; s|\.png$$||' | sort -u); do \
	  n=$${f%%_*}; s=$${f#$$n}; s=$${s#_}; \
	  $(NOTASI) render $(MANUAL_EXAMPLES)/$$n.nts $${s:+--score $$s} \
	    --ppi $(IMAGES_PPI) -o $(MANUAL_EXAMPLES)/images/$$f.png >/dev/null || exit 1; \
	done

clean:
	rm -f *.log tests/*.log
	rm -rf doc/manual/book doc/manual/src/figures

# The user manual (doc/manual/), built with mdBook into doc/manual/book/.
# Copy the committed images its pages show from examples/manual/images/
# into figures/ (generated, not committed), then build the book: mdBook
# alone, nothing is drawn (07, ADR 0052).
manual-figures:
	@mkdir -p $(MANUAL_SRC)/figures
	@cp $(MANUAL_EXAMPLES)/images/*.png $(MANUAL_SRC)/figures/

manual: manual-figures
	mdbook build doc/manual

manual-serve: manual-figures
	mdbook serve doc/manual --open
