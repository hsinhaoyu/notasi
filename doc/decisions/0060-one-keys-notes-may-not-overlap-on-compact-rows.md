# 0060 One key's notes may not overlap on compact rows

Status: accepted (2026-11-26)

Context: Compact rows (ADR 0055) give each key one row for the whole score, adding a row where different keys sound together. Two parts can also strike the same key at overlapping times without a unison, with different starts: one part holds `o2` while the other strikes it. Their boxes would then be drawn over each other in the key's row. ADR 0055's Consequences say `notes-collide` keeps only its `notes`-rows case, which would allow this.

Decision: On compact rows, as on `notes` rows, two notes on one key may share columns only as a unison (the same key, start and length), which is drawn once. Any other overlap is `notes-collide`. Overlaps of different keys still add a row. A box is never drawn over another.

Consequences: `notes-collide` keeps its case of one key, on `notes` and `compact` rows, not on `notes` rows alone; ADR 0055's sentence saying otherwise doesn't hold. Nothing else in ADR 0055 changes, so it isn't superseded. The reader checks compact groups as it checks `notes` groups.
