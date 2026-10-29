/**
 * Folio Markdown (SPEC §5.1), a line-for-line port of `MarkdownCodec.swift` and pinned by
 * `shared/markdown-fixtures.json`. One block per line; inline **bold**, _italic_, <u>underline</u>,
 * ~~strike~~, ==highlight==; `\` escapes; unclosed markers stay literal.
 */

export type InlineStyle = 'bold' | 'italic' | 'underline' | 'strikethrough' | 'highlight';
export type BlockType = 'paragraph' | 'heading' | 'bullet' | 'numbered' | 'quote' | 'checklist';
export interface Run { text: string; styles: InlineStyle[] }
export interface Block { type: BlockType; checked?: boolean; runs: Run[] }
export interface RichDocument { blocks: Block[] }

/** Outermost first; serialisation opens markers in this order so output is canonical. */
export const CANONICAL_ORDER: InlineStyle[] = ['underline', 'highlight', 'strikethrough', 'bold', 'italic'];
const OPENING: Record<InlineStyle, string> = { bold: '**', italic: '_', underline: '<u>', strikethrough: '~~', highlight: '==' };
const closing = (style: InlineStyle) => (style === 'underline' ? '</u>' : OPENING[style]);
const ESCAPED = new Set(['\\', '*', '_', '~', '=', '<']);

const sortStyles = (styles: Iterable<InlineStyle>) => CANONICAL_ORDER.filter((s) => new Set(styles).has(s));
const sameStyles = (a: InlineStyle[], b: InlineStyle[]) => a.length === b.length && a.every((s) => b.includes(s));

// MARK: Serialise

export function toMarkdown(doc: RichDocument): string {
  const lines: string[] = [];
  let number = 0;
  for (const block of doc.blocks) {
    number = block.type === 'numbered' ? number + 1 : 0;
    const body = inlineMarkdown(block.runs);
    switch (block.type) {
      case 'paragraph': lines.push(escapeLineStart(body)); break;
      case 'heading': lines.push(`# ${body}`); break;
      case 'bullet': lines.push(`- ${body}`); break;
      case 'numbered': lines.push(`${number}. ${body}`); break;
      case 'quote': lines.push(`> ${body}`); break;
      case 'checklist': lines.push(`${block.checked ? '- [x] ' : '- [ ] '}${body}`); break;
    }
  }
  return lines.join('\n');
}

export function inlineMarkdown(runs: Run[]): string {
  let output = '';
  const open: InlineStyle[] = [];
  for (const run of normalized(runs)) {
    // Close from the top of the stack until everything left is still wanted.
    for (let index = open.findIndex((s) => !run.styles.includes(s)); index >= 0; index = open.findIndex((s) => !run.styles.includes(s))) {
      while (open.length > index) output += closing(open.pop()!);
    }
    for (const style of CANONICAL_ORDER) {
      if (run.styles.includes(style) && !open.includes(style)) {
        output += OPENING[style];
        open.push(style);
      }
    }
    output += escape(run.text);
  }
  while (open.length) output += closing(open.pop()!);
  return output;
}

export const escape = (text: string) => Array.from(text, (c) => (ESCAPED.has(c) ? `\\${c}` : c)).join('');

/** A paragraph whose text would read as a block marker gets its first character escaped. */
function escapeLineStart(line: string): string {
  if (line.startsWith('# ') || line.startsWith('- ') || line.startsWith('> ') || line === '#') return `\\${line}`;
  const dot = line.indexOf('.');
  if (dot > 0 && /^\p{N}+$/u.test(line.slice(0, dot)) && line.slice(dot + 1).startsWith(' ')) {
    return `${line.slice(0, dot)}\\${line.slice(dot)}`;
  }
  return line;
}

// MARK: Parse

export function fromMarkdown(markdown: string): RichDocument {
  if (!markdown) return { blocks: [] };
  return { blocks: markdown.replace(/\r\n/g, '\n').split('\n').map(blockFrom) };
}

const PREFIXES: [string, BlockType, boolean?][] = [
  ['- [ ] ', 'checklist', false], ['- [x] ', 'checklist', true], ['- [X] ', 'checklist', true],
  ['# ', 'heading'], ['- ', 'bullet'], ['> ', 'quote'],
];

