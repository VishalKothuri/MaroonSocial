/** Public university dates only. Missing or ambiguous terms never replace stored dates. */
export const OFFICIAL_COURSE_CALENDAR_URL = 'https://catalog.tamu.edu/undergraduate/academic-calendar/';
export interface CourseCalendarTerm {
  id: string;
  season: 'Spring' | 'Summer' | 'Fall';
  year: number;
  endsOn: string;
  sourceURL: string;
  endBasis: 'last_final_exam';
  sourceSection: string;
  verified: true;
}
const GENERAL_HEADING = 'Texas A&M University and Texas A&M University at Galveston Calendar';
const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const MONTH = '(' + MONTHS.join('|') + ')';
const GROUP = new RegExp('^(?:' + MONTH + '\\s+)?(\\d{1,2})(?:\\s*-\\s*(?:' + MONTH + '\\s+)?(\\d{1,2}))?$', 'i');
const MAX_HTML = 2_000_000;
const text = (html: string) => html.replace(/<[^>]*>/g, '').replace(/&(?:amp|nbsp|ndash|mdash|quot|apos);|&#(?:x[\da-f]+|\d+);/gi, entity => {
  const named: Record<string,string> = {'&amp;':'&','&nbsp;':' ','&ndash;':'-','&mdash;':'-','&quot;':'"','&apos;':"'"};
  if (named[entity.toLowerCase()] !== undefined) return named[entity.toLowerCase()];
  const hex = /^&#x/i.test(entity);
  const n = parseInt(entity.slice(hex ? 3 : 2, -1), hex ? 16 : 10);
  return n > 0 && n <= 0x10ffff ? String.fromCodePoint(n) : '';
}).replace(/[\u2010-\u2015]/g, '-').replace(/\s+/g, ' ').trim();

function dateString(year: number, month: number, day: number): string | null {
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day
    ? `${year}-${String(month).padStart(2,'0')}-${String(day).padStart(2,'0')}` : null;
}
/** Deliberately accepts calendar date lists, not free-text or JS date guessing. */
function finalDate(value: string, year: number, season: CourseCalendarTerm['season']): string | null {
  let month = 0;
  let previous = '';
  let end = '';
  for (const segment of value.split(',')) {
    const match = segment.trim().match(GROUP);
    if (!match) return null;
    if (match[1]) month = MONTHS.findIndex(m => m.toLowerCase() === match[1].toLowerCase()) + 1;
    if (!month) return null;
    const start = dateString(year, month, Number(match[2]));
    const endMonth = match[3] ? MONTHS.findIndex(m => m.toLowerCase() === match[3].toLowerCase()) + 1 : month;
    const stop = dateString(year, endMonth, Number(match[4] ?? match[2]));
    const allowed = season === 'Spring' ? [4,5,6] : season === 'Summer' ? [6,7,8] : [11,12];
    if (!start || !stop || stop < start || (previous && start < previous) || !allowed.includes(month) || !allowed.includes(endMonth)) return null;
    previous = stop; end = stop; month = endMonth;
  }
  return end || null;
}
interface Section { heading: string; season: CourseCalendarTerm['season']; year: number; session: string; end: string | null }
function readSection(heading: string, body: string): Section | null {
  const match = heading.match(/^(20\d{2}) (?:(Spring|Fall) Semester|(Summer Term I|Summer Term II|10-Week Summer Semester))$/);
  if (!match) return null;
  const year = Number(match[1]);
  const season = (match[2] ?? 'Summer') as CourseCalendarTerm['season'];
  const section: Section = {heading, season, year, session: match[3] ?? season, end: null};
  const tables = [...body.matchAll(/<table\b([^>]*)>([\s\S]*?)<\/table\s*>/gi)].filter(m => /\btbl_academiccalendar\b/.test(m[1]));
  if (tables.length !== 1) return section;
  let date = '';
  let candidate = '';
  for (const row of tables[0][2].matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr\s*>/gi)) {
    const cells = [...row[1].matchAll(/<td\b[^>]*>([\s\S]*?)<\/td\s*>/gi)].map(m => text(m[1]));
    if (cells.length !== 2) continue;
    if (cells[0]) date = cells[0];
    const event = cells[1];
    if (!/\bfinal (?:examinations|exams)(?:\s+for\b|\s*[.!;]|$)/i.test(event)) continue;
    // Some general-campus tables also contain Washington DC-only exams. Never use
    // those, professional-program deadlines, or prose mentioning the exam week.
    if (/\b(?:Bush School|Washington|Qatar|Dentistry|Dental|Nursing|Medicine|Law|School of|College of|professional|pursuant|deadline|schedule|cancelled|canceled)\b|\bno\s+final\b/i.test(event)) continue;
    const end = finalDate(date, year, season);
    if (!end) return section;
    if (end > candidate) candidate = end;
  }
  section.end = candidate || null;
  return section;
}

