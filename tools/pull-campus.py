#!/usr/bin/env python3
"""Normalize official public feeds. No student data, contact emails or analytics fields."""
import json,urllib.request,html,re,time,pathlib,datetime
ROOT=pathlib.Path(__file__).resolve().parent.parent
SOURCES=[('Campus','https://calendar.tamu.edu/live/json/events/group/*%20Main%20University%20Calendar'),('Rec','https://calendar.tamu.edu/live/json/events/group/Rec%20Sports'),('Sports','https://calendar.tamu.edu/live/json/events/group/Aggie%20Athletics')]
def fetch(url):
    req=urllib.request.Request(url,headers={'User-Agent':'MaroonSocial/0.1 (public campus calendar preview)'})
    with urllib.request.urlopen(req,timeout=30) as r:return json.load(r)
def clean(value):return html.unescape(re.sub('<[^>]+>',' ',str(value or ''))).strip()
def feed_flag(value):return value is True or value == 1 or value in ('1','true')
def cancelled_title(title):return bool(re.search(r'(?:^\s*cancel(?:l)?ed(?:\s*[:–—-]|\s*$)|[\[(]\s*cancel(?:l)?ed\s*[\])]|[–—-]\s*cancel(?:l)?ed\s*$)',title,re.I))
def main():
    stamp=time.time(); events={};errors=[]
    for category,url in SOURCES:
        try:
            for row in fetch(url):
                starts=float(row['date_ts'])
                if not stamp-86400 <= starts <= stamp+31*86400:continue
                eid=f"{row['id']}-{int(starts)}"
                title=clean(row['title'])
                e=dict(id=eid,title=title,category=category,starts=starts,allDay=feed_flag(row.get('is_all_day')),location=clean(row.get('location_title') or row.get('location')),details=clean(row.get('description'))[:1200],url=row['url'],source=url,fetchedAt=stamp,cancelled=feed_flag(row.get('is_canceled')) or feed_flag(row.get('is_cancelled')) or cancelled_title(title))
                if row.get('date2_ts'): e['ends']=float(row['date2_ts'])
                image=row.get('thumbnailURL')
                if isinstance(image,str) and image.startswith('https://'):e['imageURL']=image
                events[eid]=e
        except Exception as ex:errors.append(f'{category}: {ex}')
    routes=[dict(id=r['routeNumber'],name=r['routeName'],color='500000',stops=[]) for r in fetch('https://aggiespirit.ts.tamu.edu/News/GetRoutes')]
    stops={s['stopCode']:dict(id=s['stopCode'],name=s['stopName'],latitude=s['latitude'],longitude=s['longitude']) for s in fetch('https://aggiespirit.ts.tamu.edu/Home/GetAllBusStops')}
    if not events:raise RuntimeError('All calendar feeds failed; existing snapshot preserved')
    result=dict(events=sorted(events.values(),key=lambda e:e['starts']),routes=routes,stops=list(stops.values()),fetchedAt=stamp)
    out=ROOT/'MaroonSocial/Resources/campus-data.json';out.write_text(json.dumps(result,separators=(',',':')))
    print(json.dumps({'events':len(events),'routes':len(routes),'stops':len(stops),'fetchedAt':datetime.datetime.fromtimestamp(stamp,datetime.timezone.utc).isoformat(),'warnings':errors}))
if __name__=='__main__':main()
