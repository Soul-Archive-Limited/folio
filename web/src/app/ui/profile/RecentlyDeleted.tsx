import { useState } from 'react';
import { formatShort } from '../../lib/days.ts';
import { plainText } from '../../lib/markdown.ts';
import { deletePhotoBlobs } from '../../lib/photos.ts';
import { daysLeft } from '../../lib/store.ts';
import { Empty, Modal } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';
import { Prose } from '../Prose.tsx';
import { Back } from './ProfileView.tsx';

type Kind = 'entry' | 'task' | 'category';

/** Recently Deleted (SPEC §5.2): restore, delete now, select, empty; gone after 30 days. */
export default function RecentlyDeleted() {
  const { store, toast, showDay } = useDiary();
  const [kind, setKind] = useState<Kind>('entry');
  const [selecting, setSelecting] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [confirm, setConfirm] = useState<{ ids: string[]; all?: boolean } | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const trash = store.trashed();
  const items = (kind === 'entry' ? trash.entries : kind === 'task' ? trash.tasks : trash.categories).sort((a, b) => (b.data.trashedAt ?? 0) - (a.data.trashedAt ?? 0));

  const title = (id: string): string => {
    if (kind === 'entry') { const e = store.get('entry', id)!.data; return e.title || plainText(e.bodyMarkdown).split('\n')[0] || 'Untitled'; }
    if (kind === 'task') return store.get('task', id)!.data.title;
    return store.get('category', id)!.data.name;
  };
  const when = (id: string) => {
    const day = kind === 'entry' ? store.get('entry', id)!.data.dayKey : kind === 'task' ? store.get('task', id)!.data.dayKey : undefined;
    return day ? formatShort(day) : undefined;
  };

  function restore(ids: string[]) {
    for (const id of ids) {
      if (kind === 'category') store.restoreCategory(id);
      else store.restore(kind, id);
    }
    const day = ids.length === 1 && kind !== 'category' ? (kind === 'entry' ? store.get('entry', ids[0]!)?.data.dayKey : store.get('task', ids[0]!)?.data.dayKey) : undefined;
    toast(day ? `Restored to ${formatShort(day)}` : `Restored ${ids.length} ${ids.length === 1 ? 'item' : 'items'}`, day ? { label: 'Show', run: () => showDay(day) } : undefined);
    setSelected(new Set());
  }

  function destroy(ids: string[], all?: boolean) {
    const targets: [Kind, string][] = all
      ? [...trash.entries.map((e) => ['entry', e.id] as [Kind, string]), ...trash.tasks.map((t) => ['task', t.id] as [Kind, string]), ...trash.categories.map((c) => ['category', c.id] as [Kind, string])]
      : ids.map((id) => [kind, id]);
    for (const [k, id] of targets) store.destroyItem(k, id).forEach((photo) => void deletePhotoBlobs(photo));
    setSelected(new Set());
    setConfirm(null);
  }

  return (
    <>
      <Back title="Recently Deleted" />
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', marginBottom: 14 }}>
        <div className="segmented glass" role="group" aria-label="Kind">
          {(['entry', 'task', 'category'] as const).map((k) => (
            <button key={k} aria-pressed={kind === k} onClick={() => { setKind(k); setSelected(new Set()); }}>{{ entry: 'Entries', task: 'Tasks', category: 'Categories' }[k]}</button>
          ))}
        </div>
        {items.length > 0 && (
          <div style={{ marginLeft: 'auto', display: 'flex', gap: 8 }}>
            <button className="btn small" onClick={() => { setSelecting(!selecting); setSelected(new Set()); }}>{selecting ? 'Done' : 'Select'}</button>
            <button className="btn small danger" onClick={() => setConfirm({ ids: items.map((i) => i.id), all: true })}>Empty</button>
          </div>
        )}
      </div>
      {items.length === 0 ? <Empty icon="trash" text="Nothing here. Deleted items stay for 30 days." /> : (
        <div className="group glass">
          {items.map((item) => (
            <div key={item.id}>
              <div className="row" data-testid="trash-row">
                {selecting && <input type="checkbox" aria-label={`Select ${title(item.id)}`} checked={selected.has(item.id)} style={{ width: 20, height: 20, accentColor: 'var(--ember)' }}
                  onChange={(e) => { const s = new Set(selected); if (e.target.checked) s.add(item.id); else s.delete(item.id); setSelected(s); }} />}
                <button className="grow" style={{ border: 0, background: 'none', textAlign: 'left', padding: '4px 0' }} onClick={() => kind === 'entry' && setPreview(preview === item.id ? null : item.id)} aria-expanded={kind === 'entry' ? preview === item.id : undefined}>
                  <span style={{ display: 'block' }}>{title(item.id)}</span>
                  <span className="callout ink3">{[when(item.id), `${daysLeft(item.data.trashedAt!)} days left`].filter(Boolean).join(' · ')}</span>
                </button>
                {!selecting && <>
                  <button className="btn small" onClick={() => restore([item.id])}><Icon name="restore" small />Restore</button>
                  <button className="btn small danger" onClick={() => setConfirm({ ids: [item.id] })}>Delete now</button>
                </>}
              </div>
              {preview === item.id && kind === 'entry' && <div style={{ padding: '0 16px 16px' }}><Prose markdown={store.get('entry', item.id)!.data.bodyMarkdown} /></div>}
            </div>
          ))}
        </div>
      )}
      {selecting && selected.size > 0 && (
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn" onClick={() => restore([...selected])}>Restore selected</button>
          <button className="btn danger" onClick={() => setConfirm({ ids: [...selected] })}>Delete selected</button>
        </div>
      )}
      {confirm && (
        <Modal title={confirm.all ? 'Empty Recently Deleted?' : confirm.ids.length === 1 ? 'Delete this for good?' : `Delete ${confirm.ids.length} items for good?`}
           message={confirm.all ? 'Every entry, task and category in Recently Deleted is deleted for good, on all your devices.' : "This can't be undone, on any of your devices."} onClose={() => setConfirm(null)}>
          <button className="btn" onClick={() => setConfirm(null)}>Cancel</button>
          <button className="btn solid-danger" onClick={() => destroy(confirm.ids, confirm.all)}>{confirm.all ? 'Empty' : 'Delete now'}</button>
        </Modal>
      )}
    </>
  );
}
