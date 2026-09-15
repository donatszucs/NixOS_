#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

const OUTPUT_FILE = '/tmp/quickshell_calendar.json';
const CONFIG_DIR = path.join(os.homedir(), '.config', 'quickshell');
const CONFIG_FILE = path.join(CONFIG_DIR, 'calendar_url.txt');

function unescapeIcs(val) {
  if (!val) return '';
  return val
    .replace(/\\,/g, ',')
    .replace(/\\;/g, ';')
    .replace(/\\\\/g, '\\')
    .replace(/\\n/gi, '\n')
    .trim();
}

function parseIcsDate(val) {
  val = (val || '').trim();
  if (!val) return { dateStr: null, timeStr: '', isAllDay: false, dateObj: null };

  // All-day: e.g. 20260915
  if (/^\d{8}$/.test(val)) {
    const y = parseInt(val.slice(0, 4), 10);
    const m = parseInt(val.slice(4, 6), 10);
    const d = parseInt(val.slice(6, 8), 10);
    const dateStr = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const dateObj = new Date(y, m - 1, d);
    return { dateStr, timeStr: 'All Day', isAllDay: true, dateObj };
  }

  // Datetime: e.g. 20260915T093000Z or 20260915T093000
  const isUtc = val.endsWith('Z');
  const clean = val.replace(/Z$/, '');
  if (clean.includes('T')) {
    const [dPart, tPart] = clean.split('T');
    const y = parseInt(dPart.slice(0, 4), 10);
    const m = parseInt(dPart.slice(4, 6), 10);
    const d = parseInt(dPart.slice(6, 8), 10);
    const hour = parseInt(tPart.slice(0, 2), 10);
    const min = parseInt(tPart.slice(2, 4), 10);

    let dateObj;
    if (isUtc) {
      dateObj = new Date(Date.UTC(y, m - 1, d, hour, min));
    } else {
      dateObj = new Date(y, m - 1, d, hour, min);
    }

    const localY = dateObj.getFullYear();
    const localM = String(dateObj.getMonth() + 1).padStart(2, '0');
    const localD = String(dateObj.getDate()).padStart(2, '0');
    const dateStr = `${localY}-${localM}-${localD}`;
    const timeStr = `${String(dateObj.getHours()).padStart(2, '0')}:${String(dateObj.getMinutes()).padStart(2, '0')}`;

    return { dateStr, timeStr, isAllDay: false, dateObj };
  }

  return { dateStr: null, timeStr: '', isAllDay: false, dateObj: null };
}

function unfoldIcs(content) {
  const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  const unfolded = [];
  for (const line of lines) {
    if ((line.startsWith(' ') || line.startsWith('\t')) && unfolded.length > 0) {
      unfolded[unfolded.length - 1] += line.slice(1);
    } else {
      unfolded.push(line);
    }
  }
  return unfolded;
}

function parseRrule(rruleStr) {
  const rule = {};
  for (const part of rruleStr.split(';')) {
    const [k, v] = part.split('=');
    if (k && v) rule[k.toUpperCase()] = v;
  }
  return rule;
}

