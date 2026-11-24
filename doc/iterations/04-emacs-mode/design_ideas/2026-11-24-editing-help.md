# Design idea: help while writing

Status: agreed in discussion (2026-11-24); see "Settled". Not the
design until promoted.

## The idea

A friendly environment helps with the writing too, not only the
picture. Everything here uses what Emacs users already know.

- **Highlighting.** The forms (`piece`, `use`, `pattern`, `part`,
  `score`, `colotomy`, `rep` …), keywords (`:instrument`, `:short` …),
  strings and comments; notes, holds (`_`) and rests in different
  faces, so a part's rhythm is easy to see.
- **Indentation** like Lisp, so `pattern` and `part` bodies line up.
  The mode is derived from `lisp-data-mode`, so moving by forms,
  `show-paren-mode`, commenting and the rest come for free.
- **Completion** (`completion-at-point`, so it works with Corfu,
  Company and plain `M-TAB`):
  - after `:instrument`, the instruments of the templates in use;
  - in a part or pattern, the note names of its instrument, and the
    names of patterns for that instrument;
  - the form names and the keywords each form takes.
- **Eldoc.** With the cursor on a pattern's name, show its definition;
  on an instrument, its keys; on a form, what it takes.
- **Imenu** lists the patterns, parts and scores, so
  `M-x imenu` (or `consult-imenu`) jumps between them.

## Open

- **Where completion gets its facts.** The instruments and their
  notes are defined in templates (`templates/gong-kebyar.nts`) and
  in the file. The mode can read these itself in Emacs Lisp, or ask
  notasi. Asking notasi is always right but needs a new command (e.g.
  `notasi describe FILE`, printing the instruments, notes, patterns
  and scores as data), which is a change to notasi itself. Reading
  them in Emacs Lisp copies some of the reader's rules. Suggested: a
  `notasi describe` command, designed in this iteration, so there is
  one source of truth.
- Is this milestone needed for the iteration's goal, or can it come
  after the preview? Suggested: keep it, after the preview.

## Settled (2026-11-24)

- **Completion, Eldoc and Imenu are not in this iteration.** Its goal
  is the preview; they come in a later iteration. The milestone
  `feat/emacs-help` and the acceptance test's step 6 are dropped.
- **Highlighting and indentation stay**, in the first milestone, with
  the mode derived from `lisp-data-mode`.
- **Where completion gets its facts** (`notasi describe`, or reading
  the forms in Emacs Lisp) is left open, for the iteration that adds
  completion.
