// Quick add's natural dates (Batch L): the same cases as QuickAddNaturalTests.swift, so the web
// and the iPhone read a line the same way. Reference now: Tuesday 27 October 2026, 09:30.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseQuickAdd } from '../src/app/lib/quickadd.ts';
import { formatTime } from '../src/app/lib/days.ts';

const today = '2026-10-27';
const now = 9 * 60 + 30;
const run = (text: string, monthFirst = false) => parseQuickAdd(text, today, now, monthFirst);
const cases: [string, string, string | undefined, string | undefined][] = [
  ['Call Mum today', 'Call Mum', '2026-10-27', undefined],
  ['Call Mum tomorrow', 'Call Mum', '2026-10-28', undefined],
  ['tomorrow call Mum', 'call Mum', '2026-10-28', undefined],
  ['Pay rent tmrw', 'Pay rent', '2026-10-28', undefined],
  ['Book flights day after tomorrow', 'Book flights', '2026-10-29', undefined],
  ['Dentist in 5 days', 'Dentist', '2026-11-01', undefined],
  ['Dentist after 5 days', 'Dentist', '2026-11-01', undefined],
  ['Renew insurance in two weeks', 'Renew insurance', '2026-11-10', undefined],
  ['Check plants in a week', 'Check plants', '2026-11-03', undefined],
  ['Car service in 3 months', 'Car service', '2027-01-27', undefined],
  ['Haircut next week', 'Haircut', '2026-11-03', undefined],
  ['Pay credit card next month', 'Pay credit card', '2026-11-27', undefined],
  ['Clean the bikes this weekend', 'Clean the bikes', '2026-10-31', undefined],
  ['Hike weekend', 'Hike', '2026-10-31', undefined],
  ['Team lunch next Monday', 'Team lunch', '2026-11-02', undefined],
  ['Team lunch on Monday', 'Team lunch', '2026-11-02', undefined],
  ['Gym Friday', 'Gym', '2026-10-30', undefined],
  ['Gym on fri', 'Gym', '2026-10-30', undefined],
  ['Standup next Tuesday', 'Standup', '2026-11-03', undefined],
  ['Standup this Tuesday', 'Standup', '2026-10-27', undefined],
  ['Pay council tax on 5 Nov', 'Pay council tax', '2026-11-05', undefined],
  ['Bonfire 5th November', 'Bonfire', '2026-11-05', undefined],
  ['Bonfire on the 5th of November', 'Bonfire', '2026-11-05', undefined],
  ['Diwali shopping 8 Nov 2026', 'Diwali shopping', '2026-11-08', undefined],
  ['Send card 2 Jan', 'Send card', '2027-01-02', undefined],
  ['Visa renewal 15/12', 'Visa renewal', '2026-12-15', undefined],
  ['Visa renewal on 15/12/2026', 'Visa renewal', '2026-12-15', undefined],
  ['Exam 03-11-26', 'Exam', '2026-11-03', undefined],
  ['Exam 3.11.2026', 'Exam', '2026-11-03', undefined],
  ['Call Mum tomorrow 6pm', 'Call Mum', '2026-10-28', '18:00'],
  ['Call Mum tomorrow at 6pm', 'Call Mum', '2026-10-28', '18:00'],
  ['Call Mum 6pm tomorrow', 'Call Mum', '2026-10-28', '18:00'],
  ['Dinner at 7', 'Dinner', '2026-10-27', '19:00'],
  ['Run at 10', 'Run', '2026-10-27', '10:00'],
  ['Run at 9', 'Run', '2026-10-27', '21:00'],
  ['Pick up parcel at 18:30', 'Pick up parcel', '2026-10-27', '18:30'],
  ['Pick up parcel 18.30', 'Pick up parcel', '2026-10-27', '18:30'],
  ['Coffee with Ana at 8am', 'Coffee with Ana', '2026-10-28', '08:00'],
  ['Pharmacy 5:15 pm', 'Pharmacy', '2026-10-27', '17:15'],
  ['Lunch with Raj noon', 'Lunch with Raj', '2026-10-27', '12:00'],
  ['Call bank tonight', 'Call bank', '2026-10-27', '20:00'],
  ['Water plants tomorrow morning', 'Water plants', '2026-10-28', '09:00'],
  ['Meeting next Monday at 9', 'Meeting', '2026-11-02', '09:00'],
  ['School pickup Friday at 3', 'School pickup', '2026-10-30', '15:00'],
  ['Call Dad this evening', 'Call Dad', '2026-10-27', '18:00'],
];
for (const [text, title, day, time] of cases) {
  test(`"${text}"`, () => {
    const r = run(text);
    assert.equal(r.title, title);
    assert.equal(r.dayKey, day);
    assert.equal(r.minutesFromMidnight === undefined ? undefined : formatTime(r.minutesFromMidnight), time);
  });
}
for (const text of ["Today's papers", 'Read Monday notes', 'Buy 2 apples', 'Enjoy the sun', 'Tomorrow', 'Look at 3 options carefully', 'Room 101']) {
  test(`stays as typed: "${text}"`, () => assert.deepEqual(run(text), { title: text }));
}
test('US order reads month first', () => {
  assert.equal(run('Visa renewal 12/15', true).dayKey, '2026-12-15');
  assert.equal(run('Visa renewal 12/15').dayKey, undefined);
});
test('a time that has passed today means tomorrow', () => assert.equal(run('Alarm check at 8am').dayKey, '2026-10-28'));
for (const text of ['Party 31 Feb', 'Party 30/02', 'Tea at 25']) test(`impossible: ${text}`, () => assert.equal(run(text).dayKey, undefined));
