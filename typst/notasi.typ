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

// Defaults for a part's marks (ADR 0056), chosen by eye: a symbol a
// fraction of the cell's narrower side, and a border thicker than the
// grey one but thin enough not to hide a small note's colour.
#let _default-symbol-size = 0.3
#let _default-symbol-color = "#222222"
#let _default-border-width = "1.5pt"

// A value of a voice's marker, or DEFAULT when the marker leaves it out.
#let _mark(marker, key, default) = {
  let v = marker.at(key, default: none)
  if v == none { default } else { v }
}

// The marker's symbol, centred in the cell and sized from it.
#let _symbol(marker) = layout(size => {
  let kind = marker.at("symbol", default: "none")
  let d = calc.min(size.width, size.height) * _mark(marker, "symbol_size", _default-symbol-size)
  let c = rgb(_mark(marker, "symbol_color", _default-symbol-color))
  let w = calc.max(d * 0.18, 0.4pt)
  let shape = if kind == "dot" {
    circle(radius: d / 2, fill: c)
  } else if kind == "ring" {
    circle(radius: d / 2 - w / 2, stroke: w + c)
  } else if kind == "cross" {
    box(width: d, height: d, {
      place(line(start: (0pt, 0pt), end: (d, d), stroke: w + c))
      place(line(start: (0pt, d), end: (d, 0pt), stroke: w + c))
    })
  }
  if shape != none { shape }
})

// The content of one note's cell: a block filling the cell in the
// note's colour, with its name when the figure gives one (ADR 0019,
// 0020). A note with no colour is just its name. A voice's MARKER (or
// none) adds its symbol and its border (ADR 0056), on every piece of a
// cut note; a "-" of a held note gets neither.
#let _note(e, marker) = {
  let name = if e.text != none and not e.continued {
    align(center + horizon,
      text(fill: rgb(e.text_color), e.text))
  }
  let dash = e.fill == none and e.text == "-"
  // The symbol takes no room, so the label stays centred with it.
  let symbol = if marker != none and not dash {
    place(center + horizon, _symbol(marker))
  }
  let border = if marker != none { marker.at("border", default: none) }
  if e.fill == none {
    if symbol == none { name } else {
      block(width: 100%, height: 100%, { symbol; name })
    }
  } else {
    // A thin grey border, the same on every edge (ADR 0041): centred on
    // the block's edge, so two touching notes share one line. It keeps
    // repeated strokes apart and outlines a note against the paper. A
    // marked part's border takes its place.
    let stroke = if border != none {
      _len(_mark(marker, "border_width", _default-border-width)) + rgb(border)
    } else {
      0.5pt + luma(150)
    }
    block(width: 100%, height: 100%, fill: rgb(e.fill), stroke: stroke,
      if symbol == none { name } else { symbol; name })
  }
}

