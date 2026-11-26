# 0055 Compact rows replace `:rows single`, adding a row where keys sound together

Status: accepted (2026-11-26)

Context: With `:rows notes`, a group has one row per key or stroke it plays, which spends a lot of height on an instrument playing one note at a time: Jaya Semara's jublag takes four rows, its gong and kempli four, though at most two strokes sound together. `:rows single` merges a group's parts into one row, but fails (`notes-collide`) wherever two notes fall in one cell, so it can't draw the gong and kempli.

Decision: `:rows` has three values, `notes`, `parts` and `compact`. `compact` replaces `single`: the group's parts merged into one line, as `single` draws them, with a row added where different keys sound together instead of an error. Two notes sound together when their boxes, as drawn, would overlap (a held note for its length, a stroke for its one column, ADR 0042). Rows are assigned by key: each key or stroke keeps one row for the whole score, filled in the order of the group's keys, each key going to the first row where it never sounds with a key already there. A chord is one note; a unison is drawn once. Compact rows have no labels. `single` becomes an unknown value, with no migration.

Consequences: The gong and kempli take two rows, G, P and T on one and K on the other, every time, so the kempli can be followed by eye. Rows by key can need more rows than the most notes sounding at once, which is accepted as rare. Pitches an octave apart share a colour (ADR 0056), so on compact rows only a note label tells them apart. `notes-collide` keeps only its `notes`-rows case. The JSON needs nothing new: a group's rows and an event's row describe any number of rows.
