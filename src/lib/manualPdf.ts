import type { GameManualDocument, ManualSection } from '../content/manual'

type PdfLine = {
  text: string
  size?: number
  bold?: boolean
  indent?: number
  gapBefore?: number
  gapAfter?: number
}

type PdfPage = PdfLine[]

const PAGE_WIDTH = 595
const PAGE_HEIGHT = 842
const LEFT = 45
const RIGHT = 45
const TOP = 52
const BOTTOM = 48
const CONTENT_WIDTH = PAGE_WIDTH - LEFT - RIGHT

function ascii(input: string) {
  return input
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201c\u201d]/g, '"')
    .replace(/[\u2013\u2014]/g, '-')
    .replace(/\u2026/g, '...')
    .replace(/\u00d7/g, 'x')
    .replace(/\u2264/g, '<=')
    .replace(/\u2265/g, '>=')
    .replace(/\u2192/g, '->')
    .replace(/\u00b7/g, '-')
    .replace(/\u20ac/g, 'EUR ')
    .replace(/[^\x20-\x7E]/g, '')
}

function escapePdfString(input: string) {
  return ascii(input)
    .replace(/\\/g, '\\\\')
    .replace(/\(/g, '\\(')
    .replace(/\)/g, '\\)')
}

function charCapacity(size: number, indent = 0) {
  const available = CONTENT_WIDTH - indent
  return Math.max(24, Math.floor(available / (size * 0.52)))
}

function wrap(text: string, size: number, indent = 0) {
  const clean = ascii(text).replace(/\s+/g, ' ').trim()
  const max = charCapacity(size, indent)
  if (!clean) return ['']

  const words = clean.split(' ')
  const lines: string[] = []
  let current = ''

  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word
    if (candidate.length <= max) {
      current = candidate
      continue
    }

    if (current) lines.push(current)

    if (word.length <= max) {
      current = word
    } else {
      let rest = word
      while (rest.length > max) {
        lines.push(rest.slice(0, max))
        rest = rest.slice(max)
      }
      current = rest
    }
  }

  if (current) lines.push(current)
  return lines
}

function addWrapped(target: PdfLine[], text: string, options: Omit<PdfLine, 'text'> = {}) {
  const size = options.size ?? 9
  const indent = options.indent ?? 0
  wrap(text, size, indent).forEach((line, index) => {
    target.push({
      text: line,
      size,
      bold: options.bold,
      indent,
      gapBefore: index === 0 ? options.gapBefore : 0,
      gapAfter: index === wrap(text, size, indent).length - 1 ? options.gapAfter : 0,
    })
  })
}

function sectionLines(section: ManualSection) {
  const lines: PdfLine[] = []
  lines.push({ text: section.title, size: 12, bold: true, gapBefore: 10, gapAfter: 4 })

  section.paragraphs?.forEach((paragraph) => {
    addWrapped(lines, paragraph, { size: 9, gapAfter: 4 })
  })

  section.bullets?.forEach((item) => {
    addWrapped(lines, `- ${item}`, { size: 9, indent: 10, gapAfter: 2 })
  })

  section.steps?.forEach((item, index) => {
    addWrapped(lines, `${index + 1}. ${item}`, { size: 9, indent: 10, gapAfter: 2 })
  })

  if (section.table) {
    lines.push({
      text: section.table.headers.join(' | '),
      size: 7.5,
      bold: true,
      gapBefore: 5,
      gapAfter: 3,
    })

    section.table.rows.forEach((row) => {
      addWrapped(lines, row.join(' | '), { size: 7.5, indent: 4, gapAfter: 2 })
    })
  }

  if (section.example) {
    addWrapped(lines, `Example: ${section.example}`, { size: 8.5, indent: 8, gapBefore: 4, gapAfter: 3 })
  }

  if (section.note) {
    addWrapped(lines, `Important: ${section.note}`, { size: 8.5, bold: true, indent: 8, gapBefore: 4, gapAfter: 3 })
  }

  section.links?.forEach((link) => {
    addWrapped(lines, `Game page: ${link.label} - ${link.href}`, { size: 7.5, indent: 8, gapBefore: 2 })
  })

  return lines
}

