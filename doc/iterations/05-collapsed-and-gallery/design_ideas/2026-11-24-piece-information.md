# Design idea: information about a piece

Status: agreed in discussion (2026-11-24, settled 2026-11-25), except
open question 11. Not the design until promoted.

## The idea

A piece can optionally say who made it and where it comes from:

| Field | Meaning |
|---|---|
| composer | Who composed the music |
| composition year | When it was composed |
| transcriber | Who wrote it down in notasi (or in the source notasi follows) |
| transcription year | When it was transcribed |
| source | Where the transcription comes from: a book, a recording, a teacher |
| contributor | Who contributed the file (to an examples collection, say) |
| contribution year | When it was contributed |
| performer | Who plays the music the transcription follows: a group or a musician (e.g. Sanggar Çudamani on Gold's CD) |
| notes | Free text about the piece: its history, what is left out, anything else |

All are optional. A piece without them reads and draws as now.

Our examples already carry this information, but only in comments,
where notasi can't use it. For `examples/jaya-semara.nts`:

```scheme
(piece "Jaya Semara: pangecet" :colotomy bapang :pickup 1
  :composer "I Wayan Beratha" :composition-year "1964"
  :source "Lisa Gold, Music in Bali (2005), figure 3.1 and activities 3.1-3.2"
  :performer "Sanggar Çudamani"
  :notes "Based on Kapi Raja (1930s). The lead-in before the gong, the
          reyong and the nyog-cag kotekan are not notated.")
```

## Agreed (2026-11-24)

- The nine fields above, all optional.
- **Every value is a string, and notasi doesn't check its form.** A
  year is `"1964"`, `"1930s"` or `"c. 1964"` alike; two people are
  written however the writer likes (`"A and B"`); "traditional" or
  "unknown" is a string like any other. notasi only checks that the
  value is a string, and keeps it as written.
- They describe the piece, so they belong to the piece (02), not to a
  score.
- **They are keys on the `piece` form**, beside `:colotomy` and
  `:pickup`, as in the example above; there is no new form. The keys
  are written with hyphens, like every key in notasi:
  `:composer`, `:composition-year`, `:transcriber`,
  `:transcription-year`, `:source`, `:contributor`,
  `:contribution-year`, `:performer`, and the notes key (its name is
  open question 11).

## Open

1. *(Settled: keys on `piece`.)* Where they are written.
2. *(Settled: one string per key.)* More than one person.
3. *(Settled: a string.)* Years that aren't exact.
4. *(Settled: a string.)* Missing and traditional composers.
5. *(Settled 2026-11-25: not now.)* Other roles. `:arranger` is added
   when a piece needs it.
6. *(Settled 2026-11-25.)* What "contributor" means: the person who
   added the file to `examples/contrib/` ([the collection of
   examples](2026-11-25-examples-collection.md)). Contributions are
   credited with `:contributor`, `:source` and `:transcriber`, by
   convention.
7. *(Settled 2026-11-25: never printed.)* Printing. The information is
   data only: in the `.nts`, and in the saved piece ([saving the
   piece](2026-11-24-saving-the-piece.md)). No score option draws it,
   and the figure JSON doesn't change.
8. *(Settled 2026-11-25: not now.)* Templates keep their sources in
   comments.
9. *(Settled 2026-11-25: kept as written.)* Long notes: the string is
   kept exactly as written, line breaks and indentation included. It is
   never printed (question 7).
10. *(Settled 2026-11-25: in the string.)* Performer and year:
    `:performer "Sanggar Çudamani, 2005"`; a `:performance-year` key
    only if a piece needs it apart.
11. *(Settled 2026-11-26: `:remarks`.)* The key's name. `:annotation` is now a
    pattern's text, so it is not available here. In notasi a note is a musical note; ADR 0024
    renamed iterations' `notes/` folder for that reason. `:notes "..."`
    on a piece could be read as music. Options: `:notes`, `:remarks`,
    `:comment`, `:about`. Leaning: `:remarks`, keeping "notes" as the
    field's name in prose only if it reads clearly.

## Notes for promotion

- 01: the new keys in the `piece` form's table, their values (strings),
  and the printing option if any.
- 02: the piece record gets the fields (or one `info` field holding
  them).
- 03: reading them. The only check is that each value is a string
  (`bad-option` otherwise, as for other options); an unknown key is
  `bad-option` as now.
- 04/05: nothing; the information is never printed (open question 7).
- The examples move what their comments say into the fields.
- Saving the piece ([saving the piece](2026-11-24-saving-the-piece.md))
  includes them.
- 08: the Emacs mode's highlighting knows the new keys.
