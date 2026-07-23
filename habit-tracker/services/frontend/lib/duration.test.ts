// [review:need-review] PHASE-01/34-duration-field-type
// summary: unit tests for duration parse/format helpers
import { describe, expect, it } from 'bun:test';
import {
  formatSecondsToHM,
  parseDurationToSeconds,
  secondsToInputValue,
} from './duration';

describe('parseDurationToSeconds', () => {
  it('parses H:MM into seconds', () => {
    expect(parseDurationToSeconds('1:20')).toBe(4800);
    expect(parseDurationToSeconds('01:20')).toBe(4800);
    expect(parseDurationToSeconds('0:45')).toBe(2700);
    expect(parseDurationToSeconds('2:00')).toBe(7200);
  });

  it('parses bare minutes', () => {
    expect(parseDurationToSeconds('45')).toBe(2700);
    expect(parseDurationToSeconds('0')).toBe(0);
  });

  it('rejects empty, malformed and out-of-range input', () => {
    expect(parseDurationToSeconds('')).toBeNull();
    expect(parseDurationToSeconds('   ')).toBeNull();
    expect(parseDurationToSeconds('abc')).toBeNull();
    expect(parseDurationToSeconds('1:60')).toBeNull();
    expect(parseDurationToSeconds('1:2:3')).toBeNull();
    expect(parseDurationToSeconds('-5')).toBeNull();
    expect(parseDurationToSeconds('1:aa')).toBeNull();
  });
});

describe('formatSecondsToHM', () => {
  it('formats hours and minutes compactly', () => {
    expect(formatSecondsToHM(4800)).toBe('1h 20m');
    expect(formatSecondsToHM(2700)).toBe('45m');
    expect(formatSecondsToHM(7200)).toBe('2h');
    expect(formatSecondsToHM(0)).toBe('0m');
    expect(formatSecondsToHM(3600)).toBe('1h');
  });

  it('clamps and rounds', () => {
    expect(formatSecondsToHM(-10)).toBe('0m');
    expect(formatSecondsToHM(89)).toBe('1m');
  });
});

describe('secondsToInputValue', () => {
  it('renders H:MM with zero-padded minutes', () => {
    expect(secondsToInputValue(4800)).toBe('1:20');
    expect(secondsToInputValue(2700)).toBe('0:45');
    expect(secondsToInputValue(3600)).toBe('1:00');
    expect(secondsToInputValue(0)).toBe('0:00');
  });

  it('round-trips with parseDurationToSeconds', () => {
    expect(parseDurationToSeconds(secondsToInputValue(4800))).toBe(4800);
  });
});
