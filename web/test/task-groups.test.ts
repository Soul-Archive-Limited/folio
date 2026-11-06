// To-do groups (Batch L): the iPhone's buckets (TodoModel.swift) on the web.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { groupTasks } from '../src/app/lib/task-groups.ts';

test('overdue, today, tomorrow, this week (next five days), later, no date', () => {
  const t = (dayKey?: string) => ({ data: { dayKey } });
  const groups = groupTasks([t('2026-10-20'), t('2026-10-27'), t('2026-10-28'), t('2026-11-02'), t('2026-11-03'), t()], '2026-10-27');
  assert.deepEqual(groups.map((g) => [g.id, g.items.map((i) => i.data.dayKey)]), [
    ['overdue', ['2026-10-20']], ['today', ['2026-10-27']], ['tomorrow', ['2026-10-28']], ['thisWeek', ['2026-11-02']], ['later', ['2026-11-03']], ['noDate', [undefined]],
  ]);
});
test('empty groups are left out', () => assert.deepEqual(groupTasks([{ data: { dayKey: '2026-10-27' } }], '2026-10-27').map((g) => g.id), ['today']));
