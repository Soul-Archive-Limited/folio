/**
 * Folio's document model ↔ the Tiptap/ProseMirror JSON the web editor edits (SPEC §5.1,
 * §11.3). Lists and quotes are runs of single-line blocks in Folio Markdown and nodes with
 * items in the editor; nested items (the editor doesn't allow them, but pasted content
 * might) flatten to top-level lines.
 */
import { type Block, type BlockType, type InlineStyle, type RichDocument, type Run, normalized } from './markdown.ts';

export interface PMNode {
  type: string;
  attrs?: Record<string, unknown>;
  content?: PMNode[];
  text?: string;
  marks?: { type: string; attrs?: Record<string, unknown> }[];
}

const MARK_FOR: Record<InlineStyle, string> = { bold: 'bold', italic: 'italic', underline: 'underline', strikethrough: 'strike', highlight: 'highlight' };
const STYLE_FOR: Record<string, InlineStyle> = { bold: 'bold', italic: 'italic', underline: 'underline', strike: 'strikethrough', highlight: 'highlight' };

const textNodes = (runs: Run[]): PMNode[] =>
  normalized(runs).map((run) => (run.styles.length ? { type: 'text', text: run.text, marks: run.styles.map((s) => ({ type: MARK_FOR[s] })) } : { type: 'text', text: run.text }));

const paragraph = (runs: Run[]): PMNode => {
  const content = textNodes(runs);
  return content.length ? { type: 'paragraph', content } : { type: 'paragraph' };
};

const LIST: Partial<Record<BlockType, { list: string; item: string }>> = {
  bullet: { list: 'bulletList', item: 'listItem' },
  numbered: { list: 'orderedList', item: 'listItem' },
  checklist: { list: 'taskList', item: 'taskItem' },
};

export function toEditorJSON(doc: RichDocument): PMNode {
  const content: PMNode[] = [];
  for (const block of doc.blocks) {
    const last = content[content.length - 1];
    const list = LIST[block.type];
    if (list) {
      const item: PMNode = { type: list.item, content: [paragraph(block.runs)] };
      if (block.type === 'checklist') item.attrs = { checked: !!block.checked };
      if (last?.type === list.list) last.content!.push(item);
      else content.push({ type: list.list, content: [item] });
    } else if (block.type === 'quote') {
      if (last?.type === 'blockquote') last.content!.push(paragraph(block.runs));
      else content.push({ type: 'blockquote', content: [paragraph(block.runs)] });
    } else if (block.type === 'heading') {
      const node = paragraph(block.runs);
      content.push({ ...node, type: 'heading', attrs: { level: 1 } });
    } else {
      content.push(paragraph(block.runs));
    }
  }
  if (content.length === 0) content.push({ type: 'paragraph' });
  return { type: 'doc', content };
}

function runsOf(node: PMNode): Run[] {
  const runs: Run[] = [];
  const walk = (n: PMNode) => {
    if (n.type === 'text') {
      const styles = (n.marks ?? []).map((m) => STYLE_FOR[m.type]).filter((s): s is InlineStyle => !!s);
      runs.push({ text: n.text ?? '', styles });
    } else n.content?.forEach(walk);
  };
  walk(node);
  return normalized(runs);
}

export function fromEditorJSON(doc: PMNode): RichDocument {
  const blocks: Block[] = [];
  const visit = (node: PMNode, as?: { type: BlockType; checked?: boolean }) => {
    switch (node.type) {
      case 'paragraph':
      case 'heading': {
        const type: BlockType = as?.type ?? (node.type === 'heading' ? 'heading' : 'paragraph');
        const block: Block = { type, runs: runsOf(node) };
        if (type === 'checklist') block.checked = !!as?.checked;
        blocks.push(block);
        break;
      }
      case 'bulletList': node.content?.forEach((item) => visit(item, { type: 'bullet' })); break;
      case 'orderedList': node.content?.forEach((item) => visit(item, { type: 'numbered' })); break;
      case 'taskList': node.content?.forEach((item) => visit(item, { type: 'checklist', checked: !!item.attrs?.checked })); break;
      case 'listItem':
      case 'taskItem': {
        // The item's first paragraph is the line; anything nested becomes its own line.
        const [first, ...rest] = node.content ?? [];
        if (first) visit(first, as);
        rest.forEach((child) => visit(child, child.type === 'paragraph' ? as : undefined));
        break;
      }
      case 'blockquote': node.content?.forEach((child) => visit(child, { type: 'quote' })); break;
      default: node.content?.forEach((child) => visit(child, as));
    }
  };
  doc.content?.forEach((node) => visit(node));
  // An editor that only holds one empty paragraph is an empty body.
  if (blocks.length === 1 && blocks[0]!.type === 'paragraph' && blocks[0]!.runs.length === 0) return { blocks: [] };
  return { blocks };
}
