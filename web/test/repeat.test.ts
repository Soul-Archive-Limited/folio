// Repeating tasks: the same next dates as RepeatReminderSubtaskTests.swift (Batch I).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nextDay, parseRule, shiftReminder } from '../src/app/lib/repeat.ts';

const today = '2026-10-30'; // a Friday
const cases: [string, string][] = [
  ['{"frequency":"daily","interval":1,"unit":"day"}', '2026-10-31'],
  ['{"frequency":"weekdays","interval":1,"unit":"day"}', '2026-11-02'],
  ['{"frequency":"weekly","interval":1,"unit":"day"}', '2026-11-06'],
  ['{"frequency":"monthly","interval":1,"unit":"day"}', '2026-11-30'],
  ['{"frequency":"yearly","interval":1,"unit":"day"}', '2027-10-30'],
  ['{"frequency":"custom","interval":3,"unit":"day"}', '2026-11-02'],
  ['{"frequency":"custom","interval":2,"unit":"week"}', '2026-11-13'],
  ['{"frequency":"custom","interval":4,"unit":"month"}', '2027-02-28'],
];
for (const [json, expected] of cases) {
  test(`next for ${json}`, () => assert.equal(nextDay(parseRule(json)!, today), expected));
}
test('31 January monthly → 28 February', () => assert.equal(nextDay({ frequency: 'monthly' }, '2027-01-31'), '2027-02-28'));
test('bad rules are ignored', () => assert.equal(parseRule('{"frequency":"hourly"}'), undefined));
test('reminders move by the same days', () => assert.equal(shiftReminder('2026-10-30T08:00', 7), '2026-11-06T08:00'));
test('intervals are bounded to 1…99', () => {
  assert.equal(parseRule('{"frequency":"custom","interval":1e9,"unit":"day"}')!.interval, 99);
  assert.equal(parseRule('{"frequency":"custom","interval":-4,"unit":"week"}')!.interval, 1);
});