function expandRecurringEvent(event, windowStart, windowEnd) {
  const rrule = event.rrule;
  if (!rrule) return [event];

  const rule = parseRrule(rrule);
  const freq = rule.FREQ;
  const interval = parseInt(rule.INTERVAL || '1', 10);
  let untilDate = null;
  if (rule.UNTIL) {
    const u = parseIcsDate(rule.UNTIL);
    if (u.dateObj) untilDate = u.dateObj;
  }
  const count = parseInt(rule.COUNT || '999', 10);
  const byday = rule.BYDAY ? rule.BYDAY.split(',') : [];

  const weekdayMap = { MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6, SU: 0 };
  const instances = [];
  let occurrences = 0;
  let curr = new Date(event.dateObj.getTime());
  let loops = 0;

  while (loops < 500) {
    loops++;
    if (untilDate && curr > untilDate) break;
    if (occurrences >= count) break;
    if (curr > windowEnd) break;

    if (freq === 'DAILY') {
      if (curr >= windowStart) {
        instances.push(cloneWithDate(event, curr));
      }
      occurrences++;
      curr.setDate(curr.getDate() + interval);
    } else if (freq === 'WEEKLY') {
      if (byday.length > 0) {
        // Find Monday of the current week
        const dayOfWeek = curr.getDay(); // 0 is Sun, 1 is Mon...
        const distToMon = (dayOfWeek + 6) % 7;
        const weekMon = new Date(curr.getTime());
        weekMon.setDate(weekMon.getDate() - distToMon);

        for (const code of byday) {
          const key = code.slice(-2).toUpperCase();
          if (weekdayMap[key] !== undefined) {
            const targetDayNum = weekdayMap[key];
            const distFromMon = (targetDayNum + 6) % 7;
            const instDate = new Date(weekMon.getTime());
            instDate.setDate(instDate.getDate() + distFromMon);

            if (instDate >= event.dateObj && (!untilDate || instDate <= untilDate)) {
              if (instDate >= windowStart && instDate <= windowEnd) {
                instances.push(cloneWithDate(event, instDate));
              }
              occurrences++;
              if (occurrences >= count) break;
            }
          }
        }
        curr.setDate(curr.getDate() + 7 * interval);
      } else {
        if (curr >= windowStart) {
          instances.push(cloneWithDate(event, curr));
        }
        occurrences++;
        curr.setDate(curr.getDate() + 7 * interval);
      }
    } else if (freq === 'MONTHLY') {
      if (curr >= windowStart) {
        instances.push(cloneWithDate(event, curr));
      }
      occurrences++;
      curr.setMonth(curr.getMonth() + interval);
    } else if (freq === 'YEARLY') {
      if (curr >= windowStart) {
        instances.push(cloneWithDate(event, curr));
      }
      occurrences++;
      curr.setFullYear(curr.getFullYear() + interval);
    } else {
      if (curr >= windowStart) {
        instances.push(cloneWithDate(event, curr));
      }
      break;
    }
  }

  return instances;
}

function cloneWithDate(ev, dateObj) {
  const y = dateObj.getFullYear();
  const m = String(dateObj.getMonth() + 1).padStart(2, '0');
  const d = String(dateObj.getDate()).padStart(2, '0');
  const res = {
    ...ev,
    date: `${y}-${m}-${d}`,
    dateObj: new Date(dateObj.getTime())
  };
  if (ev.dateObj && ev.endDateObj) {
    const duration = ev.endDateObj.getTime() - ev.dateObj.getTime();
    if (duration > 0) {
      const endObj = new Date(dateObj.getTime() + duration);
      const ey = endObj.getFullYear();
      const em = String(endObj.getMonth() + 1).padStart(2, '0');
      const ed = String(endObj.getDate()).padStart(2, '0');
      res.endDateObj = endObj;
      res.endDate = `${ey}-${em}-${ed}`;
    }
  }
  return res;
}

function getInclusiveDateRange(ev) {
  const startStr = ev.date;
  if (!startStr) return [];

  let lastStr = startStr;

  if (ev.isAllDay) {
    // All-day: DTEND is exclusive per RFC 5545 (e.g. 2026-08-12 to 2026-08-14 spans 12th and 13th)
    if (ev.endDate && ev.endDate > startStr) {
      const endParts = ev.endDate.split('-').map(Number);
      const d = new Date(endParts[0], endParts[1] - 1, endParts[2]);
      d.setDate(d.getDate() - 1);
      const y = d.getFullYear();
      const m = String(d.getMonth() + 1).padStart(2, '0');
      const dt = String(d.getDate()).padStart(2, '0');
      lastStr = `${y}-${m}-${dt}`;
      if (lastStr < startStr) lastStr = startStr;
    }
  } else {
    // Timed event
    if (ev.endDateObj && ev.endDate) {
      if (ev.endDateObj.getHours() === 0 && ev.endDateObj.getMinutes() === 0 && ev.endDateObj.getSeconds() === 0) {
        // Ends exactly at midnight -> last active day is day before
        const endParts = ev.endDate.split('-').map(Number);
        const d = new Date(endParts[0], endParts[1] - 1, endParts[2]);
        d.setDate(d.getDate() - 1);
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const dt = String(d.getDate()).padStart(2, '0');
        lastStr = `${y}-${m}-${dt}`;
        if (lastStr < startStr) lastStr = startStr;
      } else if (ev.endDate >= startStr) {
        lastStr = ev.endDate;
      }
    }
  }

  const days = [];
  const startParts = startStr.split('-').map(Number);
  const cur = new Date(startParts[0], startParts[1] - 1, startParts[2]);

  while (days.length < 366) {
    const y = cur.getFullYear();
    const m = String(cur.getMonth() + 1).padStart(2, '0');
    const d = String(cur.getDate()).padStart(2, '0');
    const curStr = `${y}-${m}-${d}`;
    days.push(curStr);
    if (curStr >= lastStr) break;
    cur.setDate(cur.getDate() + 1);
  }

  return days;
}

