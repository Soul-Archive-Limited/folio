import { useState } from 'react';
import { sameId } from '../../lib/bytes.ts';
import { CATEGORY_COLORS, categoryColor, type CategoryData } from '../../lib/payloads.ts';
import type { Rec } from '../../lib/store.ts';
import { Empty, Modal } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';
import { Back } from './ProfileView.tsx';

const MAX = 30;

/** Categories (SPEC §6.10): colour, name, count; reorder; edit; delete to Recently Deleted. */
export default function Categories() {
  const { store, toast } = useDiary();
  const [editing, setEditing] = useState<Rec<CategoryData> | 'new' | null>(null);
  const [dragging, setDragging] = useState<number | null>(null);
  const list = store.categories();
  const count = (id: string) => store.entries().filter((e) => sameId(e.data.categoryID, id)).length + store.tasks().filter((t) => sameId(t.data.categoryID, id)).length;

  function move(from: number, to: number) {
    if (to < 0 || to >= list.length || from === to) return;
    const order = [...list];
    const [item] = order.splice(from, 1);
    order.splice(to, 0, item!);
    order.forEach((c, i) => c.data.sortIndex !== i && store.put('category', { sortIndex: i }, c.id));
  }

  return (
    <>
      <Back title="Categories" />
      {list.length === 0 ? <Empty icon="tag" text="No categories yet. Make one with your own colour." /> : (
        <div className="group glass">
          {list.map((c, i) => (
            <div key={c.id} className="row" draggable onDragStart={() => setDragging(i)} onDragOver={(e) => e.preventDefault()} onDrop={() => dragging !== null && move(dragging, i)} onDragEnd={() => setDragging(null)}>
              <span className="chip" style={{ ['--c' as string]: categoryColor(c.data.colorKey), border: 0, background: 'none', padding: 0 }}><i className="dot" style={{ width: 14, height: 14 }} /></span>
              <button className="grow" style={{ border: 0, background: 'none', textAlign: 'left', padding: '6px 0' }} onClick={() => setEditing(c)}>{c.data.name}</button>
              <span className="value">{count(c.id)}</span>
              <button className="icon-btn plain" aria-label={`Move ${c.data.name} up`} disabled={i === 0} onClick={() => move(i, i - 1)}><Icon name="chevronDown" small /></button>
              <button className="icon-btn plain" aria-label={`Delete ${c.data.name}`} onClick={() => {
                store.trashCategory(c.id);
                toast('Moved to Recently Deleted', { label: 'Undo', run: () => store.restoreCategory(c.id) });
              }}><Icon name="trash" small /></button>
            </div>
          ))}
        </div>
      )}
      <button className="btn primary" disabled={list.length >= MAX} onClick={() => setEditing('new')}><Icon name="plus" small />New category</button>
      {list.length >= MAX && <p className="fine">Up to {MAX} categories.</p>}
      {editing && <EditCategory category={editing === 'new' ? undefined : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function EditCategory({ category, onClose }: { category?: Rec<CategoryData>; onClose: () => void }) {
  const { store } = useDiary();
  const used = new Set(store.categories().map((c) => c.data.colorKey));
  const [name, setName] = useState(category?.data.name ?? '');
  const [color, setColor] = useState(category?.data.colorKey ?? CATEGORY_COLORS.find((c) => !used.has(c)) ?? 'ember');
  const clash = store.categories().some((c) => c.data.name.toLowerCase() === name.trim().toLowerCase() && (!category || !sameId(c.id, category.id)));
  function save() {
    if (!name.trim() || clash) return;
    store.put('category', { name: name.trim().slice(0, 24), colorKey: color, ...(category ? {} : { sortIndex: store.categories().length, createdAt: Date.now() }) }, category?.id);
    onClose();
  }
  return (
    <Modal title={category ? 'Edit category' : 'New category'} onClose={onClose}>
      <form onSubmit={(e) => { e.preventDefault(); save(); }} style={{ display: 'grid', gap: 14, width: '100%' }}>
        <input className="field" autoFocus maxLength={24} placeholder="Name" aria-label="Name" value={name} onChange={(e) => setName(e.target.value)} />
        {clash && <p className="error">You already have a category with that name.</p>}
        <div className="swatches" role="radiogroup" aria-label="Colour">
          {CATEGORY_COLORS.map((c) => <button type="button" key={c} role="radio" aria-checked={color === c} aria-pressed={color === c} aria-label={c} style={{ ['--c' as string]: categoryColor(c) }} onClick={() => setColor(c)} />)}
        </div>
        <span className="chip" style={{ ['--c' as string]: categoryColor(color), justifySelf: 'start' }}><i className="dot" />{name.trim() || 'Preview'}</span>
        <p className="fine">Symbols for categories are chosen in the iPhone app.</p>
        <div className="actions"><button type="button" className="btn" onClick={onClose}>Cancel</button><button className="btn primary" disabled={!name.trim() || clash}>Save</button></div>
      </form>
    </Modal>
  );
}
