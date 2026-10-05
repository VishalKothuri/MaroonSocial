#!/usr/bin/env python3
"""Live shared-meme library regression against the deployed social function.
Registers two temporary accounts, shares a tiny generated PNG, reads it back as
the other account, checks ownership and reporting rules, and deletes both
accounts in finally. Never prints keys or credentials.
"""
import base64,json,pathlib,struct,urllib.request,urllib.error,uuid,zlib
config=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text())

def png(width=24,height=16,rgb=(80,0,0)):
 raw=b''.join(b'\x00'+bytes(rgb)*width for _ in range(height))
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')

def call(action,token=None,**payload):
 headers={'Content-Type':'application/json','apikey':config['publishableKey']}
 if token:headers['X-Social-Token']=token
 request=urllib.request.Request(config['url']+'/functions/v1/social',data=json.dumps(dict(action=action,**payload)).encode(),headers=headers)
 try:
  with urllib.request.urlopen(request,timeout=40)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)

def ok(action,token=None,**payload):
 status,data=call(action,token,**payload)
 assert status==200,(action,status,data.get('code'),data.get('error'))
 return data

accounts=[];label='meme_'+uuid.uuid4().hex[:10]
try:
 for suffix in['a','b']:accounts.append(ok('register',username=label+suffix,adult=True)['token'])
 a,b=accounts
 picture=png()
 shared=ok('meme.publish',a,data=base64.b64encode(picture).decode(),title='Synthetic maroon test '+label)
 meme=shared['meme_id'];assert shared['meme']['mime']=='image/png' and shared['meme']['width']==24
 print('PASS shared a generated PNG meme (no faces, no personal data)')
 listed=ok('meme.list',b,query=label)
 rows=listed['memes'];assert [r['id']for r in rows]==[meme],rows
 assert 'owner' not in rows[0] and 'path' not in rows[0],'List must not expose who shared a meme or where it is stored'
 assert ok('meme.list',b,page=1)['memes'][0]['id']==meme
 content=ok('meme.read',b,meme_id=meme)
 assert content['mime']=='image/png' and base64.b64decode(content['media_data']).startswith(b'\x89PNG')
 print('PASS another member listed, searched and read the shared meme without any owner identity')
 status,data=call('meme.publish',a,data=base64.b64encode(b'GIF89a'+b'\x00'*32).decode());assert status==400,(status,data)
 status,data=call('meme.remove',b,meme_id=meme);assert status==403,(status,data)
 reported=ok('meme.report',b,meme_id=meme,reason='Synthetic report from the library test')
 assert reported['ok'] and not reported['removed'],'One report must not remove a meme'
 assert ok('meme.read',b,meme_id=meme)['meme_id']==meme
 status,data=call('meme.report',a,meme_id=meme);assert status==400,'Owners remove instead of reporting'
 print('PASS invalid uploads rejected, non-owner removal denied, single report keeps the meme visible')
 removed=ok('meme.remove',a,meme_id=meme);assert removed['ok']
 status,data=call('meme.read',b,meme_id=meme);assert status==404,(status,data)
 assert ok('meme.list',b,query=label)['memes']==[]
 print('PASS owner removal hides the meme from reads and listings')
finally:
 failures=0
 for token in accounts:
  try:ok('account.delete',token)
  except Exception:failures+=1
 if failures:raise RuntimeError('Temporary account cleanup needs operator attention ('+str(failures)+')')
 print('PASS deleted both temporary social accounts')