// One item of an annotation row (ADR 0057): its text on one line,
// near-black, aligned as the item says when it fits its span, otherwise
// left-aligned and cut at the span's end.
#let _annotation-item(it) = layout(size => {
  let t = text(fill: rgb("#222222"), size: 0.9em, it.text)
  let w = measure(t).width
  let pad = 2pt
  let fits = w + 2 * pad <= size.width
  let where = if not fits { left }
    else if it.align == "center" { center }
    else if it.align == "right" { right }
    else { left }
  block(width: size.width, height: size.height, clip: true,
    inset: (x: pad), align(where + horizon, box(width: w, t)))
})

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
  // Columns: 0 group label, 1 key numbers, 2 row labels, then the grid
  // (ADR 0047).
  let first = 3
  let header = sys.header

  let cells = ()
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
      cells.push(grid.cell(x: 0, y: row, colspan: 3,
        align: left + horizon, text(header.cycle_label)))
    }
    for m in header.cycles {
      cells.push(grid.cell(x: first + m.column, y: row,
        colspan: span(m.column), align: center + horizon,
        text(m.text)))
    }
    row-lines.push((pulse: header-pulses, under: false))
    row += 1
  }
  if header.pulses != none {
    if header.pulse_label != none {
      cells.push(grid.cell(x: 0, y: row, colspan: 3,
        align: left + horizon, text(header.pulse_label)))
    }
    for (i, p) in header.pulses.enumerate() {
      if p != none {
        cells.push(grid.cell(x: first + i, y: row, colspan: span(i),
          align: center + horizon, text(p)))
      }
    }
    row-lines.push((pulse: header-pulses, under: false))
    row += 1
  }
  let first-group-row = row

  for g in sys.groups {
    let rows = g.rows
    // The annotation row (ADR 0057): one more row, above or below the
    // group's rows, inside its rules and frame.
    let ann = g.at("annotation", default: none)
    let ann-row = if ann == none { none }
      else if ann.position == "above" { row } else { row + rows.len() }
    let first-row = if ann != none and ann.position == "above" { row + 1 } else { row }
    let height = rows.len() + if ann == none { 0 } else { 1 }
    cells.push(grid.hline(y: row, stroke: 0.8pt + luma(120)))
    if height > 0 {
      cells.push(grid.cell(x: 0, y: row, rowspan: height,
        align: horizon + left, inset: (right: 10pt), {
          text(size: 1.1em, g.label)
          if g.subtitle != none {
            // A one-row group has no room for a second line: the
            // subtitle follows the label on the same line.
            if height > 1 { linebreak() } else { h(0.5em) }
            text(fill: luma(110), style: "italic", g.subtitle)
          }
        }))
    }
    if rows.len() > 0 {
      for (i, l) in rows.enumerate() {
        cells.push(grid.cell(x: 2, y: first-row + i, align: horizon + right,
          inset: (right: 5pt), text(fill: luma(140), size: 0.85em, l)))
      }
      // Key numbers, to the left of the row labels, lighter (ADR 0047).
      let numbers = g.at("key_numbers", default: none)
      if numbers != none {
        for (i, n) in numbers.enumerate() {
          cells.push(grid.cell(x: 1, y: first-row + i, align: horizon + right,
            inset: (right: 3pt), text(fill: luma(170), size: 0.85em, n)))
        }
      }
      for v in g.voices {
        let marker = v.at("marker", default: none)
        for e in v.events {
          cells.push(grid.cell(x: first + e.start, y: first-row + e.row,
            colspan: e.dur, inset: 0pt, _note(e, marker)))
        }
      }
    }
    if ann != none {
      if ann.label != none {
        cells.push(grid.cell(x: 2, y: ann-row, align: horizon + right,
          inset: (right: 5pt), text(fill: luma(140), size: 0.85em, ann.label)))
      }
      for it in ann.items {
        cells.push(grid.cell(x: first + it.start, y: ann-row, colspan: it.dur,
          inset: 0pt, _annotation-item(it)))
      }
      // A light line between the annotation row and the group's rows,
      // across the grid, as a row line is drawn.
      if rows.len() > 0 {
        let between = if ann.position == "above" { ann-row + 1 } else { ann-row }
        cells.push(grid.hline(y: between, start: first,
          stroke: 0.5pt + luma(170)))
      }
    }
    let pulses = g.at("pulse_lines", default: true)
    let rules = g.at("row_lines", default: false)
    // The annotation row has cycle lines only; the line between it and
    // the group's rows is drawn with its cells.
    if ann != none and ann.position == "above" {
      row-lines.push((pulse: false, under: false))
    }
    for i in range(rows.len()) {
      row-lines.push((pulse: pulses, under: rules and i < rows.len() - 1))
    }
    if ann != none and ann.position == "below" {
      row-lines.push((pulse: false, under: false))
    }
    row += height
  }
  cells.push(grid.hline(y: row, stroke: 0.8pt + luma(120)))
  // The frame between the row labels and the grid, beside the groups
  // (ADR 0044).
  if row > first-group-row {
    cells.push(grid.vline(x: first, start: first-group-row, end: row,
      stroke: 0.8pt + luma(120)))
  }
  let rows-count = calc.max(row, 1)

  let cols = ((_len(sizes.label_width),
               _len(sizes.at("key_width", default: "0em")),
               _len(sizes.row_label_width))
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
      // The last pulse is closed on its right, as each pulse is on its
      // left, wherever the row has pulse lines.
      let right = if x == cols.len() - 1 and info.pulse {
        (right: 0.5pt + luma(170))
      }
      let parts = (left, under, right).filter(p => p != none)
      if parts.len() > 0 { parts.sum() }
    },
    ..range(cols.len() * rows-count).map(_ => []))

  let foreground = grid(columns: cols, rows: rows, ..cells)

  box({
    background
    place(top + left, foreground)
  })
}

/// Draw DATA, the figure laid out by notasi: its systems stacked, 1em
/// apart. Returns content; title, subtitle, caption and numbering are
/// the caller's.
#let score(data) = {
  data.systems.map(sys => _system(data, sys)).join(v(1em))
}
