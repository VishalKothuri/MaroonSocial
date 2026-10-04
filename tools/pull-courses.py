#!/usr/bin/env python3
"""Refresh the bundled official catalog without creating any chat rooms.

Only course codes/titles and source URLs are retained. Full descriptions are not
copied. A failed or incomplete crawl never replaces the last complete catalog.
"""
import concurrent.futures
import datetime
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BASE = 'https://catalog.tamu.edu'
CACHE = ROOT / 'build/course-catalog-cache'
OUTPUT = ROOT / 'MaroonSocial/Resources/CourseCatalog.json'


class Headings(HTMLParser):
    def __init__(self):
        super().__init__()
        self.capturing = False
        self.value = []
        self.titles = []

    def handle_starttag(self, tag, attrs):
        if tag == 'h2' and 'courseblocktitle' in dict(attrs).get('class', '').split():
            self.capturing = True
            self.value = []

    def handle_data(self, value):
        if self.capturing:
            self.value.append(value)

    def handle_endtag(self, tag):
        if tag == 'h2' and self.capturing:
            self.titles.append(' '.join(''.join(self.value).split()))
            self.capturing = False


def parse_courses(document, url, level):
    parser = Headings()
    parser.feed(document)
    result = []
    for title in parser.titles:
        match = re.match(r'^((?:[A-Z]{2,5}\s+\d{3,4}[A-Z]?)(?:\s*/\s*[A-Z]{2,5}\s+\d{3,4}[A-Z]?)*)(?:\s+(.*))?$', title)
        if not match:
            raise ValueError(f'Unrecognized course heading at {url}: {title}')
        # The catalog lists cross-listed aliases in one heading. Every code is
        # searchable, but joining still uses the selected official course code.
        for subject, number in re.findall(r'([A-Z]{2,5})\s+(\d{3,4}[A-Z]?)', match[1]):
            result.append({'code': f'{subject} {number}', 'title': match[2] or '', 'levels': [level], 'sourceURL': url})
    # Some official subject pages are intentionally empty; they create no entries.
    return result


def fetch(path):
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = CACHE / (path.strip('/').replace('/', '_') + '.html')
    if cached.exists() and time.time() - cached.stat().st_mtime < 86400:
        return cached.read_text()
    request = urllib.request.Request(BASE + path, headers={'User-Agent': 'MaroonSocial-Catalog/1.0 (course title index; maroonsocial.chat)'})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=35) as response:
                body = response.read().decode('utf-8')
            cached.write_text(body)
            return body
        except Exception:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def main():
    pages = []
    editions = set()
    for level in ['undergraduate', 'graduate']:
        path = f'/{level}/course-descriptions/'
        document = fetch(path)
        edition = re.search(r'(20\d\d-20\d\d) Edition', document)
        if edition:
            editions.add(edition[1])
        links = sorted(set(re.findall(r'href="(/' + level + r'/course-descriptions/[a-z0-9-]+/)"', document)))
        if len(links) < 100:
            raise ValueError(f'Incomplete {level} subject index: {len(links)} pages')
        pages.extend((link, level.capitalize()) for link in links)
    courses = {}
    def read_page(item):
        path, level = item
        return parse_courses(fetch(path), BASE + path, level)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for index, rows in enumerate(pool.map(read_page, pages), 1):
            for row in rows:
                existing = courses.get(row['code'])
                if existing:
                    existing['levels'] = sorted(set(existing['levels'] + row['levels']))
                else:
                    courses[row['code']] = row
            if index % 50 == 0:
                print(f'Read {index}/{len(pages)} subject pages', flush=True)
    if len(courses) < 5000 or len(editions) != 1:
        raise ValueError('Catalog validation failed; the previous file is preserved.')
    payload = {'edition': next(iter(editions)), 'fetchedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'sourcePages': len(pages), 'courses': sorted(courses.values(), key=lambda row: row['code'])}
    temporary = OUTPUT.with_suffix('.tmp')
    temporary.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')) + '\n')
    temporary.replace(OUTPUT)
    print(f'Saved {len(courses)} official course codes from {len(pages)} pages. No rooms created.', flush=True)


if __name__ == '__main__':
    main()