const PALETTE = [
  '#3b82f6', // Blue
  '#10b981', // Emerald
  '#f43f5e', // Rose
  '#a855f7', // Purple
  '#f59e0b', // Amber
  '#06b6d4', // Cyan
  '#ec4899', // Fuchsia
  '#6366f1'  // Indigo
];

function extractCalendarName(content) {
  const match = content.match(/X-WR-CALNAME:(.*)/i);
  if (match && match[1]) {
    return unescapeIcs(match[1].trim());
  }
  return '';
}

function parseIcs(content, calInfo) {
  const lines = unfoldIcs(content);
  const rawEvents = [];
  let current = null;

  const now = new Date();
  const windowStart = new Date(now.getFullYear(), now.getMonth() - 3, 1);
  const windowEnd = new Date(now.getFullYear(), now.getMonth() + 12, 28);

  for (let line of lines) {
    line = line.trim();
    if (!line) continue;

    if (line === 'BEGIN:VEVENT') {
      current = {
        calendar_id: calInfo ? calInfo.id : 0,
        calendar_name: calInfo ? calInfo.name : 'Calendar',
        calendar_color: calInfo ? calInfo.color : '#3b82f6'
      };
      continue;
    } else if (line === 'END:VEVENT') {
      if (current && current.dateObj && current.status !== 'CANCELLED') {
        if (!current.endDateObj && current.duration) {
          const durMatch = current.duration.match(/^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
          if (durMatch) {
            const weeks = parseInt(durMatch[1] || '0', 10);
            const days = parseInt(durMatch[2] || '0', 10);
            const hours = parseInt(durMatch[3] || '0', 10);
            const mins = parseInt(durMatch[4] || '0', 10);
            const secs = parseInt(durMatch[5] || '0', 10);
            const totalMs = (((weeks * 7 + days) * 24 + hours) * 60 + mins) * 60000 + secs * 1000;
            if (totalMs > 0) {
              const endObj = new Date(current.dateObj.getTime() + totalMs);
              current.endDateObj = endObj;
              const ey = endObj.getFullYear();
              const em = String(endObj.getMonth() + 1).padStart(2, '0');
              const ed = String(endObj.getDate()).padStart(2, '0');
              current.endDate = `${ey}-${em}-${ed}`;
              if (!current.isAllDay) {
                current.endTime = `${String(endObj.getHours()).padStart(2, '0')}:${String(endObj.getMinutes()).padStart(2, '0')}`;
              }
            }
          }
        }

        // Default all-day event duration to 1 day if DTEND is missing
        if (!current.endDate && current.isAllDay && current.date) {
          const parts = current.date.split('-').map(Number);
          const nextDay = new Date(parts[0], parts[1] - 1, parts[2] + 1);
          const ny = nextDay.getFullYear();
          const nm = String(nextDay.getMonth() + 1).padStart(2, '0');
          const nd = String(nextDay.getDate()).padStart(2, '0');
          current.endDate = `${ny}-${nm}-${nd}`;
          current.endDateObj = nextDay;
        }

        const effectiveEnd = current.endDateObj || current.dateObj;
        if (current.rrule) {
          const expanded = expandRecurringEvent(current, windowStart, windowEnd);
          rawEvents.push(...expanded);
        } else if (current.dateObj <= windowEnd && effectiveEnd >= windowStart) {
          rawEvents.push(current);
        }
      }
      current = null;
      continue;
    }

    if (!current) continue;

    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;

    const propHeader = line.slice(0, colonIdx);
    const propVal = line.slice(colonIdx + 1);
    const propName = propHeader.split(';')[0].toUpperCase();

    switch (propName) {
      case 'SUMMARY':
        current.title = unescapeIcs(propVal);
        break;
      case 'DTSTART': {
        const parsed = parseIcsDate(propVal);
        if (parsed.dateStr) {
          current.date = parsed.dateStr;
          current.startTime = parsed.timeStr;
          current.isAllDay = parsed.isAllDay;
          current.dateObj = parsed.dateObj;
        }
        break;
      }
      case 'DTEND': {
        const parsed = parseIcsDate(propVal);
        if (parsed.dateStr) {
          current.endDate = parsed.dateStr;
          current.endTime = parsed.timeStr;
          current.endIsAllDay = parsed.isAllDay;
          current.endDateObj = parsed.dateObj;
        }
        break;
      }
      case 'DURATION':
        current.duration = propVal.trim();
        break;
      case 'RRULE':
        current.rrule = propVal.trim();
        break;
      case 'LOCATION':
        current.location = unescapeIcs(propVal);
        break;
      case 'DESCRIPTION':
        current.description = unescapeIcs(propVal);
        break;
      case 'STATUS':
        current.status = propVal.trim().toUpperCase();
        break;
    }
  }

  return rawEvents;
}

async function main() {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });

  const calendarConfigs = [];
  if (process.argv[2] && (process.argv[2].startsWith('http') || fs.existsSync(process.argv[2]))) {
    calendarConfigs.push({
      id: 0,
      url: process.argv[2],
      color: PALETTE[0],
      customName: ''
    });
  } else if (fs.existsSync(CONFIG_FILE)) {
    const lines = fs.readFileSync(CONFIG_FILE, 'utf-8').split('\n');
    let idx = 0;
    for (let l of lines) {
      l = l.trim();
      if (!l || l.startsWith('#')) continue;
      const parts = l.split(/\s+/);
      const url = parts[0];
      if (!url.startsWith('http') && !url.startsWith('file://') && !fs.existsSync(url)) continue;

      let color = PALETTE[idx % PALETTE.length];
      let customName = '';
      if (parts.length > 1) {
        if (parts[1].startsWith('#')) {
          color = parts[1];
          if (parts.length > 2) customName = parts.slice(2).join(' ');
        } else {
          customName = parts.slice(1).join(' ');
        }
      }
      calendarConfigs.push({
        id: idx,
        url,
        color,
        customName
      });
      idx++;
    }
  }

  if (calendarConfigs.length === 0) {
    const res = {
      last_updated: Date.now(),
      has_url: false,
      error: 'No calendar URL configured in ~/.config/quickshell/calendar_url.txt',
      calendars: [],
      events_by_date: {},
      event_colors_by_date: {},
      upcoming: []
    };
    writeOutput(res);
    return;
  }

  const allRaw = [];
  const errors = [];
  const calendarList = [];

  for (const cfg of calendarConfigs) {
    try {
      let text = '';
      if (cfg.url.startsWith('http://') || cfg.url.startsWith('https://')) {
        const resp = await fetch(cfg.url, {
          headers: { 'User-Agent': 'Mozilla/5.0 (compatible; QuickshellCalendar/1.0)' },
          signal: AbortSignal.timeout(12000)
        });
        if (!resp.ok) {
          errors.push(`HTTP ${resp.status} fetching ${cfg.url.slice(0, 30)}...`);
          continue;
        }
        text = await resp.text();
      } else if (cfg.url.startsWith('file://')) {
        text = fs.readFileSync(cfg.url.replace('file://', ''), 'utf-8');
      } else if (fs.existsSync(cfg.url)) {
        text = fs.readFileSync(cfg.url, 'utf-8');
      } else {
        continue;
      }

      const detectedName = extractCalendarName(text);
      const calName = cfg.customName || detectedName || `Calendar ${cfg.id + 1}`;
      const calInfo = {
        id: cfg.id,
        name: calName,
        color: cfg.color
      };
      calendarList.push(calInfo);

      const parsed = parseIcs(text, calInfo);
      allRaw.push(...parsed);
    } catch (e) {
      errors.push(`Error fetching calendar: ${e.message}`);
    }
  }

  // Group by date YYYY-MM-DD
  const eventsByDate = {};
  const upcoming = [];

  const todayStr = new Date().toISOString().slice(0, 10);

  for (const ev of allRaw) {
    const spanDays = getInclusiveDateRange(ev);
    if (spanDays.length === 0) continue;

    const isMultiDay = spanDays.length > 1;
    const firstDay = spanDays[0];
    const lastDay = spanDays[spanDays.length - 1];

    for (const dayStr of spanDays) {
      const isFirst = (dayStr === firstDay);
      const isLast = (dayStr === lastDay);

      let timeDisplay = '';
      let isAllDayForDay = ev.isAllDay;

      if (ev.isAllDay) {
        timeDisplay = 'All Day';
      } else if (isMultiDay) {
        if (isFirst) {
          timeDisplay = ev.startTime ? `${ev.startTime} →` : 'All Day';
        } else if (isLast) {
          timeDisplay = ev.endTime ? `→ ${ev.endTime}` : 'All Day';
        } else {
          timeDisplay = 'All Day';
          isAllDayForDay = true;
        }
      } else {
        timeDisplay = ev.startTime + (ev.endTime ? ` - ${ev.endTime}` : '');
      }

      const item = {
        title: ev.title || '(No title)',
        date: dayStr,
        start_date: firstDay,
        end_date: lastDay,
        start_time: ev.startTime || '',
        end_time: ev.endTime || '',
        time_display: timeDisplay,
        is_all_day: isAllDayForDay,
        is_multi_day: isMultiDay,
        calendar_id: ev.calendar_id !== undefined ? ev.calendar_id : 0,
        calendar_name: ev.calendar_name || '',
        calendar_color: ev.calendar_color || '#3b82f6',
        location: ev.location || '',
        description: ev.description || ''
      };

      if (!eventsByDate[dayStr]) {
        eventsByDate[dayStr] = [];
      }
      eventsByDate[dayStr].push(item);
    }

    // Add to upcoming once per event if it hasn't ended yet
    if (lastDay >= todayStr && upcoming.length < 30) {
      let upcomingTimeDisplay = '';
      if (ev.isAllDay) {
        upcomingTimeDisplay = 'All Day';
      } else if (isMultiDay) {
        upcomingTimeDisplay = `${ev.startTime || ''} → ${ev.endTime || ''}`.trim();
      } else {
        upcomingTimeDisplay = ev.startTime + (ev.endTime ? ` - ${ev.endTime}` : '');
      }

      upcoming.push({
        title: ev.title || '(No title)',
        date: firstDay,
        start_date: firstDay,
        end_date: lastDay,
        start_time: ev.startTime || '',
        end_time: ev.endTime || '',
        time_display: upcomingTimeDisplay,
        is_all_day: !!ev.isAllDay,
        is_multi_day: isMultiDay,
        calendar_id: ev.calendar_id !== undefined ? ev.calendar_id : 0,
        calendar_name: ev.calendar_name || '',
        calendar_color: ev.calendar_color || '#3b82f6',
        location: ev.location || '',
        description: ev.description || ''
      });
    }
  }

  // Sort events within each day: all-day / ongoing first, then chronological
  for (const d in eventsByDate) {
    eventsByDate[d].sort((a, b) => {
      if (a.is_all_day && !b.is_all_day) return -1;
      if (!a.is_all_day && b.is_all_day) return 1;
      return (a.start_time || '').localeCompare(b.start_time || '');
    });
  }

  // Collect distinct calendar colors per day for quick UI rendering of dots
  const eventColorsByDate = {};
  for (const date in eventsByDate) {
    const seen = new Set();
    const colors = [];
    for (const ev of eventsByDate[date]) {
      const c = ev.calendar_color || '#3b82f6';
      if (!seen.has(c)) {
        seen.add(c);
        colors.push(c);
      }
    }
    eventColorsByDate[date] = colors;
  }

  const result = {
    last_updated: Date.now(),
    has_url: true,
    error: errors.join('; '),
    calendars: calendarList,
    events_by_date: eventsByDate,
    event_colors_by_date: eventColorsByDate,
    upcoming: upcoming
  };

  writeOutput(result);
}

function writeOutput(data) {
  const tmp = OUTPUT_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2), 'utf-8');
  fs.renameSync(tmp, OUTPUT_FILE);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
