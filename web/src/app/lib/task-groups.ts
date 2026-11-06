import { addDays } from './days.ts';
import type { TaskData } from './payloads.ts';
import type { Rec } from './store.ts';

export type Group<T = Rec<TaskData>> = { id: 'overdue' | 'today' | 'tomorrow' | 'thisWeek' | 'later' | 'noDate'; title: string; items: T[] };
/** The iPhone's groups (SPEC §6.7): Overdue · Today · Tomorrow · This week (the next five days) · Later · No date. */
export function groupTasks<T extends { data: Pick<TaskData, 'dayKey'> }>(active: T[], today: string): Group<T>[] {
  const tomorrow = addDays(today, 1), weekEnd = addDays(today, 6);
  const groups: Group<T>[] = [
    { id: 'overdue', title: 'Overdue', items: [] }, { id: 'today', title: 'Today', items: [] }, { id: 'tomorrow', title: 'Tomorrow', items: [] },
    { id: 'thisWeek', title: 'This week', items: [] }, { id: 'later', title: 'Later', items: [] }, { id: 'noDate', title: 'No date', items: [] },
  ];
  for (const t of active) {
    const d = t.data.dayKey;
    const index = !d ? 5 : d < today ? 0 : d === today ? 1 : d === tomorrow ? 2 : d <= weekEnd ? 3 : 4;
    groups[index]!.items.push(t);
  }
  return groups.filter((g) => g.items.length > 0);
}
