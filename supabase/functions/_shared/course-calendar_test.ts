import { OFFICIAL_COURSE_CALENDAR_URL, parseCourseCalendar, refreshCourseCalendar, type CourseCalendarDB } from './course-calendar.ts';
const fixture = await Deno.readTextFile(new URL('./fixtures/course-calendar-2026-10-03.html', import.meta.url));
function assert(value: unknown, message = 'Assertion failed'): asserts value { if (!value) throw new Error(message); }
function equal(actual: unknown, expected: unknown) { assert(JSON.stringify(actual) === JSON.stringify(expected), `Expected ${JSON.stringify(expected)}; got ${JSON.stringify(actual)}`); }
const wrap = (contents: string) => `<h2>Texas A&amp;M University and Texas A&amp;M University at Galveston Calendar</h2>${contents}`;
const section = (title: string, date: string, event = 'Final examinations for all students.') => `<h3>${title}</h3><table class="tbl_academiccalendar"><tr><td>${date}</td><td>${event}</td></tr></table>`;
const htmlResponse = (html: string) => new Response(html, {headers: {'Content-Type':'text/html; charset=utf-8'}});
const mockFetch = (handler: (input: string | URL | Request, init?: RequestInit) => Response | Promise<Response>): typeof fetch => handler as typeof fetch;

