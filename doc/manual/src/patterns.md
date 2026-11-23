# Patterns

Gamelan parts are often built from the same short figure, played again
and again, or moved to another tone. A **pattern** gives such a figure a
name, so you write it once:

```scheme
{{#include examples/patterns.nts}}
```

- `(pattern norot :instrument reyong …)` names a figure for the reyong.
  Its notes are checked against the reyong's pots, even if no part uses
  it yet.
- `@norot` plays the figure where you write it, in a part, in a `rep`,
  or in another pattern.
- `(@ norot :step -1)` plays it moved one degree down the scale: every
  `i` becomes `a`, every `o` becomes `i`. `:step 1` moves it one degree
  up. Notes written by number move by that many pots instead.

## Lengths in a pattern

A pattern means the same wherever you use it. Its notes start at one
pulse each unless it says otherwise, as `o2:1/4` does here. After the
pattern, the part carries on with the length it had before.

A pattern may start with `_`: it then holds the note before it, wherever
it is used.

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
