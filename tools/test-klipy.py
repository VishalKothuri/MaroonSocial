#!/usr/bin/env python3
"""Small live provider + private-media regression. Never prints app keys or credentials.
No fabricated moderation reports, ad impressions/clicks, or provider share events.
All three temporary social accounts and their references are deleted in finally.
"""
import json,pathlib,urllib.request,urllib.error,urllib.parse,uuid,sys
import runner_backend
config=runner_backend.load()
key=json.loads(pathlib.Path('MaroonSocial/Resources/Klipy.json').read_text())['appKey'].strip()
assert key,'Save a KLIPY mobile app key first.'

def provider(category):
 params=urllib.parse.urlencode({'page':1,'per_page':8,'q':'hello','customer_id':'maroon-isolated-integration','locale':'us','content_filter':'high'})
 url='https://api.klipy.com/api/v1/'+urllib.parse.quote(key,safe='')+'/'+category+'/search?'+params
 try:
  with urllib.request.urlopen(urllib.request.Request(url,headers={'Accept':'application/json','User-Agent':'MaroonSocial/0.1 (iOS)'}),timeout=25)as r:data=json.load(r)
 except Exception as e:raise RuntimeError('Provider search failed; check app-key status and connection.')from None
 assert data['result']
 rows=data['data']['data'];print('PASS real',category,'search:',len(rows),'items;',sum(x.get('type')=='ad'for x in rows),'provider ads')
 for row in rows:
  if row.get('type')=='ad':continue
  for format in (['gif']if category=='gifs'else['png','jpg','jpeg']):
   f=row.get('file',{}).get('sm',{}).get(format)
   if f and 0<f.get('size',0)<=5000000:
    parsed=urllib.parse.urlparse(f['url']);assert parsed.scheme=='https'and parsed.hostname in['static.klipy.com','static1.klipy.com','static2.klipy.com']
    with urllib.request.urlopen(urllib.request.Request(f['url'],headers={'User-Agent':'MaroonSocial/0.1 (iOS)'}),timeout=25)as r:media=r.read(5000001)
    assert 0<len(media)<=5000000
    assert media.startswith((b'GIF87a',b'GIF89a',b'\x89PNG',b'\xff\xd8'))
    print('PASS direct bounded',format,'media load:',len(media),'bytes (memory only)')
    return {'provider':'klipy','id':str(row['id']),'slug':row['slug'],'title':row['title'],'category':category,'kind':'gif'if format=='gif'else'image','mime':'image/gif'if format=='gif'else'image/png'if format=='png'else'image/jpeg','url':f['url'],'previewURL':f['url'],'size':f['size']}
 raise AssertionError('No compatible provider result')

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

references=[provider('static-memes'),provider('gifs')]
accounts=[];label='klipy_'+uuid.uuid4().hex[:10]
try:
 for suffix in['a','b','c']:accounts.append(ok('register',username=label+suffix,adult=True)['token'])
 a,b,c=accounts
 room=ok('dm.request',a,username=label+'b',text='Temporary KLIPY integration check')['resource_id']
 ok('dm.accept',b,room_id=room)
 ref=references[1];nonce=str(uuid.uuid4())
 payload=dict(room_id=room,reference=ref,nonce=nonce)
 attachment=ok('attachment.external',a,**payload)['attachment_id']
 assert ok('attachment.external',a,**payload)['attachment_id']==attachment
 assert call('attachment.read',b,attachment_id=attachment)[0]==403
 ok('room.send',a,room_id=room,text='Temporary GIF reference',attachment_id=attachment,nonce=str(uuid.uuid4()))
 assert ok('attachment.read',b,attachment_id=attachment)['external_media']==ref
 assert call('attachment.read',c,attachment_id=attachment)[0]==403
 assert call('attachment.external',c,**payload)[0]==403
 print('PASS shared GIF reference, exact original URL, private unsent draft, accepted peer, outsider denial, retry idempotency')
 post=ok('post.create',a,text='Temporary KLIPY meme reference check',community='Texas A&M',anonymous=True)['resource_id']
 image=ok('attachment.external',a,post_id=post,reference=references[0],nonce=str(uuid.uuid4()))['attachment_id']
 assert ok('attachment.read',c,attachment_id=image)['external_media']==references[0]
 ok('post.delete',a,post_id=post)
 assert call('attachment.read',c,attachment_id=image)[0]==403
 ok('block',b,room_id=room)
 assert call('attachment.read',b,attachment_id=attachment)[0]==403
 print('PASS real meme post reference, deleted post denial, blocked conversation denial')
finally:
 failures=0
 for token in accounts:
  try:ok('account.delete',token)
  except Exception:failures+=1
 if failures:raise RuntimeError('Temporary account cleanup needs operator attention ('+str(failures)+')')
 print('PASS deleted all temporary social accounts and media references')
