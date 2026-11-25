# Design idea: bapang in two lengths, and what a colotomy is

Status: agreed in discussion (2026-11-24, open questions settled
2026-11-25).
Not the design until promoted.

## The problem

ADR 0046 put `bapang` in the `gong-kebyar` template as a 16-pulse
cycle (kempur on 4 and 12, klentong on 8, gong on 16), "the meter of
Gold's Jaya Semara". Checking the sources on 2026-11-24 showed that
this is only half right:

- **Gold's basic bapang is 8 beats.** Figure 5.11 (p. 110): kempur on
  2 and 6, klentong on 4, gong on 8; on p. 112 she calls it "this
  eight-beat cycle" (CD track 32). Our reference note already has this
  row, but the template doesn't follow it.
- **Bapang also comes in longer forms.** Gold notes that some meters
  in figure 5.11 have elongated, twice-as-long versions, sometimes
  called *longgor* (p. 111). Her listening guides name a
  "sixteen-beat, elongated bapang" and a "thirty-two-beat, elongated
  bapang" in "Jagra Parwata" (p. 142), both pur, tong, pur, gong.
- **Jaya Semara's pangecet is the 16-beat form.** Gold names the meter
  "bapang colotomic meter: pur, tong, pur, gong" (figure 6.6, p. 140),
  and on p. 58 (activity 3.2) marks the strokes over the Jaya Semara
  parts: kempur over beats 4 and 12, klentong over 8, gong over 16,
  with the kempli on every beat. So our 16-pulse pattern is right for
  the piece; calling it simply `bapang` is not.
- **Other sources agree that bapang has more than one length.**
  McGraw's glossary of Balinese music: "An 8 or 16 beat cycle
  typically outlined by the gong structure (G).P.t.P". The glossary of
  the Arbiter release *Dancers of Bali* (drawing on Tenzer 2000):
  "8 or 16 beats per gong (or kempur)", phrased (G).P.t.P.G.
- **The gong strokes alone don't name a meter.** In Gold's figure 5.11,
  gegaboran (16 beats: kempur on 4 and 12, klentong on 8, gong on 16)
  has exactly the strokes of the 16-beat bapang. Meters also go with
  drum patterns, moods, genres and tempi (Gold, p. 42).
- **Beat counts depend on what a source counts.** Gold counts kempli
  beats. Another study of kebyar drumming gives bapang as 4 or 8 beats
  and gegaboran as 8, half of Gold's numbers, probably counting a
  slower pulse. A number of beats means little without saying whose
  count it is.

Smaller faults found on the way:

