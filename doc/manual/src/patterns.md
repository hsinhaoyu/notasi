# Patterns

Gamelan parts are often built from the same short figure, played again
and again, or moved to another tone. A **pattern** gives such a figure a
name, so you write it once:

```scheme
{{#include ../../../examples/manual/patterns.nts}}
```

- `(pattern norot :instrument reyong …)` names a figure for the reyong.
  Its notes are checked against the reyong's pots, even if no part uses
  it yet.
- `@norot` plays the figure where you write it, in a part, in a `rep`,
  or in another pattern.
- `(@ norot :step -1)` plays it moved one pitch down the scale: every
  `i` becomes `a`, every `o` becomes `i`. `:step 1` moves it one pitch
  up. Notes written by number move by that many pots instead.

## Lengths in a pattern

A pattern means the same wherever you use it. Its notes start at one
pulse each unless it says otherwise, as `o2:1/4` does here. After the
pattern, the part carries on with the length it had before.

A pattern may start with `_`: it then holds the note before it, wherever
it is used.

## Naming patterns in the score

A pattern can have names, `:short` and `:long`, and a note about how it
is played, `:annotation`. A use can give its own, so that a moved
figure is named after the tone it plays. A group of a
[score](scores.md) can show them in an **annotation row**, a row of
text only, under (or over) its notes:

```scheme
{{#include ../../../examples/manual/annotation-row.nts}}
```

![The norot figures with their notes](figures/annotation-row.png)

`:annotation-part` turns the row on and says which part of the group
it shows. The other settings are on the group too:

| Setting | What it does |
|---|---|
| `:annotation-part PART` | Show an annotation row, with PART's patterns and text. PART is a part of the group. |
| `:annotation-position below` / `above` | Where the row goes: under the notes (the default) or over them. |
| `:annotation-align left` / `center` / `right` | Where a pattern's text sits in its stretch: `left` unless you say. |
| `:annotation-level N` | Which patterns to name: 0 (the default) for those used in the part, 1 for those inside them, and so on. |
| `:annotation-text annotation` / `short` / `long` | What a pattern shows: its `:annotation` (the default, or its long name when it has none), its short name or its long name. |
| `:annotation-label "…"` | A label for the row, beside it where the row labels are. |

A text too long for its stretch is cut off at the stretch's end, and
starts at the left whatever the alignment.

### Text of your own

`(text "angsel")` in a part writes "angsel" in the annotation row at
that point, and runs until the next text in the row. `(text "angsel"
2)` covers two pulses from that point. Text takes no time: the music
around it is not moved. It can go inside a pattern, so that every use
of the pattern carries it, and inside `rep`.

Where your text and a pattern's name would overlap, your text is shown
and the pattern's name is cut short. Text in a part that has no
annotation row is not shown.

## The rules

- Every pattern says which instrument it is for, with `:instrument`.
  It can only be used on that instrument.
- A pattern's name can't start with `:` or `@`.
- A pattern can use other patterns, but not itself.
- `|` and `||` inside a pattern are checked where it is used.
- Patterns can go in a template too (see [Templates](templates.md)).

When notasi finds a mistake inside a pattern, it says which pattern, and
where it was used.

The full rules are in the
[notation reference](https://github.com/hsinhaoyu/notasi/blob/dev/doc/design/01-notation.md).
