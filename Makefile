GUILE ?= guile
GUILE_FLAGS = --fresh-auto-compile -L .

TESTS = $(wildcard tests/*.scm)

.PHONY: check check-emacs clean golden manual manual-figures manual-serve preview

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

# Draw every score of each example in examples/ with render-piece, to
# build/preview/NAME.png (or NAME_SCORE.png for a file with scores), for a
# person to check how figures look. Needs typst.
preview:
	@mkdir -p build/preview
	@$(GUILE) $(GUILE_FLAGS) scripts/preview.scm

clean:
	rm -f *.log tests/*.log
	rm -rf doc/manual/book doc/manual/src/figures

# The user manual (doc/manual/), built with mdBook into doc/manual/book/.
# Draw every figure a manual page shows as figures/NAME.svg from
# examples/NAME.nts, or figures/NAME_SCORE.svg from its score SCORE
# (needs Guile and Typst), then build the book.
MANUAL_SRC = doc/manual/src

manual-figures:
	@mkdir -p $(MANUAL_SRC)/figures
	@for f in $$(grep -oh 'figures/[a-z0-9_-]*\.svg' $(MANUAL_SRC)/*.md | sed 's|figures/||; s|\.svg$$||' | sort -u); do \
	  n=$${f%%_*}; s=$${f#$$n}; s=$${s#_}; \
	  scripts/notasi render $(MANUAL_SRC)/examples/$$n.nts $${s:+--score $$s} \
	    -o $(MANUAL_SRC)/figures/$$f.svg >/dev/null || exit 1; \
	done

manual: manual-figures
	mdbook build doc/manual

manual-serve: manual-figures
	mdbook serve doc/manual --open
