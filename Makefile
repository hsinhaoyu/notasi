GUILE ?= guile
GUILE_FLAGS = --fresh-auto-compile -L .

TESTS = $(wildcard tests/*.scm)

.PHONY: check clean golden manual manual-figures manual-serve preview

check:
	@status=0; \
	for t in $(TESTS); do \
	  echo "== $$t"; \
	  $(GUILE) $(GUILE_FLAGS) $$t || status=1; \
	done; \
	exit $$status

# Rewrite tests/golden/ from examples/ after an intended output change.
golden:
	$(GUILE) $(GUILE_FLAGS) tests/golden.scm --update

# Draw every score of each example in examples/ with render-piece, to
# build/preview/NAME.png (or NAME.SCORE.png for a file with scores), for a
# person to check how figures look. Needs typst.
preview:
	@mkdir -p build/preview
	@$(GUILE) $(GUILE_FLAGS) scripts/preview.scm

clean:
	rm -f *.log tests/*.log
	rm -rf doc/manual/book doc/manual/src/figures

# The user manual (doc/manual/), built with mdBook into doc/manual/book/.
# Draw every figure a manual page shows as figures/NAME.svg from
# examples/NAME.nts, or figures/NAME.SCORE.svg from its score SCORE
# (needs Guile and Typst), then build the book.
MANUAL_SRC = doc/manual/src

manual-figures:
	@mkdir -p $(MANUAL_SRC)/figures
	@for f in $$(grep -oh 'figures/[a-z0-9.-]*\.svg' $(MANUAL_SRC)/*.md | sed 's|figures/||; s|\.svg$$||' | sort -u); do \
	  n=$${f%%.*}; s=$${f#$$n}; s=$${s#.}; \
	  scripts/notasi render $(MANUAL_SRC)/examples/$$n.nts $${s:+--score $$s} \
	    -o $(MANUAL_SRC)/figures/$$f.svg >/dev/null || exit 1; \
	done

manual: manual-figures
	mdbook build doc/manual

manual-serve: manual-figures
	mdbook serve doc/manual --open
