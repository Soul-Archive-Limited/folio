import Highlight from '@tiptap/extension-highlight';
import { ListItem, TaskItem, TaskList } from '@tiptap/extension-list';
import { EditorContent, type Editor as TiptapEditor, useEditor, useEditorState } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import { useState } from 'react';
import { fromEditorJSON, type PMNode, toEditorJSON } from '../lib/editorDoc.ts';
import { fromMarkdown, toMarkdown } from '../lib/markdown.ts';
import { Icon } from './Icons.tsx';

/** One level only: Folio Markdown is a line per block, so items never nest (SPEC §5.1). */
const FlatListItem = ListItem.extend({ addKeyboardShortcuts() { return { Enter: () => this.editor.commands.splitListItem(this.name) }; } });
const FlatTaskItem = TaskItem.extend({ addKeyboardShortcuts() { return { Enter: () => this.editor.commands.splitListItem(this.name) }; } });

/**
 * The web editor (SPEC §11.3): Tiptap with exactly SPEC §5.1's styles — bold, italic,
 * underline, strikethrough, highlight, one heading level, bullets, numbers, checklist, quote —
 * and nothing else, so whatever is typed or pasted fits Folio Markdown. Hook API: one editor
 * in one component.
 */
export function useFolioEditor(markdown: string, placeholder: string, onChange: () => void) {
  return useEditor({
    extensions: [
      StarterKit.configure({
        code: false, codeBlock: false, horizontalRule: false, hardBreak: false, link: false, trailingNode: false,
        heading: { levels: [1] }, listItem: false,
      }),
      FlatListItem,
      TaskList,
      FlatTaskItem.configure({ nested: false }),
      Highlight.configure({ multicolor: false }),
    ],
    content: toEditorJSON(fromMarkdown(markdown)),
    editorProps: { attributes: { 'aria-label': placeholder, 'aria-multiline': 'true', role: 'textbox', 'data-placeholder': placeholder } },
    immediatelyRender: true,
    shouldRerenderOnTransaction: false,
    onUpdate: onChange,
  });
}

export const editorMarkdown = (editor: TiptapEditor | null) => (editor ? toMarkdown(fromEditorJSON(editor.getJSON() as PMNode)) : '');

export function EditorBody({ editor, placeholder }: { editor: TiptapEditor | null; placeholder: string }) {
  const empty = useEditorState({ editor, selector: (s) => s.editor?.isEmpty ?? true });
  return (
    <div className="editor" style={{ position: 'relative' }}>
      {empty && <div aria-hidden="true" className="ink3" style={{ position: 'absolute', pointerEvents: 'none' }}>{placeholder}</div>}
      <EditorContent editor={editor} />
    </div>
  );
}

const INLINE = [
  ['bold', 'Bold', 'toggleBold'], ['italic', 'Italic', 'toggleItalic'], ['underline', 'Underline', 'toggleUnderline'],
  ['strike', 'Strikethrough', 'toggleStrike'], ['highlight', 'Highlight', 'toggleHighlight'],
] as const;
const BLOCKS = [
  ['heading', 'Heading', 'heading'], ['bullets', 'Bulleted list', 'bulletList'], ['numbers', 'Numbered list', 'orderedList'],
  ['checklist', 'Checklist', 'taskList'], ['quote', 'Quote', 'blockquote'],
] as const;

/** The Aa popover: five inline and five block styles (SPEC §6.4). */
export function FormatPopover({ editor, onClose }: { editor: TiptapEditor; onClose: () => void }) {
  const state = useEditorState({
    editor,
    selector: ({ editor: e }) => Object.fromEntries([
      ...INLINE.map(([, , command]) => [command, e.isActive(command.replace('toggle', '').toLowerCase())]),
      ['heading', e.isActive('heading')], ['bulletList', e.isActive('bulletList')], ['orderedList', e.isActive('orderedList')],
      ['taskList', e.isActive('taskList')], ['blockquote', e.isActive('blockquote')],
    ]) as Record<string, boolean>,
  });
  const run = (name: string) => {
    const chain = editor.chain().focus();
    switch (name) {
      case 'heading': chain.toggleHeading({ level: 1 }).run(); break;
      case 'bulletList': chain.toggleBulletList().run(); break;
      case 'orderedList': chain.toggleOrderedList().run(); break;
      case 'taskList': chain.toggleTaskList().run(); break;
      case 'blockquote': chain.toggleBlockquote().run(); break;
      default: (chain as unknown as Record<string, () => { run: () => void }>)[name]!().run();
    }
  };
  return (
    <div className="format-pop glass" role="toolbar" aria-label="Text styles" onKeyDown={(e) => e.key === 'Escape' && onClose()}>
      <div className="row">
        {INLINE.map(([icon, label, command]) => (
          <button key={command} className="icon-btn" aria-label={label} aria-pressed={!!state?.[command]} onMouseDown={(e) => e.preventDefault()} onClick={() => run(command)}><Icon name={icon} /></button>
        ))}
      </div>
      <div className="row">
        {BLOCKS.map(([icon, label, name]) => (
          <button key={name} className="icon-btn" aria-label={label} aria-pressed={!!state?.[name]} onMouseDown={(e) => e.preventDefault()} onClick={() => run(name)}><Icon name={icon} /></button>
        ))}
      </div>
    </div>
  );
}

export function useToggle(initial = false) {
  const [on, set] = useState(initial);
  return [on, () => set((v) => !v), set] as const;
}