function paginate(manual: GameManualDocument) {
  const pages: PdfPage[] = []

  const titlePage: PdfPage = []
  titlePage.push({ text: 'TENNIS LEGACY: RISE TO GLORY', size: 13, bold: true, gapBefore: 95, gapAfter: 16 })
  titlePage.push({ text: 'FULL GAME MANUAL', size: 27, bold: true, gapAfter: 16 })
  addWrapped(titlePage, 'The complete in-game reference for the currently implemented Tennis Legacy career.', { size: 11, gapAfter: 12 })
  titlePage.push({ text: `English source edition - Version ${manual.meta.version}`, size: 9, bold: true, gapAfter: 4 })
  titlePage.push({ text: `Updated ${manual.meta.updated}`, size: 9, gapAfter: 16 })
  addWrapped(titlePage, manual.meta.sourceNotice, { size: 8.5, gapAfter: 10 })
  addWrapped(titlePage, 'The in-game manual is the primary living reference. This PDF is generated from the same English manual content.', { size: 8.5 })
  pages.push(titlePage)

  const toc: PdfPage = [{ text: 'TABLE OF CONTENTS', size: 18, bold: true, gapAfter: 10 }]
  manual.chapters.forEach((chapter, index) => {
    addWrapped(toc, `${String(index + 1).padStart(2, '0')}  ${chapter.title}`, {
      size: 9,
      bold: true,
      gapAfter: 2,
    })
  })
  pages.push(toc)

  manual.chapters.forEach((chapter, chapterIndex) => {
    const chapterLines: PdfLine[] = [
      { text: `CHAPTER ${chapterIndex + 1} OF ${manual.chapters.length}`, size: 8, bold: true, gapAfter: 5 },
      { text: chapter.title, size: 19, bold: true, gapAfter: 7 },
    ]
    addWrapped(chapterLines, chapter.summary, { size: 10, gapAfter: 8 })
    chapter.sections.forEach((section) => chapterLines.push(...sectionLines(section)))

    let current: PdfPage = []
    let y = PAGE_HEIGHT - TOP

    const pushPage = () => {
      if (current.length) pages.push(current)
      current = []
      y = PAGE_HEIGHT - TOP
    }

    for (const line of chapterLines) {
      const size = line.size ?? 9
      const lineHeight = size * 1.38
      const needed = (line.gapBefore ?? 0) + lineHeight + (line.gapAfter ?? 0)

      if (y - needed < BOTTOM && current.length) pushPage()

      current.push(line)
      y -= needed
    }

    pushPage()
  })

  return pages
}

function contentStream(lines: PdfLine[], pageNumber: number, pageCount: number) {
  const commands: string[] = []
  let y = PAGE_HEIGHT - TOP

  for (const line of lines) {
    y -= line.gapBefore ?? 0
    const size = line.size ?? 9
    const font = line.bold ? 'F2' : 'F1'
    const x = LEFT + (line.indent ?? 0)
    commands.push(
      `BT /${font} ${size.toFixed(2)} Tf 1 0 0 1 ${x.toFixed(2)} ${y.toFixed(2)} Tm (${escapePdfString(line.text)}) Tj ET`,
    )
    y -= size * 1.38
    y -= line.gapAfter ?? 0
  }

  const footer = `Tennis Legacy Full Game Manual - Page ${pageNumber} of ${pageCount}`
  commands.push(
    `BT /F1 7.00 Tf 1 0 0 1 ${LEFT.toFixed(2)} 24.00 Tm (${escapePdfString(footer)}) Tj ET`,
  )

  return commands.join('\n')
}

function buildPdf(manual: GameManualDocument) {
  const pages = paginate(manual)
  const objects = new Map<number, string>()

  objects.set(1, '<< /Type /Catalog /Pages 2 0 R >>')
  objects.set(3, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>')
  objects.set(4, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>')

  const kids: string[] = []

  pages.forEach((lines, index) => {
    const pageId = 5 + index * 2
    const contentId = pageId + 1
    kids.push(`${pageId} 0 R`)

    const stream = contentStream(lines, index + 1, pages.length)
    objects.set(
      pageId,
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${PAGE_WIDTH} ${PAGE_HEIGHT}] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents ${contentId} 0 R >>`,
    )
    objects.set(contentId, `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`)
  })

  objects.set(2, `<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>`)

  const maxId = 4 + pages.length * 2
  let pdf = '%PDF-1.4\n% Tennis Legacy Full Game Manual\n'
  const offsets: number[] = new Array(maxId + 1).fill(0)

  for (let id = 1; id <= maxId; id += 1) {
    offsets[id] = pdf.length
    pdf += `${id} 0 obj\n${objects.get(id) ?? '<< >>'}\nendobj\n`
  }

  const xrefOffset = pdf.length
  pdf += `xref\n0 ${maxId + 1}\n`
  pdf += '0000000000 65535 f \n'

  for (let id = 1; id <= maxId; id += 1) {
    pdf += `${String(offsets[id]).padStart(10, '0')} 00000 n \n`
  }

  pdf += `trailer\n<< /Size ${maxId + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`

  return new Blob([pdf], { type: 'application/pdf' })
}

export function downloadGameManualPdf(manual: GameManualDocument) {
  const blob = buildPdf(manual)
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = 'Tennis-Legacy-Full-Game-Manual-EN.pdf'
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  window.setTimeout(() => URL.revokeObjectURL(url), 1500)
}
