import type { ReactNode } from 'react';
import { type Block, fromMarkdown, type Run } from '../lib/markdown.ts';

/** Renders Folio Markdown as elements (never as HTML strings). */
export function Prose({ markdown }: { markdown: string }) {
  const blocks = fromMarkdown(markdown).blocks;
  const out: ReactNode[] = [];
  for (let i = 0; i < blocks.length; ) {
    const block = blocks[i]!;
    if (block.type === 'bullet' || block.type === 'numbered' || block.type === 'checklist') {
      const group: Block[] = [];
      while (i < blocks.length && blocks[i]!.type === block.type) group.push(blocks[i++]!);
      const items = group.map((b, k) => block.type === 'checklist'
        ? <li key={k} className={b.checked ? 'done' : undefined}><input type="checkbox" checked={!!b.checked} readOnly disabled aria-label={b.checked ? 'Done' : 'Not done'} /><span>{runs(b.runs)}</span></li>
        : <li key={k}>{runs(b.runs)}</li>);
      out.push(block.type === 'numbered' ? <ol key={i}>{items}</ol> : <ul key={i} className={block.type === 'checklist' ? 'checklist' : undefined}>{items}</ul>);
      continue;
    }
    if (block.type === 'quote') {
      const group: Block[] = [];
      while (i < blocks.length && blocks[i]!.type === 'quote') group.push(blocks[i++]!);
      out.push(<blockquote key={i}>{group.map((b, k) => <p key={k}>{runs(b.runs)}</p>)}</blockquote>);
      continue;
    }
    out.push(block.type === 'heading' ? <h1 key={i}>{runs(block.runs)}</h1> : <p key={i}>{runs(block.runs)}</p>);
    i++;
  }
  return <div className="prose">{out}</div>;
}

function runs(list: Run[]): ReactNode[] {
  return list.map((run, k) => {
    let node: ReactNode = run.text;
    for (const style of [...run.styles].reverse()) {
      node = style === 'bold' ? <strong>{node}</strong> : style === 'italic' ? <em>{node}</em> : style === 'underline' ? <u>{node}</u>
        : style === 'strikethrough' ? <s>{node}</s> : <mark>{node}</mark>;
    }
    return <span key={k}>{node}</span>;
  });
}
