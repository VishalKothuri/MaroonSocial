// Hold incoming signaling until the media engine has finished its reset/start.
// An old permission prompt must never flush messages into a later conversation.
export class CallSignalBuffer {
  constructor(){this.reset();}
  reset(){this.version=(this.version||0)+1;this.items=[];this.seen=new Set();this.receive=null;this.chain=Promise.resolve();return this.version;}
  add(signal){
    if(this.seen.has(signal.id))return;
    if(this.items.length>=256)throw new Error('Too many pending call signals. End this conversation and try again.');
    this.seen.add(signal.id);this.items.push({type:signal.kind,payload:signal.payload});this.flush();
  }
  ready(version,receive){if(version!==this.version)return;this.receive=receive;this.flush();}
  flush(){
    if(!this.receive)return;
    const version=this.version,receive=this.receive,items=this.items.splice(0);
    this.chain=this.chain.then(async()=>{for(const item of items){if(version!==this.version)return;await receive(item);}});
  }
}
