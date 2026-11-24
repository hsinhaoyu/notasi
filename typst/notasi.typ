// notasi: draw a figure laid out by notasi's Guile side.
// See doc/design/05-typst-backend.md, "Typst template design".
//
//   #import "notasi.typ": score
//   #score(json("piece.json"))
//
// The template draws exactly what the figure says and makes no musical
// decisions (ADR 0005). It sets no page, font or text size, so a
// score takes on the look of the document around it.

// A length from the figure, e.g. "10.5em" or "4mm".
#let _len(s) = eval(s)

// The content of one note's cell: a block filling the cell in the
// note's colour, with its name when the figure gives one (ADR 0019,
// 0020). A note with no colour is just its name.
#let _note(e) = {
  let name = if e.text != none and not e.continued {
    align(center + horizon,
      text(fill: rgb(e.text_color), weight: "bold", e.text))
  }
  if e.fill == none {
    name
  } else {
    // A thin grey border, the same on every edge (ADR 0041): centred on
    // the block's edge, so two touching notes share one line. It keeps
    // repeated strokes apart and outlines a note against the paper.
    block(width: 100%, height: 100%, fill: rgb(e.fill),
      stroke: 0.5pt + luma(150), name)
  }
}

// The line at the left of a column, as the figure's `lines' says
// (ADR 0037): thin at a pulse, heavier at the start of a gong cycle.
#let _line(kind) = if kind == "cycle" {
  (left: 1pt + luma(90))
} else if kind == "pulse" {
  (left: 0.5pt + luma(170))
}

// One system as a grid: a background layer for the lines, and a
// transparent foreground layer for labels, header rows and notes, drawn
// on top. A single grid can't do both: a note spanning several columns
// would cover the lines under it. The template does no counting: every
// number and line comes from the figure (ADRs 0036, 0043).
#let _system(data, sys) = {
  let sizes = data.sizes
  let first = 2                     // column 0: group label, 1: lane label
  let header = sys.header

  let cells = ()
  let overlays = ()
  let row = 0
  // For each grid row: whether pulse lines cross it, and whether a row
  // line runs under it (ADRs 0041, 0043). A figure without the flags
  // draws pulse lines and no row lines.
  let header-pulses = header.at("pulse_lines", default: true)
  let row-lines = ()
  // A number is centred over its pulse: it spans steps_per_pulse
  // columns from its column, or what is left of the system (ADR 0044).
  let k = data.steps_per_pulse
  let span(column) = calc.min(k, sys.steps - column)
  if header.cycles != none {
    if header.cycle_label != none {
      cells.push(grid.cell(x: 0, y: row, colspan: 2,
        align: left + horizon, text(weight: "bold", header.cycle_label)))
    }
    for m in header.cycles {
      cells.push(grid.cell(x: first + m.column, y: row,
        colspan: span(m.column), align: center + horizon,
        text(weight: "bold", m.text)))
    }
    row-lines.push((pulse: header-pulses, under: false))
    row += 1
  }
  if header.pulses != none {
    if header.pulse_label != none {
      cells.push(grid.cell(x: 0, y: row, colspan: 2,
        align: left + horizon, text(weight: "bold", header.pulse_label)))
    }
    for (i, p) in header.pulses.enumerate() {
      if p != none {
        cells.push(grid.cell(x: first + i, y: row, colspan: span(i),
          align: center + horizon, text(weight: "bold", p)))
      }
    }
    row-lines.push((pulse: header-pulses, under: false))
    row += 1
  }
  let first-group-row = row

  for g in sys.groups {
    let lanes = g.lanes
    cells.push(grid.hline(y: row, stroke: 0.8pt + luma(120)))
    if lanes.len() > 0 {
      cells.push(grid.cell(x: 0, y: row, rowspan: lanes.len(),
        align: horizon + left, inset: (right: 10pt), {
          text(weight: "bold", size: 1.1em, g.label)
          if g.subtitle != none {
            // A one-row group has no room for a second line: the
            // subtitle follows the label on the same line.
            if lanes.len() > 1 { linebreak() } else { h(0.5em) }
            text(fill: luma(110), style: "italic", g.subtitle)
          }
        }))
      for (i, l) in lanes.enumerate() {
        cells.push(grid.cell(x: 1, y: row + i, align: horizon + right,
          inset: (right: 5pt), text(fill: luma(140), size: 0.85em, l)))
      }
      for v in g.voices {
        for e in v.events {
          cells.push(grid.cell(x: first + e.start, y: row + e.lane,
            colspan: e.dur, inset: 0pt, _note(e)))
        }
      }
      // Pattern names, written over the notes (ADR 0036); a continued
      // piece shows its name again.
      for o in g.overlays {
        overlays.push(grid.cell(x: first + o.start, y: row + o.row,
          colspan: o.dur, rowspan: o.rows, align: center + horizon,
          box(fill: white.transparentize(20%), inset: (x: 3pt, y: 2pt),
            radius: 0pt, text(fill: rgb("#222222"), o.text))))
      }
    }
    let pulses = g.at("pulse_lines", default: true)
    let rules = g.at("row_lines", default: false)
    for i in range(lanes.len()) {
      row-lines.push((pulse: pulses, under: rules and i < lanes.len() - 1))
    }
    row += lanes.len()
  }
  cells.push(grid.hline(y: row, stroke: 0.8pt + luma(120)))
  // The frame between the lane labels and the grid, beside the groups
  // (ADR 0044).
  if row > first-group-row {
    cells.push(grid.vline(x: first, start: first-group-row, end: row,
      stroke: 0.8pt + luma(120)))
  }
  let rows-count = calc.max(row, 1)

  let cols = ((_len(sizes.label_width), _len(sizes.lane_width))
    + (_len(sizes.cell_width),) * sys.steps)
  let rows = (_len(sizes.cell_height),) * rows-count

  let background = grid(columns: cols, rows: rows,
    stroke: (x, y) => {
      let info = row-lines.at(y, default: (pulse: true, under: false))
      let left = if x >= first {
        let kind = sys.lines.at(x - first)
        // Cycle lines always; pulse lines where the row has them.
        if kind == "cycle" or info.pulse { _line(kind) }
      }
      let under = if x >= first and info.under {
        (bottom: 0.5pt + luma(170))
      }
      if left == none { under } else if under == none { left }
      else { left + under }
    },
    ..range(cols.len() * rows-count).map(_ => []))

  let foreground = grid(columns: cols, rows: rows, ..cells)
  // A layer of its own: its cells would overlap the notes' in one grid.
  let names = grid(columns: cols, rows: rows, ..overlays)

  box({
    place(top + left, background)
    place(top + left, foreground)
    names
  })
}

/// Draw DATA, the figure laid out by notasi: its systems stacked, 1em
/// apart. Returns content; title, subtitle, caption and numbering are
/// the caller's.
#let score(data) = {
  data.systems.map(sys => _system(data, sys)).join(v(1em))
}
