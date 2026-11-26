# 0059 The JSON contract is version 4: rows, the annotation row and part markers

Status: accepted (2026-11-26)

Context: Iteration 5 changes what the figure must carry. Pattern names over the notes (`overlays`) are removed (ADR 0057), and a group can have an annotation row instead. A part's notes can carry marks (ADR 0056). The glossary (ADR 0051) calls a group's horizontal lines rows, not lanes, and version 3 (ADRs 0043, 0047) names them `lanes`, `lane` and `lane_width`. Version 3 is released, so these changes need a new version (ADR 0006).

Decision: The figure becomes version 4.
- The group's `lanes` becomes `rows`, the event's `lane` becomes `row`, and `sizes.lane_width` becomes `row_label_width`. Their meanings don't change.
- Each group's `overlays` is removed. In its place the group has `annotation`: `null`, or its annotation row, with `position` (`"above"` or `"below"`), `label` (a string, or `null` for none) and `items`. Each item has `start`, `dur`, `text`, `align` (`"left"`, `"center"` or `"right"`) and `continued`, in the system's columns. Layout decides each item's span and text. The template aligns the text in its span when it fits, and otherwise left-aligns it and cuts it at the span's end.
- Each voice gets `marker`: `null`, or its part's marks, with `symbol` (`"none"`, `"dot"`, `"ring"` or `"cross"`), `symbol_size` (a fraction of the cell's narrower side), `symbol_color`, `border` (`"#rrggbb"`) and `border_width` (a length). Each field except `symbol` may be `null`, meaning the template's default.

Everything else in ADRs 0043 and 0047 stands: the header and its labels, the lines, the cycle mark for the pickup, `pulse_lines` and `row_lines`, `key_numbers` and `key_width`, the columns' order, subtitle and caption, the sizes, and a template that only draws what the figure says. Version 4 is built over iteration 5: each milestone that changes the figure adds its part, and the version is fixed when the iteration is released.

Consequences: Every golden file changes, since every group loses `overlays` and gains `annotation`, and every voice gains `marker`. The template, `(notasi layout)`, the golden files and the Emacs mode's tests change together. The template draws the annotation row, the cycle lines through it but not the pulse lines, and the marks.

Supersedes: 0043, 0047
