# 0039 The cycle and pulse rows are labelled by default

Status: accepted (2026-11-23)

Context: A score prints a row of cycle numbers and a row of pulse numbers above the groups. Only the pulse row can be labelled (`:pulse-label`, with no default), and the cycle row not at all, so a reader has to guess what the `1` above `1 2 3 … 8` means.

Decision: `:cycle-label STRING` and `:pulse-label STRING`, on a score, label the two rows, with the defaults `"Cycle"` and `"Pulse"`, the words notasi uses for positions everywhere else. `""` removes a label. A label is printed only when its row is. Each has one form (no long and short labels), and both sit in the group-label column, where the pulse label is today.

Consequences: Every score with a colotomy gains two labels, so every figure and golden file changes. The figure's header carries two labels, which changes the JSON contract (04, 05). Scores in Tenzer's layout set `:pulse-label "Beats"` and, if his page has none, `:cycle-label ""`.