- `examples/jaya-semara.nts` cites activity 2.4 (p. 43) for the gong
  pattern. Activity 2.4 is a generic 16-beat demonstration and does
  not name Jaya Semara. The pattern over the Jaya Semara parts is on
  p. 58 (activity 3.2), with p. 57 (activity 3.1: "two repetitions to
  cover one sixteen-beat gong cycle") and p. 140 (the name).
- The manual's gong-cycles page says the template's `bapang` is
  sixteen pulses, and the template comment, 01-notation, ADR 0046 and
  `tests/syntax.scm` say the same.

## Agreed (2026-11-24)

- **No general doubling.** notasi gets no operation that stretches a
  colotomy (no `:longgor`, no scaling). Each length of a meter is
  written out as its own colotomy.
- **The template has bapang in its 8-pulse form and its 16-pulse
  form**, both in `gong-kebyar`, beside `gilak`:
  - 8 pulses: kempur on 2 and 6, klentong on 4, gong on 8 (Gold,
    figure 5.11, p. 110);
  - 16 pulses: kempur on 4 and 12, klentong on 8, gong on 16 (Gold,
    p. 58 for Jaya Semara; p. 142 for the elongated bapang).
- **Jaya Semara uses the 16-pulse form.** Its music and drawings don't
  change; only the colotomy's name and the citations do.
- **The documentation describes colotomies correctly** (next section).

## What the documentation should say about colotomies

Everywhere notasi explains the word (the manual's gong-cycles page,
the glossaries in 01-notation and `doc/design/README.md`, the
template's comments):

1. **Where the word comes from.** "Colotomic" is a word from Western
   writing about gamelan, for the way gongs mark off time. Gold says
   there is no single Balinese term; each meter has its own name, such
   as gilak or bapang (p. 42). `colotomy` is notasi's name for one
   named colotomic meter: a length in pulses and the gong parts that
   mark it. Say that it is our word, so a reader doesn't look for it in
   Balinese.
2. **A meter is its gongs' order and spacing, not a fixed length.** The
   same named meter can be played at more than one length (bapang at 8
   and 16 pulses, and 32 in Gold's "Jagra Parwata"). notasi writes each
   length as its own colotomy.
3. **The gongs don't tell meters apart on their own.** Two meters can
   share the same strokes (16-pulse bapang and Gold's gegaboran); they
   differ in drumming, mood and genre, which a `colotomy` doesn't
   record. A colotomy's name is the writer's label for the meter.
4. **Say whose count a number is.** Pulses in notasi are kempli strokes
   (ADR 0009, Gold's "beats"). When the documentation gives a meter's
   length from a source, it says the source counts kempli beats, and
   cites the page.
5. **Examples are checked against a source and cited.** Each colotomy
   the documentation shows gives its source and page:
   - `gilak`: Gold, figure 5.11 (p. 110) and Tenzer's Baris;
   - 8-pulse bapang: Gold, figure 5.11 (p. 110), activity 5.3;
   - 16-pulse bapang: Gold, p. 58 (Jaya Semara), p. 142;
   - Jaya Semara's pangecet as the 16-pulse bapang, not "bapang".
   An example made up to teach the syntax says that it is made up (see
   open question 3).

## Open

1. *(Settled 2026-11-25: `bapang-8` and `bapang-16`.)* Names. Both
   say their length; plain `bapang` no longer exists, so a file that
   writes `:colotomy bapang` gets an unknown-colotomy error instead of
   silently changing length (no migration, as for other removed names).
2. *(Settled 2026-11-25: not now.)* The 32-pulse form. Added as
   `bapang-32` when a piece needs it, as ADR 0046 says; until then a
   writer defines it in their own file.
3. *(Settled 2026-11-25: removed.)* The manual's `gilak-kempur`.
   `doc/manual/src/examples/own-colotomy.nts` ("Gilak, another way"),
   which has no source, is removed with its figure; the section that
   used it gets a real example instead (question 6).
4. *(Settled 2026-11-25: added.)* Gegaboran. The template gets
   `gegaboran`, 16 pulses, with the same strokes as `bapang-16`
   (kempur on 4 and 12, klentong on 8, gong on 16; Gold, figure 5.11,
   p. 110), so a writer can name the meter they mean. No example uses
   it, so this is an exception to ADR 0046's rule that the template
   holds only colotomies an example uses; the ADR for this idea says
   so. Its comment says the strokes are bapang-16's and that the meters
   differ in drumming, mood and genre.
5. *(Settled 2026-11-25: none.)* An 8-pulse bapang example. The
   template test is enough.
6. *(Settled 2026-11-25: a real cycle, written by hand.)* The manual's
   section "A cycle of your own" keeps its place, with a new example in
   place of `own-colotomy.nts`: the 32-pulse bapang of Gold's "Jagra
   Parwata" (p. 142), pur, tong, pur, gong, written as a `colotomy`
   (say `bapang-32`) in the example file, with its source in a comment.
   It is a cycle the template doesn't have (question 2), which is what
   the section is about. The stroke positions are to be checked against
   Gold p. 142 before it is written (presumably kempur on 8 and 24,
   klentong on 16, gong on 32, by analogy with the shorter forms).

## Later changes (2026-11-25)

- [The collection of examples](2026-11-25-examples-collection.md) is
  promoted first and moves `examples/jaya-semara.nts` to
  `examples/gallery/jaya-semara.nts`; the notes below mean that path.
- Terms follow the [glossary](2026-11-25-glossary.md): pitch name, not
  degree.

## Notes for promotion

- A new ADR, partly superseding 0046: the template has `bapang-8`,
  `bapang-16` and `gegaboran` (no plain `bapang`), there is no general
  doubling, and gegaboran is an exception to 0046's rule that the
  template holds only colotomies an example uses.
- 01-notation: the Concepts table (`colotomy`), the template paragraph
  after the instrument ranges, the `colotomy` section, and the Jaya
  Semara example's `:colotomy`.
- `doc/design/README.md`: the glossary (`colotomy`, `colotomic`).
- `templates/gong-kebyar.nts`: `bapang-8`, `bapang-16` and
  `gegaboran`, with sources in the comments.
- `examples/jaya-semara.nts`: `:colotomy` names the 16-pulse form; the
  sources list cites p. 58 (and pp. 57, 140) for the gongs instead of
  activity 2.4.
- Manual: `gong-cycles.md` (the template's colotomies, what a colotomy
  is, points 1–4 above), `templates.md` (the list of gong cycles);
  `own-colotomy.nts` removed and replaced by the 32-pulse bapang
  example (questions 3 and 6), with its figure.
- Tests: `tests/syntax.scm`, "[template] bapang", checks 16 pulses
  today; it gets one group per form, and one for `gegaboran`. Golden files don't change: Jaya
  Semara's gongs are the same.
- `doc/references/2026-11-21-reference-gold-2005.md`: add the elongated
  forms (pp. 111, 142), Jaya Semara's meter (pp. 58, 140), and the
  warning that gegaboran and 16-beat bapang share their strokes.

## Sources

- Lisa Gold, *Music in Bali* (2005): pp. 42, 43, 57, 58, 110–112, 140,
  142.
- Andrew McGraw, "Glossary of Frequently Used Terms in Balinese Music",
  entry *bapang*:
  https://swarasanti.nl/upload/doc/Glossary%20Balinese%20Music.pdf
- Glossary to *Dancers of Bali: Gamelan of Peliatan, 1952* (Arbiter
  Records), entries *bapang*, *longgor*:
  https://arbiterrecords.org/wp-content/uploads/2009/09/Glossary-.pdf
