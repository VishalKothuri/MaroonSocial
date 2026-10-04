#!/usr/bin/env python3
"""Install owner-provided APNs credentials without logging secrets or sending an alert."""
import argparse,json,os,pathlib,secrets,subprocess,tempfile,urllib.request,sys
p=argparse.ArgumentParser();p.add_argument('--key-file',required=True);p.add_argument('--key-id',required=True);p.add_argument('--team-id',default='259BRQX9UQ');p.add_argument('--topic',default='app.maroonsocial.MaroonSocial');p.add_argument('--project-ref',default='myxbghfbapbfffkpndwo');p.add_argument('--environments',choices=['sandbox','production','sandbox,production'],default='sandbox');p.add_argument('--install',action='store_true');a=p.parse_args()
path=pathlib.Path(a.key_file).expanduser();pem=path.read_text().strip()
if not pem.startswith('-----BEGIN PRIVATE KEY-----') or not pem.endswith('-----END PRIVATE KEY-----'):sys.exit('Choose the original Apple .p8 private-key file.')
if not all(v.isalnum() and len(v)==10 for v in [a.key_id,a.team_id]):sys.exit('Apple key and team identifiers must be ten characters.')
check=subprocess.run(['openssl','pkey','-in',str(path),'-noout','-check'],capture_output=True)
if check.returncode:sys.exit('The private-key file could not be validated.')
if not a.install:print('APNs key structure validated. Nothing uploaded; no notification sent. Add --install to install the owner-authorized credentials.');sys.exit(0)
worker=secrets.token_hex(32)
values={'APNS_TEAM_ID':a.team_id,'APNS_KEY_ID':a.key_id,'APNS_PRIVATE_KEY':pem,'APNS_TOPIC':a.topic,'PUSH_WORKER_SECRET':worker,'APNS_ALLOWED_ENVIRONMENTS':a.environments}
fd,name=tempfile.mkstemp(prefix='maroon-apns-',suffix='.env');os.chmod(name,0o600)
try:
 with os.fdopen(fd,'w')as f:
  for key,value in values.items():f.write(key+'='+json.dumps(value)+'\n')
 result=subprocess.run(['supabase','secrets','set','--project-ref',a.project_ref,'--env-file',name],capture_output=True)
 if result.returncode:sys.exit('Secret installation failed. No secret output was printed. Check the Supabase CLI login/project permissions.')
finally:os.unlink(name)
# Retrieve the service credential only in this process to install the fixed-name
# Vault worker secret. Never place it in argv, logs, the app or a persistent file.
result=subprocess.run(['supabase','projects','api-keys','--project-ref',a.project_ref,'--output','json'],capture_output=True)
if result.returncode:sys.exit('Edge secrets installed, but Vault setup needs a signed-in Supabase CLI. Re-run after CLI authentication; no credentials printed.')
try:
 keys=json.loads(result.stdout);service=next(x['api_key'] for x in keys if x.get('name')=='service_role')
 request=urllib.request.Request('https://'+a.project_ref+'.supabase.co/rest/v1/rpc/push_setup_worker',data=json.dumps({'p_secret':worker}).encode(),headers={'apikey':service,'Authorization':'Bearer '+service,'Content-Type':'application/json'})
 with urllib.request.urlopen(request,timeout=20)as response:assert json.load(response).get('configured')is True
except Exception:sys.exit('Edge secrets installed, but the fixed-name Vault worker setup failed. Re-run after the push_setup_worker migration is deployed. No credentials printed.')
print('APNs credentials and matching worker secret installed. No notification sent by this tool. Cron/authorized event hooks can now deliver eligible queued alerts; real-device delivery still needs verification.')
