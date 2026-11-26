# 0043 The JSON contract is version 3

Status: superseded by 0059

Context: Iteration 3 labels the cycle row as well as the pulse row (ADR 0039), lets a score or group choose its background lines (ADR 0041), and numbers the pickup as cycle 0. Version 2 (ADR 0036) has one header label, says nothing about which lines a group draws, and gives the pickup no cycle mark. ADR 0005 has layout decide and the template draw, so these choices belong in the figure, not in the template.

Decision: The figure becomes version 3. The header's `label` becomes `cycle_label` and `pulse_label`, each a string or `null` (no label, or its row not shown). The header gets `pulse_lines`, and each group gets `pulse_lines` and `row_lines`, booleans from the score's or group's `background`: the template draws pulse lines only where they are true, and the lines between a group's rows only where `row_lines` is. The system's `lines` are unchanged; cycle lines and the lines between groups are always drawn. A system that starts in the pickup, or with it, has a cycle mark `0` at the pickup's first column it shows. Everything else in ADR 0036 stands: per-system headers and lines, overlays, subtitle and caption, the sizes, `lanes` as row labels, and a template that only draws what the figure says.

Consequences: The template, the golden files and the JSON writer's callers change together, in one PR (05). Every golden file changes anyway, since the labels have defaults.

Supersedes: 0036
