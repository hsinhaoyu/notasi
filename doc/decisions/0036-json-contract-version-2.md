# 0036 The JSON contract is version 2

Status: superseded by 0043

Context: Version 1 of the figure (05) has no place for what scores print: cycle numbers, pulse numbers in Tenzer's numbering, a pulse label, lines at cycle boundaries, pattern names over the notes, subtitles, captions, font and cell sizes, and rows per part. The template also computes pulse numbers itself, which breaks with pickups and cycles.

Decision: The figure becomes version 2. Layout writes, for each system, a `header` (the cycle marks, a pulse number or `null` for every column, and the pulse label) and a `lines` entry for every column (`none`, `pulse` or `cycle`); each group gets `overlays` (pattern names, with their columns and rows); the figure gets `subtitle` and `caption`; `sizes` gets `font_size`, `cell_width` and `cell_height`, replacing `step_width` and `row_height`. `lanes` holds the row labels, whatever the rows are. `steps_per_pulse` is the columns per pulse of the step layout chose. The template draws only what the figure says, and does no counting (ADR 0005).

Consequences: The template, the golden files and the JSON writer's callers change together, in one PR (05). Golden files become one per example and score. ADR 0006 stands: the figure is still the contract, and its `version` says which one.