export function parseCourseCalendar(html: string, sourceURL = OFFICIAL_COURSE_CALENDAR_URL): CourseCalendarTerm[] {
  if (sourceURL !== OFFICIAL_COURSE_CALENDAR_URL || html.length > MAX_HTML) return [];
  const clean = html.replace(/<!--([\s\S]*?)-->/g, '').replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, '');
  const headings = [...clean.matchAll(/<h([1-6])\b[^>]*>([\s\S]*?)<\/h\1\s*>/gi)];
  let inGeneral = false;
  let generalCount = 0;
  const sections: Section[] = [];
  for (let i = 0; i < headings.length; i++) {
    const heading = headings[i];
    const title = text(heading[2]);
    const level = Number(heading[1]);
    if (level <= 2) {
      inGeneral = level === 2 && title === GENERAL_HEADING;
      if (inGeneral) generalCount++;
    } else if (inGeneral && level === 3) {
      const body = clean.slice(heading.index! + heading[0].length, headings[i+1]?.index ?? clean.length);
      const section = readSection(title, body);
      if (section) sections.push(section);
      // A newly introduced professional/program subsection must not inherit the
      // general-campus scope just because the publisher kept it at heading 3.
      else inGeneral = false;
    }
  }
  if (generalCount !== 1) return [];
  const groups = new Map<string, Section[]>();
  for (const section of sections) {
    const key = `${section.season} ${section.year}`;
    groups.set(key, [...(groups.get(key) ?? []), section]);
  }
  const result: CourseCalendarTerm[] = [];
  for (const [id, group] of groups) {
    // Summer closes after every published session, never after Term I alone.
    const expected = group[0].season === 'Summer' ? ['Summer Term I','Summer Term II','10-Week Summer Semester'] : [group[0].season];
    if (group.length !== expected.length || !expected.every(session => group.filter(s => s.session === session).length === 1) || group.some(s => !s.end)) continue;
    const last = [...group].sort((a,b) => b.end!.localeCompare(a.end!) || (a.session === '10-Week Summer Semester' ? -1 : 1))[0];
    result.push({id, season: last.season, year: last.year, endsOn: last.end!, sourceURL,
      endBasis: 'last_final_exam', sourceSection: last.heading, verified: true});
  }
  return result.sort((a,b) => a.endsOn.localeCompare(b.endsOn));
}

export type CourseCalendarDB = (path: string, init?: RequestInit) => Promise<Response>;
export type CourseCalendarRefresh = {status: 'refreshed' | 'cached' | 'preserved'; terms: number};
/** Call from the existing server-only refresh job; the database owns the daily lease. */
export async function refreshCourseCalendar(db: CourseCalendarDB, fetcher: typeof fetch = fetch): Promise<CourseCalendarRefresh> {
  try {
    const claim = await db('rpc/claim_course_calendar_refresh', {method: 'POST', body: '{}'});
    if (!claim.ok) return {status: 'preserved', terms: 0};
    const claimed: unknown = await claim.json();
    if (claimed === false) return {status: 'cached', terms: 0};
    if (claimed !== true) return {status: 'preserved', terms: 0};
    const response = await fetcher(OFFICIAL_COURSE_CALENDAR_URL, {redirect: 'error', signal: AbortSignal.timeout(20000), headers: {'Accept':'text/html'}});
    if (!response.ok || !/^text\/html\b/i.test(response.headers.get('content-type') ?? '') || Number(response.headers.get('content-length') ?? 0) > MAX_HTML) return {status: 'preserved', terms: 0};
    const html = await response.text();
    const terms = parseCourseCalendar(html);
    if (!terms.length) return {status: 'preserved', terms: 0};
    const saved = await db('rpc/course_calendar_ingest', {method: 'POST', body: JSON.stringify({p_terms: terms})});
    if (!saved.ok) return {status: 'preserved', terms: 0};
    const result = await saved.json();
    if (result && typeof result === 'object' && 'error' in result) return {status: 'preserved', terms: 0};
    return {status: 'refreshed', terms: terms.length};
  } catch {
    // A failed fetch/format change must not erase dates or trigger guessed purges.
    return {status: 'preserved', terms: 0};
  }
}
