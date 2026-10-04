#!/usr/bin/env python3
"""Private DB-operator moderation via Supabase Management API. No app credential grants admin access."""
import argparse,json,os,re,sys,urllib.request,urllib.error

def sql_literal(value):return "'"+value.replace("'","''")+"'"
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
 a=p.parse_args();payload={}
 if a.command in['reports','organizations']:action=a.command+'.list';payload['status']=a.status
 elif a.command=='announcements':action='announcements.list'
 elif a.command=='publish-announcement':action='announcements.publish';payload=dict(title=a.title,body=a.body,note=a.note)
 elif a.command=='withdraw-announcement':action='announcements.withdraw';payload=dict(id=a.id,note=a.note)
 elif a.command=='audit':action='audit.list'
 elif a.command=='pending-media-deletions':action='storage.list'
 elif a.command=='review-report':action='reports.review';payload=dict(id=a.id,decision=a.decision,note=a.note)
 elif a.command=='review-organization':action='organizations.review';payload=dict(id=a.id,decision=a.decision,note=a.note,evidence_checked=a.evidence_checked)
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
