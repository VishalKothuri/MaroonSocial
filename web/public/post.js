// Shared post landing page, served for /p/<post id> (rewrite in vercel.json). The page never shows
// post content: posts open only for members, in the app. The button opens the app through the
// custom scheme; once the owner enables Associated Domains, iOS opens /p/* links in the app directly.
const POST_PATH=/^\/p\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/?$/i;
function appLinkFor(pathname){
 const match=POST_PATH.exec(pathname||'');
 return match?'maroonsocial://post/'+match[1].toLowerCase():null;
}
const appLink=appLinkFor(window.location.pathname);
const open=document.getElementById('open-app');
const invalid=document.getElementById('invalid-link');
if(appLink){open.href=appLink;open.hidden=false;invalid.hidden=true}
else{open.hidden=true;open.removeAttribute('href');invalid.hidden=false}