Deno.test('actual official HTML yields four general terms and exact last exam dates', () => {
  const terms = parseCourseCalendar(fixture);
  equal(terms.map(t => [t.id,t.endsOn]), [['Summer 2026','2026-08-06'],['Fall 2026','2026-12-10'],['Spring 2027','2027-05-11'],['Summer 2027','2027-08-11']]);
  for (const term of terms) {
    equal(term.verified, true); equal(term.endBasis, 'last_final_exam'); equal(term.sourceURL, OFFICIAL_COURSE_CALENDAR_URL);
    assert(!('closesAt' in term) && !('purgeAt' in term), 'Database derives lifecycle timestamps');
  }
});
Deno.test('current catalog facts match independently verified bundled known terms', async () => {
  const bundle = JSON.parse(await Deno.readTextFile(new URL('../../../MaroonSocial/Resources/CourseTerms.json', import.meta.url)));
  for (const parsed of parseCourseCalendar(fixture)) {
    const cached = bundle.terms.find((t: {id: string}) => t.id === parsed.id);
    equal(parsed.endsOn, cached.endsOn);
    equal(parsed.sourceSection, cached.sourceSection);
  }
});
Deno.test('summer requires all sessions and chooses maximum even when Term II ends last', () => {
  const one = section('2027 Summer Term I','July 5');
  const two = section('2027 Summer Term II','August 13');
  const ten = section('2027 10-Week Summer Semester','August 10-11');
  equal(parseCourseCalendar(wrap(one + ten)), []);
  equal(parseCourseCalendar(wrap(one + two)), []);
  equal(parseCourseCalendar(wrap(one + two + ten)).map(t => [t.endsOn,t.sourceSection]), [['2027-08-13','2027 Summer Term II']]);
});
Deno.test('Dentistry and Qatar sections cannot introduce or override general terms', () => {
  const html = wrap(section('2026 Fall Semester','December 7-10')) + '<h2>College of Dentistry (Dental Hygiene) Calendar</h2>' + section('2026 Fall Semester','November 1') + '<h2>Texas A&amp;M University at Qatar Calendar</h2>' + section('2027 Spring Semester','April 1');
  equal(parseCourseCalendar(html).map(t => [t.id,t.endsOn]), [['Fall 2026','2026-12-10']]);
  equal(parseCourseCalendar('<h2>Texas A&amp;M University at Qatar Calendar</h2>' + section('2027 Spring Semester','May 1')), []);
  equal(parseCourseCalendar(section('2027 Spring Semester','May 1')), []);
  equal(parseCourseCalendar(wrap('<h3>College of Dentistry Calendar</h3>' + section('2027 Spring Semester','May 1'))), []);
});
Deno.test('DC-only exams, exam-week prose and final grades cannot determine the end', () => {
  const table = '<h3>2027 Spring Semester</h3><table class="tbl_academiccalendar"><tr><td>May 1</td><td>Spring final examinations for all students.</td></tr><tr><td>May 20</td><td>Bush School Washington, D.C. site final examinations.</td></tr><tr><td>May 25</td><td>Pursuant to Student Rule 8.3, no examinations during the week final exams start.</td></tr><tr><td>May 30</td><td>Final grades due.</td></tr></table>';
  equal(parseCourseCalendar(wrap(table))[0].endsOn, '2027-05-01');
  equal(parseCourseCalendar(wrap(section('2027 Spring Semester','May 20','Bush School Washington, D.C. site final examinations.'))), []);
});
Deno.test('missing dates, impossible dates, reversed lists and ambiguous headings preserve terms', () => {
  for (const date of ['', 'TBA', 'May 35', 'May 12-6', 'May 10, 6', 'July 1', 'May 5 or 8']) {
    equal(parseCourseCalendar(wrap(section('2027 Spring Semester',date))), []);
  }
  equal(parseCourseCalendar(wrap(section('2027 Spring Semester','May 6') + section('2027 Spring Semester','May 8'))), []);
  equal(parseCourseCalendar(wrap(section('2027 Spring Semester','May 6')) + wrap(section('2027 Spring Semester','May 8'))), []);
  equal(parseCourseCalendar(wrap(section('2027 Spring Semester','May 6')), 'https://untrusted.example/calendar'), []);
});
Deno.test('date lists, month ranges, nonbreaking spans and carried table dates parse explicitly', () => {
  equal(parseCourseCalendar(wrap(section('2027 Spring Semester','April 30-May 2, 5-6')))[0].endsOn, '2027-05-06');
  const carried = '<h3><span>2027&nbsp;</span><span>Spring Semester</span></h3><table class="tbl_academiccalendar"><tr><td>May 6&#8211;7, 10&#8211;11</td><td>Thursday-Friday.</td></tr><tr><td></td><td>Spring semester final examinations for all students.</td></tr></table>';
  equal(parseCourseCalendar(wrap(carried))[0].endsOn, '2027-05-11');
});
Deno.test('no dates or foreign-campus-only page never invokes ingest', async () => {
  for (const html of ['', '<h2>Qatar Calendar</h2>'+section('2027 Spring Semester','May 4'), wrap(section('2027 Spring Semester','TBA'))]) {
    const calls: string[] = [];
    const db: CourseCalendarDB = (path) => {calls.push(path); return Promise.resolve(Response.json(true));};
    equal(await refreshCourseCalendar(db, mockFetch(() => htmlResponse(html))), {status:'preserved',terms:0});
    equal(calls, ['rpc/claim_course_calendar_refresh']);
  }
});
Deno.test('daily database claim prevents source fetch and writes when already refreshed', async () => {
  const db: CourseCalendarDB = (path) => {equal(path,'rpc/claim_course_calendar_refresh'); return Promise.resolve(Response.json(false));};
  equal(await refreshCourseCalendar(db, mockFetch(() => {throw new Error('Must not fetch')})), {status:'cached',terms:0});
});
Deno.test('refresh submits only verified official terms using service RPC', async () => {
  const calls: string[] = [];
  const db: CourseCalendarDB = (path, init) => {
    calls.push(path);
    equal(init?.method, 'POST');
    if (path.endsWith('ingest')) {
      const payload = JSON.parse(String(init?.body));
      equal(payload.p_terms, parseCourseCalendar(fixture));
      return Promise.resolve(Response.json({updated:payload.p_terms.length}));
    }
    return Promise.resolve(Response.json(true));
  };
  const fetcher = mockFetch((input, init) => {equal(input, OFFICIAL_COURSE_CALENDAR_URL);equal(init?.redirect,'error'); return htmlResponse(fixture);});
  equal(await refreshCourseCalendar(db,fetcher), {status:'refreshed',terms:4});
  equal(calls,['rpc/claim_course_calendar_refresh','rpc/course_calendar_ingest']);
});
Deno.test('fetch failure, non-HTML and rejected ingest preserve existing data', async () => {
  for (const fetcher of [mockFetch(() => {throw new Error('Source unavailable')}),mockFetch(() => Response.json({error:'maintenance'})),mockFetch(() => new Response('Unavailable',{status:503}))]) {
    const calls: string[] = [];
    const db: CourseCalendarDB = (path) => {calls.push(path);return Promise.resolve(Response.json(true));};
    equal(await refreshCourseCalendar(db,fetcher),{status:'preserved',terms:0});
    equal(calls,['rpc/claim_course_calendar_refresh']);
  }
  const db: CourseCalendarDB = path => Promise.resolve(Response.json(path.endsWith('ingest') ? {error:'Unverified source'} : true));
  equal(await refreshCourseCalendar(db,mockFetch(() => htmlResponse(fixture))),{status:'preserved',terms:0});
});
