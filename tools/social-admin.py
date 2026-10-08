#!/usr/bin/env python3
"""Private DB-operator moderation via Supabase Management API. No app credential grants admin access."""
import argparse,hashlib,json,os,re,sys,urllib.request,urllib.error

def sql_literal(value):return "'"+value.replace("'","''")+"'"
def filter_hash(term):
 # The server compares lowercase runs of letters and digits; a term must be exactly one such word.
 words=[w for w in re.split(r'[\W_]+',term.lower())if w]
 if len(words)!=1:sys.exit('Give exactly one word (letters and digits only).')
 return hashlib.sha256(words[0].encode()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--project-ref',default='myxbghfbapbfffkpndwo');p.add_argument('--execute',action='store_true',help='Execute using SUPABASE_ACCESS_TOKEN; otherwise print reviewable SQL for the DB connector')
 p.add_argument('--reviewer',default='');sub=p.add_subparsers(dest='command',required=True)
 for name in['reports','organizations']:
  q=sub.add_parser(name);q.add_argument('--status',default='pending')
 sub.add_parser('announcements')
 q=sub.add_parser('publish-announcement');q.add_argument('--title',required=True);q.add_argument('--body',required=True);q.add_argument('--note',required=True)
 q=sub.add_parser('withdraw-announcement');q.add_argument('id');q.add_argument('--note',required=True)
 sub.add_parser('audit');sub.add_parser('pending-media-deletions')
 q=sub.add_parser('review-report');q.add_argument('id');q.add_argument('decision',choices=['resolved','dismissed','remove']);q.add_argument('--note',required=True)
 q=sub.add_parser('review-organization');q.add_argument('id');q.add_argument('decision',choices=['verified','declined','suspended']);q.add_argument('--note',required=True);q.add_argument('--evidence-checked',action='store_true')
 q=sub.add_parser('suspend');group=q.add_mutually_exclusive_group(required=True);group.add_argument('--username');group.add_argument('--report-id');q.add_argument('--note',required=True)
 q=sub.add_parser('set-topic',help='Set or clear a post topic (slug, or "null")');q.add_argument('post_id');q.add_argument('topic');q.add_argument('--note',required=True)
 for name in['disable-topic','enable-topic']:
  q=sub.add_parser(name);q.add_argument('slug');q.add_argument('--note',required=True)
 for name in['add-filter-word','remove-filter-word']:
  # The word is read from stdin, hashed here and never printed or sent in plain text.
  q=sub.add_parser(name,help='Reads one word from stdin; only its sha256 hash is sent');q.add_argument('--note',required=True)
 q=sub.add_parser('require-guidelines',help='Set the community guidelines version members must accept before posting, replying or messaging');q.add_argument('version',type=int);q.add_argument('--note',required=True)
 switch=q.add_mutually_exclusive_group();switch.add_argument('--enforce',dest='enforced',action='store_true');switch.add_argument('--no-enforce',dest='enforced',action='store_false');q.set_defaults(enforced=None)
 a=p.parse_args();payload={}
 if a.command in['reports','organizations']:action=a.command+'.list';payload['status']=a.status
 elif a.command=='announcements':action='announcements.list'
 elif a.command=='publish-announcement':action='announcements.publish';payload=dict(title=a.title,body=a.body,note=a.note)
 elif a.command=='withdraw-announcement':action='announcements.withdraw';payload=dict(id=a.id,note=a.note)
 elif a.command=='audit':action='audit.list'
 elif a.command=='pending-media-deletions':action='storage.list'
 elif a.command=='review-report':action='reports.review';payload=dict(id=a.id,decision=a.decision,note=a.note)
 elif a.command=='review-organization':action='organizations.review';payload=dict(id=a.id,decision=a.decision,note=a.note,evidence_checked=a.evidence_checked)
 elif a.command=='set-topic':action='topic.set';payload=dict(post_id=a.post_id,topic=None if a.topic=='null' else a.topic,note=a.note)
 elif a.command in['disable-topic','enable-topic']:action='topic.'+a.command.split('-')[0];payload=dict(slug=a.slug,note=a.note)
 elif a.command in['add-filter-word','remove-filter-word']:action='filter.'+a.command.split('-')[0];payload=dict(hash=filter_hash(sys.stdin.readline().strip()),note=a.note)
 elif a.command=='require-guidelines':
  action='guidelines.require';payload=dict(version=a.version,note=a.note)
  if a.enforced is not None:payload['enforced']=a.enforced
 else:action='members.suspend';payload={'note':a.note};payload.update({'username':a.username}if a.username else{'report_id':a.report_id})
 changing=not action.endswith('.list')
 if changing and len(a.reviewer.strip())<3:p.error('Mutations require --reviewer before the command')
 if not re.fullmatch('[a-z0-9]{20}',a.project_ref):p.error('Invalid project ref')
 query='select social_private.operator('+sql_literal(action)+','+sql_literal(json.dumps(payload))+"::jsonb,"+sql_literal(a.reviewer)+') as result;'
 if not a.execute:print(query);return
 token=os.environ.get('SUPABASE_ACCESS_TOKEN')
 if not token:sys.exit('Set SUPABASE_ACCESS_TOKEN privately for the authorized project operator, or run the printed SQL through the existing Supabase database connector. Never put this credential in the app.')
 request=urllib.request.Request('https://api.supabase.com/v1/projects/'+a.project_ref+'/database/query',data=json.dumps({'query':query,'read_only':not changing}).encode(),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},method='POST')
 try:
  with urllib.request.urlopen(request,timeout=30)as response:print(json.dumps(json.load(response),indent=2))
 except urllib.error.HTTPError as error:sys.exit('Operator API rejected the request (HTTP '+str(error.code)+'). Check project permissions and the review inputs; credentials were not printed.')
if __name__=='__main__':main()
