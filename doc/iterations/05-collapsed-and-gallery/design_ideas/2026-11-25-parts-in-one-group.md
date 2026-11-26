# Design idea: telling parts apart in one group

Status: agreed in discussion (2026-11-25); only the default sizes are
left to choose by eye.
Not the design until promoted.

## The problem

A group can hold several parts on one instrument (ADR 0011), and the
kotekan does this: the `kotekan` score of `examples/jaya-semara.nts`
puts polos and sangsih in one group, "Gangsa pemade". On `:rows notes`
rows, each note sits in its key's row and takes its key's colour,
whichever part plays it. **Nothing in the drawing says which part a
note belongs to.** The two parts merge into one composite line; the
interlocking, which is the point of drawing them together, can only
be worked out by already knowing the parts.

The same holds for `:rows compact`, which merges the parts into one
line ([collapsed rows](2026-11-25-collapsed-rows.md)).
`:rows parts` keeps them apart, one row per part, but gives up the key
rows, and with them the shape of the melody.

The information is already in the figure: a group's JSON has one
`voice` per member part, named, each with its own events (04, 05). The
template draws every voice the same way.

## Agreed (2026-11-25)

- **Colour stays the pitch colour** (ADR 0017). Parts are not told
  apart by colour. (Considered and dropped: a colour per part, which
  loses pitch colour; and a colour family per part with a shade per
  pitch, whose shades are too alike to read.)
- **Parts are told apart by a symbol and a border.**
- **Only when asked.** Nothing is marked by default: a group's parts
  are drawn as now unless the writer gives the group `:part-marker`.
  There is no default order of symbols. This holds for every kind of
  rows (`notes`, `parts`, `compact`) and for groups of strokes as well
  as pitched parts.
- **Written on the group**, since printing belongs to scores (ADR
  0031):
  ```scheme
  (group "Gangsa pemade"
         :part-marker ((sangsih :symbol dot :border "#d62728"))
    polos sangsih)
  ```
  Each entry names a part of the group and gives its symbol, its
  border, or both. A part with no entry is drawn as now.
- **Symbols**: `none`, `dot`, `ring`, `cross`. Each is small and
  centred in the note's cell; it does not fill the cell.
- **Borders**: the writer gives a part a border colour; that part's
  notes are drawn with a border of that colour, thicker than the
  normal border (ADR 0041).
- **Group only.** `:part-marker` is a group option; a score can't set
  it for its groups.
- **Everything is set per part**, in the part's entry. The keys:

  | Key | Value | Default |
  |---|---|---|
  | `:symbol` | `none`, `dot`, `ring`, `cross` | `none` |
  | `:symbol-size` | a fraction of the cell's narrower side, e.g. `0.3` | chosen by eye |
  | `:symbol-color` | `"#rrggbb"` | near-black, as note labels |
  | `:border` | `"#rrggbb"` | none (the normal border) |
  | `:border-width` | a length, e.g. `"1pt"` | thicker than the normal border, chosen by eye |

  A fraction keeps the symbol inside quarter-pulse gangsa cells
  whatever the cell size. The default border width stays modest, since
  a thick border on a gangsa cell hides its fill.
- **Symbol and note label together**: when a group has both (a symbol
  and a `:note-label` other than `none`), both are drawn, in the middle of the cell,
  even if they overlap. Choosing a combination that reads well is the
  writer's responsibility; the engine doesn't move or hide either.
- **Unisons are drawn once** on `notes` and `compact` rows, as now
  (04): under the first part that plays the note, with that part's
  symbol and border. (On `parts` rows each part has its own row, so a
  unison shows in both, each with its own marks.) The other parts'
  marks are not shown for that note. So in norot each figure's opening
  unison looks like polos alone; the manual says so.

## Left to choose by eye

- The default `:symbol-size` and `:border-width`, drawing the `kotekan`
  score of Jaya Semara with a few values.

## Consequences

- Nothing changes for existing scores: marks are drawn only when a
  group asks for them, so no golden file changes until an example uses
  `:part-marker`.

## Notes for promotion

- 01: `:part-marker` on a group (not on a score): its entries and
  their keys, with defaults; the note on symbols and names drawn
  together.
- 04: each voice's symbol and border; unisons drawn once, with the
  first part's marks.
- 05: the voice in the figure JSON gets fields for its symbol, symbol
  size and colour, and border colour and width: contract version 4, shared
  across the iteration (see the iteration README)
  (ADR 0006). The template draws the symbol and the border.
- 03: reading the option: `:part-marker` on a score, a part not in the
  group, an unknown key or symbol, a colour not in `"#rrggbb"` form, a
  size outside 0 to 1, or a width that isn't a length are errors.
- A new ADR: parts in one group are told apart by symbol and border,
  not colour, and only when asked; unisons drawn once. It narrows ADR
  0017, which says parts in one group are not told apart.
- Examples: Jaya Semara's `kotekan` score uses `:part-marker`; its
  golden file changes.
- Manual: the page on groups; a figure of the kotekan with its marks;
  the note on unisons.
- 08: the Emacs mode knows the new option and the symbol names.
- Related: [collapsed rows](2026-11-25-collapsed-rows.md).
