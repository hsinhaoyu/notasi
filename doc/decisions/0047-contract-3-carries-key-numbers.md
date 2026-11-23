# 0047 Contract version 3 carries key numbers and empty row labels

Status: accepted (2026-11-24)

Context: A score can show a column of key numbers to the left of the row labels (`:key-numbers`, pitched keys only) and can leave the row labels out (`:row-labels no`). ADR 0043's version 3 has no place for the numbers or for a column that is left out, and ADR 0005 has layout decide while the template draws. Version 3 is not built yet.

Decision: Version 3 also has, for each group, `key_numbers`: one string per lane, the lane's key number on its instrument counted from 1, or `null` when the group shows none. `sizes` gets `key_width`, the width of the key-number column: `"0.0em"` when no group shows key numbers. A group that leaves its row labels out has `""` for each lane in `lanes`; when no group shows row labels, `lane_width` is `"0.0em"`, so the column takes no space. Columns are, left to right: group label, key numbers, row labels, grid. ADR 0043 stands; this adds to it.

Consequences: The template draws one more column, and the figure's version stays 3, since version 3 isn't released. Golden files gain `key_width` and `key_numbers` (`null` in every score that doesn't ask for numbers).