function blockFrom(line: string): Block {
  for (const [prefix, type, checked] of PREFIXES) {
    if (line.startsWith(prefix)) {
      const block: Block = { type, runs: inlineRuns(line.slice(prefix.length)) };
      if (type === 'checklist') block.checked = checked;
      return block;
    }
  }
  const numbered = /^([0-9]+)\. /.exec(line);
  if (numbered) return { type: 'numbered', runs: inlineRuns(line.slice(numbered[0].length)) };
  return { type: 'paragraph', runs: inlineRuns(line) };
}

type Token = { kind: 'text'; text: string } | { kind: 'marker'; style: InlineStyle; opening: boolean; literal: string };

export function inlineRuns(text: string): Run[] {
  const tokens = tokenize(text);
  const matched = matchedMarkers(tokens);
  const runs: Run[] = [];
  const active = new Set<InlineStyle>();
  tokens.forEach((token, index) => {
    if (token.kind === 'text') {
      runs.push({ text: token.text, styles: sortStyles(active) });
    } else if (matched.has(index)) {
      if (token.opening) active.add(token.style);
      else active.delete(token.style);
    } else {
      runs.push({ text: token.literal, styles: sortStyles(active) });
    }
  });
  return normalized(runs);
}

/** Toggle markers (`**`, `_`, `*`, `~~`, `==`) open when their style isn't active and close when it is. */
function tokenize(text: string): Token[] {
  const tokens: Token[] = [];
  const chars = Array.from(text);
  const active = new Set<InlineStyle>();
  let buffer = '';
  let i = 0;
  const flush = () => {
    if (buffer) tokens.push({ kind: 'text', text: buffer });
    buffer = '';
  };
  const toggle = (style: InlineStyle, literal: string) => {
    flush();
    const opening = !active.has(style);
    if (opening) active.add(style);
    else active.delete(style);
    tokens.push({ kind: 'marker', style, opening, literal });
  };
  const ahead = (s: string) => chars.slice(i, i + s.length).join('') === s;
  while (i < chars.length) {
    const c = chars[i]!;
    if (c === '\\' && i + 1 < chars.length) {
      buffer += chars[i + 1];
      i += 2;
    } else if (ahead('**')) {
      toggle('bold', '**'); i += 2;
    } else if (ahead('~~')) {
      toggle('strikethrough', '~~'); i += 2;
    } else if (ahead('==')) {
      toggle('highlight', '=='); i += 2;
    } else if (ahead('<u>')) {
      flush(); active.add('underline');
      tokens.push({ kind: 'marker', style: 'underline', opening: true, literal: '<u>' }); i += 3;
    } else if (ahead('</u>')) {
      flush(); active.delete('underline');
      tokens.push({ kind: 'marker', style: 'underline', opening: false, literal: '</u>' }); i += 4;
    } else if (c === '_' || c === '*') {
      toggle('italic', c); i += 1;
    } else {
      buffer += c; i += 1;
    }
  }
  flush();
  return tokens;
}

/** Indices of markers that have a partner; the rest are literal text. */
function matchedMarkers(tokens: Token[]): Set<number> {
  const matched = new Set<number>();
  const openIndex = new Map<InlineStyle, number>();
  tokens.forEach((token, index) => {
    if (token.kind !== 'marker') return;
    if (token.opening) openIndex.set(token.style, index);
    else if (openIndex.has(token.style)) {
      matched.add(openIndex.get(token.style)!);
      matched.add(index);
      openIndex.delete(token.style);
    }
  });
  return matched;
}

/** Merges neighbouring runs with identical styles and drops empty ones. */
export function normalized(runs: Run[]): Run[] {
  const out: Run[] = [];
  for (const run of runs) {
    if (!run.text) continue;
    const last = out[out.length - 1];
    if (last && sameStyles(last.styles, run.styles)) last.text += run.text;
    else out.push({ text: run.text, styles: sortStyles(run.styles) });
  }
  return out;
}

/** Plain text, one block per line — previews and the "has content" check. */
export const plainText = (markdown: string) => fromMarkdown(markdown).blocks.map((b) => b.runs.map((r) => r.text).join('')).join('\n');
