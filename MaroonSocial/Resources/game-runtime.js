(()=>{var Kd=Object.create;var cu=Object.defineProperty;var Jd=Object.getOwnPropertyDescriptor;var jd=Object.getOwnPropertyNames;var Qd=Object.getPrototypeOf,ep=Object.prototype.hasOwnProperty;var tp=(r,e)=>()=>(e||r((e={exports:{}}).exports,e),e.exports);var np=(r,e,t,n)=>{if(e&&typeof e=="object"||typeof e=="function")for(let i of jd(e))!ep.call(r,i)&&i!==t&&cu(r,i,{get:()=>e[i],enumerable:!(n=Jd(e,i))||n.enumerable});return r};var rc=(r,e,t)=>(t=r!=null?Kd(Qd(r)):{},np(e||!r||!r.__esModule?cu(t,"default",{value:r,enumerable:!0}):t,r));var Ml=tp((ho,wh)=>{(function(e,t){typeof ho=="object"&&typeof wh=="object"?wh.exports=t():typeof define=="function"&&define.amd?define("Matter",[],t):typeof ho=="object"?ho.Matter=t():e.Matter=t()})(ho,function(){return(function(r){var e={};function t(n){if(e[n])return e[n].exports;var i=e[n]={i:n,l:!1,exports:{}};return r[n].call(i.exports,i,i.exports,t),i.l=!0,i.exports}return t.m=r,t.c=e,t.d=function(n,i,s){t.o(n,i)||Object.defineProperty(n,i,{enumerable:!0,get:s})},t.r=function(n){typeof Symbol<"u"&&Symbol.toStringTag&&Object.defineProperty(n,Symbol.toStringTag,{value:"Module"}),Object.defineProperty(n,"__esModule",{value:!0})},t.t=function(n,i){if(i&1&&(n=t(n)),i&8||i&4&&typeof n=="object"&&n&&n.__esModule)return n;var s=Object.create(null);if(t.r(s),Object.defineProperty(s,"default",{enumerable:!0,value:n}),i&2&&typeof n!="string")for(var o in n)t.d(s,o,(function(a){return n[a]}).bind(null,o));return s},t.n=function(n){var i=n&&n.__esModule?function(){return n.default}:function(){return n};return t.d(i,"a",i),i},t.o=function(n,i){return Object.prototype.hasOwnProperty.call(n,i)},t.p="",t(t.s=20)})([(function(r,e){var t={};r.exports=t,(function(){t._baseDelta=1e3/60,t._nextId=0,t._seed=0,t._nowStartTime=+new Date,t._warnedOnce={},t._decomp=null,t.extend=function(i,s){var o,a,l;typeof s=="boolean"?(o=2,l=s):(o=1,l=!0);for(var h=o;h<arguments.length;h++){var f=arguments[h];if(f)for(var c in f)l&&f[c]&&f[c].constructor===Object&&(!i[c]||i[c].constructor===Object)?(i[c]=i[c]||{},t.extend(i[c],l,f[c])):i[c]=f[c]}return i},t.clone=function(i,s){return t.extend({},s,i)},t.keys=function(i){if(Object.keys)return Object.keys(i);var s=[];for(var o in i)s.push(o);return s},t.values=function(i){var s=[];if(Object.keys){for(var o=Object.keys(i),a=0;a<o.length;a++)s.push(i[o[a]]);return s}for(var l in i)s.push(i[l]);return s},t.get=function(i,s,o,a){s=s.split(".").slice(o,a);for(var l=0;l<s.length;l+=1)i=i[s[l]];return i},t.set=function(i,s,o,a,l){var h=s.split(".").slice(a,l);return t.get(i,s,0,-1)[h[h.length-1]]=o,o},t.shuffle=function(i){for(var s=i.length-1;s>0;s--){var o=Math.floor(t.random()*(s+1)),a=i[s];i[s]=i[o],i[o]=a}return i},t.choose=function(i){return i[Math.floor(t.random()*i.length)]},t.isElement=function(i){return typeof HTMLElement<"u"?i instanceof HTMLElement:!!(i&&i.nodeType&&i.nodeName)},t.isArray=function(i){return Object.prototype.toString.call(i)==="[object Array]"},t.isFunction=function(i){return typeof i=="function"},t.isPlainObject=function(i){return typeof i=="object"&&i.constructor===Object},t.isString=function(i){return toString.call(i)==="[object String]"},t.clamp=function(i,s,o){return i<s?s:i>o?o:i},t.sign=function(i){return i<0?-1:1},t.now=function(){if(typeof window<"u"&&window.performance){if(window.performance.now)return window.performance.now();if(window.performance.webkitNow)return window.performance.webkitNow()}return Date.now?Date.now():new Date-t._nowStartTime},t.random=function(i,s){return i=typeof i<"u"?i:0,s=typeof s<"u"?s:1,i+n()*(s-i)};var n=function(){return t._seed=(t._seed*9301+49297)%233280,t._seed/233280};t.colorToNumber=function(i){return i=i.replace("#",""),i.length==3&&(i=i.charAt(0)+i.charAt(0)+i.charAt(1)+i.charAt(1)+i.charAt(2)+i.charAt(2)),parseInt(i,16)},t.logLevel=1,t.log=function(){console&&t.logLevel>0&&t.logLevel<=3&&console.log.apply(console,["matter-js:"].concat(Array.prototype.slice.call(arguments)))},t.info=function(){console&&t.logLevel>0&&t.logLevel<=2&&console.info.apply(console,["matter-js:"].concat(Array.prototype.slice.call(arguments)))},t.warn=function(){console&&t.logLevel>0&&t.logLevel<=3&&console.warn.apply(console,["matter-js:"].concat(Array.prototype.slice.call(arguments)))},t.warnOnce=function(){var i=Array.prototype.slice.call(arguments).join(" ");t._warnedOnce[i]||(t.warn(i),t._warnedOnce[i]=!0)},t.deprecated=function(i,s,o){i[s]=t.chain(function(){t.warnOnce("\u{1F505} deprecated \u{1F505}",o)},i[s])},t.nextId=function(){return t._nextId++},t.indexOf=function(i,s){if(i.indexOf)return i.indexOf(s);for(var o=0;o<i.length;o++)if(i[o]===s)return o;return-1},t.map=function(i,s){if(i.map)return i.map(s);for(var o=[],a=0;a<i.length;a+=1)o.push(s(i[a]));return o},t.topologicalSort=function(i){var s=[],o=[],a=[];for(var l in i)!o[l]&&!a[l]&&t._topologicalSort(l,o,a,i,s);return s},t._topologicalSort=function(i,s,o,a,l){var h=a[i]||[];o[i]=!0;for(var f=0;f<h.length;f+=1){var c=h[f];o[c]||s[c]||t._topologicalSort(c,s,o,a,l)}o[i]=!1,s[i]=!0,l.push(i)},t.chain=function(){for(var i=[],s=0;s<arguments.length;s+=1){var o=arguments[s];o._chained?i.push.apply(i,o._chained):i.push(o)}var a=function(){for(var l,h=new Array(arguments.length),f=0,c=arguments.length;f<c;f++)h[f]=arguments[f];for(f=0;f<i.length;f+=1){var u=i[f].apply(l,h);typeof u<"u"&&(l=u)}return l};return a._chained=i,a},t.chainPathBefore=function(i,s,o){return t.set(i,s,t.chain(o,t.get(i,s)))},t.chainPathAfter=function(i,s,o){return t.set(i,s,t.chain(t.get(i,s),o))},t.setDecomp=function(i){t._decomp=i},t.getDecomp=function(){var i=t._decomp;try{!i&&typeof window<"u"&&(i=window.decomp),!i&&typeof global<"u"&&(i=global.decomp)}catch{i=null}return i}})()}),(function(r,e){var t={};r.exports=t,(function(){t.create=function(n){var i={min:{x:0,y:0},max:{x:0,y:0}};return n&&t.update(i,n),i},t.update=function(n,i,s){n.min.x=1/0,n.max.x=-1/0,n.min.y=1/0,n.max.y=-1/0;for(var o=0;o<i.length;o++){var a=i[o];a.x>n.max.x&&(n.max.x=a.x),a.x<n.min.x&&(n.min.x=a.x),a.y>n.max.y&&(n.max.y=a.y),a.y<n.min.y&&(n.min.y=a.y)}s&&(s.x>0?n.max.x+=s.x:n.min.x+=s.x,s.y>0?n.max.y+=s.y:n.min.y+=s.y)},t.contains=function(n,i){return i.x>=n.min.x&&i.x<=n.max.x&&i.y>=n.min.y&&i.y<=n.max.y},t.overlaps=function(n,i){return n.min.x<=i.max.x&&n.max.x>=i.min.x&&n.max.y>=i.min.y&&n.min.y<=i.max.y},t.translate=function(n,i){n.min.x+=i.x,n.max.x+=i.x,n.min.y+=i.y,n.max.y+=i.y},t.shift=function(n,i){var s=n.max.x-n.min.x,o=n.max.y-n.min.y;n.min.x=i.x,n.max.x=i.x+s,n.min.y=i.y,n.max.y=i.y+o}})()}),(function(r,e){var t={};r.exports=t,(function(){t.create=function(n,i){return{x:n||0,y:i||0}},t.clone=function(n){return{x:n.x,y:n.y}},t.magnitude=function(n){return Math.sqrt(n.x*n.x+n.y*n.y)},t.magnitudeSquared=function(n){return n.x*n.x+n.y*n.y},t.rotate=function(n,i,s){var o=Math.cos(i),a=Math.sin(i);s||(s={});var l=n.x*o-n.y*a;return s.y=n.x*a+n.y*o,s.x=l,s},t.rotateAbout=function(n,i,s,o){var a=Math.cos(i),l=Math.sin(i);o||(o={});var h=s.x+((n.x-s.x)*a-(n.y-s.y)*l);return o.y=s.y+((n.x-s.x)*l+(n.y-s.y)*a),o.x=h,o},t.normalise=function(n){var i=t.magnitude(n);return i===0?{x:0,y:0}:{x:n.x/i,y:n.y/i}},t.dot=function(n,i){return n.x*i.x+n.y*i.y},t.cross=function(n,i){return n.x*i.y-n.y*i.x},t.cross3=function(n,i,s){return(i.x-n.x)*(s.y-n.y)-(i.y-n.y)*(s.x-n.x)},t.add=function(n,i,s){return s||(s={}),s.x=n.x+i.x,s.y=n.y+i.y,s},t.sub=function(n,i,s){return s||(s={}),s.x=n.x-i.x,s.y=n.y-i.y,s},t.mult=function(n,i){return{x:n.x*i,y:n.y*i}},t.div=function(n,i){return{x:n.x/i,y:n.y/i}},t.perp=function(n,i){return i=i===!0?-1:1,{x:i*-n.y,y:i*n.x}},t.neg=function(n){return{x:-n.x,y:-n.y}},t.angle=function(n,i){return Math.atan2(i.y-n.y,i.x-n.x)},t._temp=[t.create(),t.create(),t.create(),t.create(),t.create(),t.create()]})()}),(function(r,e,t){var n={};r.exports=n;var i=t(2),s=t(0);(function(){n.create=function(o,a){for(var l=[],h=0;h<o.length;h++){var f=o[h],c={x:f.x,y:f.y,index:h,body:a,isInternal:!1};l.push(c)}return l},n.fromPath=function(o,a){var l=/L?\s*([-\d.e]+)[\s,]*([-\d.e]+)*/ig,h=[];return o.replace(l,function(f,c,u){h.push({x:parseFloat(c),y:parseFloat(u)})}),n.create(h,a)},n.centre=function(o){for(var a=n.area(o,!0),l={x:0,y:0},h,f,c,u=0;u<o.length;u++)c=(u+1)%o.length,h=i.cross(o[u],o[c]),f=i.mult(i.add(o[u],o[c]),h),l=i.add(l,f);return i.div(l,6*a)},n.mean=function(o){for(var a={x:0,y:0},l=0;l<o.length;l++)a.x+=o[l].x,a.y+=o[l].y;return i.div(a,o.length)},n.area=function(o,a){for(var l=0,h=o.length-1,f=0;f<o.length;f++)l+=(o[h].x-o[f].x)*(o[h].y+o[f].y),h=f;return a?l/2:Math.abs(l)/2},n.inertia=function(o,a){for(var l=0,h=0,f=o,c,u,d=0;d<f.length;d++)u=(d+1)%f.length,c=Math.abs(i.cross(f[u],f[d])),l+=c*(i.dot(f[u],f[u])+i.dot(f[u],f[d])+i.dot(f[d],f[d])),h+=c;return a/6*(l/h)},n.translate=function(o,a,l){l=typeof l<"u"?l:1;var h=o.length,f=a.x*l,c=a.y*l,u;for(u=0;u<h;u++)o[u].x+=f,o[u].y+=c;return o},n.rotate=function(o,a,l){if(a!==0){var h=Math.cos(a),f=Math.sin(a),c=l.x,u=l.y,d=o.length,p,v,g,m;for(m=0;m<d;m++)p=o[m],v=p.x-c,g=p.y-u,p.x=c+(v*h-g*f),p.y=u+(v*f+g*h);return o}},n.contains=function(o,a){for(var l=a.x,h=a.y,f=o.length,c=o[f-1],u,d=0;d<f;d++){if(u=o[d],(l-c.x)*(u.y-c.y)+(h-c.y)*(c.x-u.x)>0)return!1;c=u}return!0},n.scale=function(o,a,l,h){if(a===1&&l===1)return o;h=h||n.centre(o);for(var f,c,u=0;u<o.length;u++)f=o[u],c=i.sub(f,h),o[u].x=h.x+c.x*a,o[u].y=h.y+c.y*l;return o},n.chamfer=function(o,a,l,h,f){typeof a=="number"?a=[a]:a=a||[8],l=typeof l<"u"?l:-1,h=h||2,f=f||14;for(var c=[],u=0;u<o.length;u++){var d=o[u-1>=0?u-1:o.length-1],p=o[u],v=o[(u+1)%o.length],g=a[u<a.length?u:a.length-1];if(g===0){c.push(p);continue}var m=i.normalise({x:p.y-d.y,y:d.x-p.x}),_=i.normalise({x:v.y-p.y,y:p.x-v.x}),x=Math.sqrt(2*Math.pow(g,2)),y=i.mult(s.clone(m),g),S=i.normalise(i.mult(i.add(m,_),.5)),M=i.sub(p,i.mult(S,x)),E=l;l===-1&&(E=Math.pow(g,.32)*1.75),E=s.clamp(E,h,f),E%2===1&&(E+=1);for(var A=Math.acos(i.dot(m,_)),b=A/E,w=0;w<E;w++)c.push(i.add(i.rotate(y,b*w),M))}return c},n.clockwiseSort=function(o){var a=n.mean(o);return o.sort(function(l,h){return i.angle(a,l)-i.angle(a,h)}),o},n.isConvex=function(o){var a=0,l=o.length,h,f,c,u;if(l<3)return null;for(h=0;h<l;h++)if(f=(h+1)%l,c=(h+2)%l,u=(o[f].x-o[h].x)*(o[c].y-o[f].y),u-=(o[f].y-o[h].y)*(o[c].x-o[f].x),u<0?a|=1:u>0&&(a|=2),a===3)return!1;return a!==0?!0:null},n.hull=function(o){var a=[],l=[],h,f;for(o=o.slice(0),o.sort(function(c,u){var d=c.x-u.x;return d!==0?d:c.y-u.y}),f=0;f<o.length;f+=1){for(h=o[f];l.length>=2&&i.cross3(l[l.length-2],l[l.length-1],h)<=0;)l.pop();l.push(h)}for(f=o.length-1;f>=0;f-=1){for(h=o[f];a.length>=2&&i.cross3(a[a.length-2],a[a.length-1],h)<=0;)a.pop();a.push(h)}return a.pop(),l.pop(),a.concat(l)}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(3),s=t(2),o=t(7),a=t(0),l=t(1),h=t(11);(function(){n._timeCorrection=!0,n._inertiaScale=4,n._nextCollidingGroupId=1,n._nextNonCollidingGroupId=-1,n._nextCategory=1,n._baseDelta=1e3/60,n.create=function(c){var u={id:a.nextId(),type:"body",label:"Body",parts:[],plugin:{},angle:0,vertices:i.fromPath("L 0 0 L 40 0 L 40 40 L 0 40"),position:{x:0,y:0},force:{x:0,y:0},torque:0,positionImpulse:{x:0,y:0},constraintImpulse:{x:0,y:0,angle:0},totalContacts:0,speed:0,angularSpeed:0,velocity:{x:0,y:0},angularVelocity:0,isSensor:!1,isStatic:!1,isSleeping:!1,motion:0,sleepThreshold:60,density:.001,restitution:0,friction:.1,frictionStatic:.5,frictionAir:.01,collisionFilter:{category:1,mask:4294967295,group:0},slop:.05,timeScale:1,render:{visible:!0,opacity:1,strokeStyle:null,fillStyle:null,lineWidth:null,sprite:{xScale:1,yScale:1,xOffset:0,yOffset:0}},events:null,bounds:null,chamfer:null,circleRadius:0,positionPrev:null,anglePrev:0,parent:null,axes:null,area:0,mass:0,inertia:0,deltaTime:16.666666666666668,_original:null},d=a.extend(u,c);return f(d,c),d},n.nextGroup=function(c){return c?n._nextNonCollidingGroupId--:n._nextCollidingGroupId++},n.nextCategory=function(){return n._nextCategory=n._nextCategory<<1,n._nextCategory};var f=function(c,u){u=u||{},n.set(c,{bounds:c.bounds||l.create(c.vertices),positionPrev:c.positionPrev||s.clone(c.position),anglePrev:c.anglePrev||c.angle,vertices:c.vertices,parts:c.parts||[c],isStatic:c.isStatic,isSleeping:c.isSleeping,parent:c.parent||c}),i.rotate(c.vertices,c.angle,c.position),h.rotate(c.axes,c.angle),l.update(c.bounds,c.vertices,c.velocity),n.set(c,{axes:u.axes||c.axes,area:u.area||c.area,mass:u.mass||c.mass,inertia:u.inertia||c.inertia});var d=c.isStatic?"#14151f":a.choose(["#f19648","#f5d259","#f55a3c","#063e7b","#ececd1"]),p=c.isStatic?"#555":"#ccc",v=c.isStatic&&c.render.fillStyle===null?1:0;c.render.fillStyle=c.render.fillStyle||d,c.render.strokeStyle=c.render.strokeStyle||p,c.render.lineWidth=c.render.lineWidth||v,c.render.sprite.xOffset+=-(c.bounds.min.x-c.position.x)/(c.bounds.max.x-c.bounds.min.x),c.render.sprite.yOffset+=-(c.bounds.min.y-c.position.y)/(c.bounds.max.y-c.bounds.min.y)};n.set=function(c,u,d){var p;typeof u=="string"&&(p=u,u={},u[p]=d);for(p in u)if(Object.prototype.hasOwnProperty.call(u,p))switch(d=u[p],p){case"isStatic":n.setStatic(c,d);break;case"isSleeping":o.set(c,d);break;case"mass":n.setMass(c,d);break;case"density":n.setDensity(c,d);break;case"inertia":n.setInertia(c,d);break;case"vertices":n.setVertices(c,d);break;case"position":n.setPosition(c,d);break;case"angle":n.setAngle(c,d);break;case"velocity":n.setVelocity(c,d);break;case"angularVelocity":n.setAngularVelocity(c,d);break;case"speed":n.setSpeed(c,d);break;case"angularSpeed":n.setAngularSpeed(c,d);break;case"parts":n.setParts(c,d);break;case"centre":n.setCentre(c,d);break;default:c[p]=d}},n.setStatic=function(c,u){for(var d=0;d<c.parts.length;d++){var p=c.parts[d];u?(p.isStatic||(p._original={restitution:p.restitution,friction:p.friction,mass:p.mass,inertia:p.inertia,density:p.density,inverseMass:p.inverseMass,inverseInertia:p.inverseInertia}),p.restitution=0,p.friction=1,p.mass=p.inertia=p.density=1/0,p.inverseMass=p.inverseInertia=0,p.positionPrev.x=p.position.x,p.positionPrev.y=p.position.y,p.anglePrev=p.angle,p.angularVelocity=0,p.speed=0,p.angularSpeed=0,p.motion=0):p._original&&(p.restitution=p._original.restitution,p.friction=p._original.friction,p.mass=p._original.mass,p.inertia=p._original.inertia,p.density=p._original.density,p.inverseMass=p._original.inverseMass,p.inverseInertia=p._original.inverseInertia,p._original=null),p.isStatic=u}},n.setMass=function(c,u){var d=c.inertia/(c.mass/6);c.inertia=d*(u/6),c.inverseInertia=1/c.inertia,c.mass=u,c.inverseMass=1/c.mass,c.density=c.mass/c.area},n.setDensity=function(c,u){n.setMass(c,u*c.area),c.density=u},n.setInertia=function(c,u){c.inertia=u,c.inverseInertia=1/c.inertia},n.setVertices=function(c,u){u[0].body===c?c.vertices=u:c.vertices=i.create(u,c),c.axes=h.fromVertices(c.vertices),c.area=i.area(c.vertices),n.setMass(c,c.density*c.area);var d=i.centre(c.vertices);i.translate(c.vertices,d,-1),n.setInertia(c,n._inertiaScale*i.inertia(c.vertices,c.mass)),i.translate(c.vertices,c.position),l.update(c.bounds,c.vertices,c.velocity)},n.setParts=function(c,u,d){var p;for(u=u.slice(0),c.parts.length=0,c.parts.push(c),c.parent=c,p=0;p<u.length;p++){var v=u[p];v!==c&&(v.parent=c,c.parts.push(v))}if(c.parts.length!==1){if(d=typeof d<"u"?d:!0,d){var g=[];for(p=0;p<u.length;p++)g=g.concat(u[p].vertices);i.clockwiseSort(g);var m=i.hull(g),_=i.centre(m);n.setVertices(c,m),i.translate(c.vertices,_)}var x=n._totalProperties(c);c.area=x.area,c.parent=c,c.position.x=x.centre.x,c.position.y=x.centre.y,c.positionPrev.x=x.centre.x,c.positionPrev.y=x.centre.y,n.setMass(c,x.mass),n.setInertia(c,x.inertia),n.setPosition(c,x.centre)}},n.setCentre=function(c,u,d){d?(c.positionPrev.x+=u.x,c.positionPrev.y+=u.y,c.position.x+=u.x,c.position.y+=u.y):(c.positionPrev.x=u.x-(c.position.x-c.positionPrev.x),c.positionPrev.y=u.y-(c.position.y-c.positionPrev.y),c.position.x=u.x,c.position.y=u.y)},n.setPosition=function(c,u,d){var p=s.sub(u,c.position);d?(c.positionPrev.x=c.position.x,c.positionPrev.y=c.position.y,c.velocity.x=p.x,c.velocity.y=p.y,c.speed=s.magnitude(p)):(c.positionPrev.x+=p.x,c.positionPrev.y+=p.y);for(var v=0;v<c.parts.length;v++){var g=c.parts[v];g.position.x+=p.x,g.position.y+=p.y,i.translate(g.vertices,p),l.update(g.bounds,g.vertices,c.velocity)}},n.setAngle=function(c,u,d){var p=u-c.angle;d?(c.anglePrev=c.angle,c.angularVelocity=p,c.angularSpeed=Math.abs(p)):c.anglePrev+=p;for(var v=0;v<c.parts.length;v++){var g=c.parts[v];g.angle+=p,i.rotate(g.vertices,p,c.position),h.rotate(g.axes,p),l.update(g.bounds,g.vertices,c.velocity),v>0&&s.rotateAbout(g.position,p,c.position,g.position)}},n.setVelocity=function(c,u){var d=c.deltaTime/n._baseDelta;c.positionPrev.x=c.position.x-u.x*d,c.positionPrev.y=c.position.y-u.y*d,c.velocity.x=(c.position.x-c.positionPrev.x)/d,c.velocity.y=(c.position.y-c.positionPrev.y)/d,c.speed=s.magnitude(c.velocity)},n.getVelocity=function(c){var u=n._baseDelta/c.deltaTime;return{x:(c.position.x-c.positionPrev.x)*u,y:(c.position.y-c.positionPrev.y)*u}},n.getSpeed=function(c){return s.magnitude(n.getVelocity(c))},n.setSpeed=function(c,u){n.setVelocity(c,s.mult(s.normalise(n.getVelocity(c)),u))},n.setAngularVelocity=function(c,u){var d=c.deltaTime/n._baseDelta;c.anglePrev=c.angle-u*d,c.angularVelocity=(c.angle-c.anglePrev)/d,c.angularSpeed=Math.abs(c.angularVelocity)},n.getAngularVelocity=function(c){return(c.angle-c.anglePrev)*n._baseDelta/c.deltaTime},n.getAngularSpeed=function(c){return Math.abs(n.getAngularVelocity(c))},n.setAngularSpeed=function(c,u){n.setAngularVelocity(c,a.sign(n.getAngularVelocity(c))*u)},n.translate=function(c,u,d){n.setPosition(c,s.add(c.position,u),d)},n.rotate=function(c,u,d,p){if(!d)n.setAngle(c,c.angle+u,p);else{var v=Math.cos(u),g=Math.sin(u),m=c.position.x-d.x,_=c.position.y-d.y;n.setPosition(c,{x:d.x+(m*v-_*g),y:d.y+(m*g+_*v)},p),n.setAngle(c,c.angle+u,p)}},n.scale=function(c,u,d,p){var v=0,g=0;p=p||c.position;for(var m=0;m<c.parts.length;m++){var _=c.parts[m];i.scale(_.vertices,u,d,p),_.axes=h.fromVertices(_.vertices),_.area=i.area(_.vertices),n.setMass(_,c.density*_.area),i.translate(_.vertices,{x:-_.position.x,y:-_.position.y}),n.setInertia(_,n._inertiaScale*i.inertia(_.vertices,_.mass)),i.translate(_.vertices,{x:_.position.x,y:_.position.y}),m>0&&(v+=_.area,g+=_.inertia),_.position.x=p.x+(_.position.x-p.x)*u,_.position.y=p.y+(_.position.y-p.y)*d,l.update(_.bounds,_.vertices,c.velocity)}c.parts.length>1&&(c.area=v,c.isStatic||(n.setMass(c,c.density*v),n.setInertia(c,g))),c.circleRadius&&(u===d?c.circleRadius*=u:c.circleRadius=null)},n.update=function(c,u){u=(typeof u<"u"?u:1e3/60)*c.timeScale;var d=u*u,p=n._timeCorrection?u/(c.deltaTime||u):1,v=1-c.frictionAir*(u/a._baseDelta),g=(c.position.x-c.positionPrev.x)*p,m=(c.position.y-c.positionPrev.y)*p;c.velocity.x=g*v+c.force.x/c.mass*d,c.velocity.y=m*v+c.force.y/c.mass*d,c.positionPrev.x=c.position.x,c.positionPrev.y=c.position.y,c.position.x+=c.velocity.x,c.position.y+=c.velocity.y,c.deltaTime=u,c.angularVelocity=(c.angle-c.anglePrev)*v*p+c.torque/c.inertia*d,c.anglePrev=c.angle,c.angle+=c.angularVelocity;for(var _=0;_<c.parts.length;_++){var x=c.parts[_];i.translate(x.vertices,c.velocity),_>0&&(x.position.x+=c.velocity.x,x.position.y+=c.velocity.y),c.angularVelocity!==0&&(i.rotate(x.vertices,c.angularVelocity,c.position),h.rotate(x.axes,c.angularVelocity),_>0&&s.rotateAbout(x.position,c.angularVelocity,c.position,x.position)),l.update(x.bounds,x.vertices,c.velocity)}},n.updateVelocities=function(c){var u=n._baseDelta/c.deltaTime,d=c.velocity;d.x=(c.position.x-c.positionPrev.x)*u,d.y=(c.position.y-c.positionPrev.y)*u,c.speed=Math.sqrt(d.x*d.x+d.y*d.y),c.angularVelocity=(c.angle-c.anglePrev)*u,c.angularSpeed=Math.abs(c.angularVelocity)},n.applyForce=function(c,u,d){var p={x:u.x-c.position.x,y:u.y-c.position.y};c.force.x+=d.x,c.force.y+=d.y,c.torque+=p.x*d.y-p.y*d.x},n._totalProperties=function(c){for(var u={mass:0,area:0,inertia:0,centre:{x:0,y:0}},d=c.parts.length===1?0:1;d<c.parts.length;d++){var p=c.parts[d],v=p.mass!==1/0?p.mass:1;u.mass+=v,u.area+=p.area,u.inertia+=p.inertia,u.centre=s.add(u.centre,s.mult(p.position,v))}return u.centre=s.div(u.centre,u.mass),u}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(0);(function(){n.on=function(s,o,a){for(var l=o.split(" "),h,f=0;f<l.length;f++)h=l[f],s.events=s.events||{},s.events[h]=s.events[h]||[],s.events[h].push(a);return a},n.off=function(s,o,a){if(!o){s.events={};return}typeof o=="function"&&(a=o,o=i.keys(s.events).join(" "));for(var l=o.split(" "),h=0;h<l.length;h++){var f=s.events[l[h]],c=[];if(a&&f)for(var u=0;u<f.length;u++)f[u]!==a&&c.push(f[u]);s.events[l[h]]=c}},n.trigger=function(s,o,a){var l,h,f,c,u=s.events;if(u&&i.keys(u).length>0){a||(a={}),l=o.split(" ");for(var d=0;d<l.length;d++)if(h=l[d],f=u[h],f){c=i.clone(a,!1),c.name=h,c.source=s;for(var p=0;p<f.length;p++)f[p].apply(s,[c])}}}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(5),s=t(0),o=t(1),a=t(4);(function(){n.create=function(l){return s.extend({id:s.nextId(),type:"composite",parent:null,isModified:!1,bodies:[],constraints:[],composites:[],label:"Composite",plugin:{},cache:{allBodies:null,allConstraints:null,allComposites:null}},l)},n.setModified=function(l,h,f,c){if(l.isModified=h,h&&l.cache&&(l.cache.allBodies=null,l.cache.allConstraints=null,l.cache.allComposites=null),f&&l.parent&&n.setModified(l.parent,h,f,c),c)for(var u=0;u<l.composites.length;u++){var d=l.composites[u];n.setModified(d,h,f,c)}},n.add=function(l,h){var f=[].concat(h);i.trigger(l,"beforeAdd",{object:h});for(var c=0;c<f.length;c++){var u=f[c];switch(u.type){case"body":if(u.parent!==u){s.warn("Composite.add: skipped adding a compound body part (you must add its parent instead)");break}n.addBody(l,u);break;case"constraint":n.addConstraint(l,u);break;case"composite":n.addComposite(l,u);break;case"mouseConstraint":n.addConstraint(l,u.constraint);break}}return i.trigger(l,"afterAdd",{object:h}),l},n.remove=function(l,h,f){var c=[].concat(h);i.trigger(l,"beforeRemove",{object:h});for(var u=0;u<c.length;u++){var d=c[u];switch(d.type){case"body":n.removeBody(l,d,f);break;case"constraint":n.removeConstraint(l,d,f);break;case"composite":n.removeComposite(l,d,f);break;case"mouseConstraint":n.removeConstraint(l,d.constraint);break}}return i.trigger(l,"afterRemove",{object:h}),l},n.addComposite=function(l,h){return l.composites.push(h),h.parent=l,n.setModified(l,!0,!0,!1),l},n.removeComposite=function(l,h,f){var c=s.indexOf(l.composites,h);if(c!==-1){var u=n.allBodies(h);n.removeCompositeAt(l,c);for(var d=0;d<u.length;d++)u[d].sleepCounter=0}if(f)for(var d=0;d<l.composites.length;d++)n.removeComposite(l.composites[d],h,!0);return l},n.removeCompositeAt=function(l,h){return l.composites.splice(h,1),n.setModified(l,!0,!0,!1),l},n.addBody=function(l,h){return l.bodies.push(h),n.setModified(l,!0,!0,!1),l},n.removeBody=function(l,h,f){var c=s.indexOf(l.bodies,h);if(c!==-1&&(n.removeBodyAt(l,c),h.sleepCounter=0),f)for(var u=0;u<l.composites.length;u++)n.removeBody(l.composites[u],h,!0);return l},n.removeBodyAt=function(l,h){return l.bodies.splice(h,1),n.setModified(l,!0,!0,!1),l},n.addConstraint=function(l,h){return l.constraints.push(h),n.setModified(l,!0,!0,!1),l},n.removeConstraint=function(l,h,f){var c=s.indexOf(l.constraints,h);if(c!==-1&&n.removeConstraintAt(l,c),f)for(var u=0;u<l.composites.length;u++)n.removeConstraint(l.composites[u],h,!0);return l},n.removeConstraintAt=function(l,h){return l.constraints.splice(h,1),n.setModified(l,!0,!0,!1),l},n.clear=function(l,h,f){if(f)for(var c=0;c<l.composites.length;c++)n.clear(l.composites[c],h,!0);return h?l.bodies=l.bodies.filter(function(u){return u.isStatic}):l.bodies.length=0,l.constraints.length=0,l.composites.length=0,n.setModified(l,!0,!0,!1),l},n.allBodies=function(l){if(l.cache&&l.cache.allBodies)return l.cache.allBodies;for(var h=[].concat(l.bodies),f=0;f<l.composites.length;f++)h=h.concat(n.allBodies(l.composites[f]));return l.cache&&(l.cache.allBodies=h),h},n.allConstraints=function(l){if(l.cache&&l.cache.allConstraints)return l.cache.allConstraints;for(var h=[].concat(l.constraints),f=0;f<l.composites.length;f++)h=h.concat(n.allConstraints(l.composites[f]));return l.cache&&(l.cache.allConstraints=h),h},n.allComposites=function(l){if(l.cache&&l.cache.allComposites)return l.cache.allComposites;for(var h=[].concat(l.composites),f=0;f<l.composites.length;f++)h=h.concat(n.allComposites(l.composites[f]));return l.cache&&(l.cache.allComposites=h),h},n.get=function(l,h,f){var c,u;switch(f){case"body":c=n.allBodies(l);break;case"constraint":c=n.allConstraints(l);break;case"composite":c=n.allComposites(l).concat(l);break}return c?(u=c.filter(function(d){return d.id.toString()===h.toString()}),u.length===0?null:u[0]):null},n.move=function(l,h,f){return n.remove(l,h),n.add(f,h),l},n.rebase=function(l){for(var h=n.allBodies(l).concat(n.allConstraints(l)).concat(n.allComposites(l)),f=0;f<h.length;f++)h[f].id=s.nextId();return l},n.translate=function(l,h,f){for(var c=f?n.allBodies(l):l.bodies,u=0;u<c.length;u++)a.translate(c[u],h);return l},n.rotate=function(l,h,f,c){for(var u=Math.cos(h),d=Math.sin(h),p=c?n.allBodies(l):l.bodies,v=0;v<p.length;v++){var g=p[v],m=g.position.x-f.x,_=g.position.y-f.y;a.setPosition(g,{x:f.x+(m*u-_*d),y:f.y+(m*d+_*u)}),a.rotate(g,h)}return l},n.scale=function(l,h,f,c,u){for(var d=u?n.allBodies(l):l.bodies,p=0;p<d.length;p++){var v=d[p],g=v.position.x-c.x,m=v.position.y-c.y;a.setPosition(v,{x:c.x+g*h,y:c.y+m*f}),a.scale(v,h,f)}return l},n.bounds=function(l){for(var h=n.allBodies(l),f=[],c=0;c<h.length;c+=1){var u=h[c];f.push(u.bounds.min,u.bounds.max)}return o.create(f)}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(4),s=t(5),o=t(0);(function(){n._motionWakeThreshold=.18,n._motionSleepThreshold=.08,n._minBias=.9,n.update=function(a,l){for(var h=l/o._baseDelta,f=n._motionSleepThreshold,c=0;c<a.length;c++){var u=a[c],d=i.getSpeed(u),p=i.getAngularSpeed(u),v=d*d+p*p;if(u.force.x!==0||u.force.y!==0){n.set(u,!1);continue}var g=Math.min(u.motion,v),m=Math.max(u.motion,v);u.motion=n._minBias*g+(1-n._minBias)*m,u.sleepThreshold>0&&u.motion<f?(u.sleepCounter+=1,u.sleepCounter>=u.sleepThreshold/h&&n.set(u,!0)):u.sleepCounter>0&&(u.sleepCounter-=1)}},n.afterCollisions=function(a){for(var l=n._motionSleepThreshold,h=0;h<a.length;h++){var f=a[h];if(f.isActive){var c=f.collision,u=c.bodyA.parent,d=c.bodyB.parent;if(!(u.isSleeping&&d.isSleeping||u.isStatic||d.isStatic)&&(u.isSleeping||d.isSleeping)){var p=u.isSleeping&&!u.isStatic?u:d,v=p===u?d:u;!p.isStatic&&v.motion>l&&n.set(p,!1)}}}},n.set=function(a,l){var h=a.isSleeping;l?(a.isSleeping=!0,a.sleepCounter=a.sleepThreshold,a.positionImpulse.x=0,a.positionImpulse.y=0,a.positionPrev.x=a.position.x,a.positionPrev.y=a.position.y,a.anglePrev=a.angle,a.speed=0,a.angularSpeed=0,a.motion=0,h||s.trigger(a,"sleepStart")):(a.isSleeping=!1,a.sleepCounter=0,h&&s.trigger(a,"sleepEnd"))}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(3),s=t(9);(function(){var o=[],a={overlap:0,axis:null},l={overlap:0,axis:null};n.create=function(h,f){return{pair:null,collided:!1,bodyA:h,bodyB:f,parentA:h.parent,parentB:f.parent,depth:0,normal:{x:0,y:0},tangent:{x:0,y:0},penetration:{x:0,y:0},supports:[null,null],supportCount:0}},n.collides=function(h,f,c){if(n._overlapAxes(a,h.vertices,f.vertices,h.axes),a.overlap<=0||(n._overlapAxes(l,f.vertices,h.vertices,f.axes),l.overlap<=0))return null;var u=c&&c.table[s.id(h,f)],d;u?d=u.collision:(d=n.create(h,f),d.collided=!0,d.bodyA=h.id<f.id?h:f,d.bodyB=h.id<f.id?f:h,d.parentA=d.bodyA.parent,d.parentB=d.bodyB.parent),h=d.bodyA,f=d.bodyB;var p;a.overlap<l.overlap?p=a:p=l;var v=d.normal,g=d.tangent,m=d.penetration,_=d.supports,x=p.overlap,y=p.axis,S=y.x,M=y.y,E=f.position.x-h.position.x,A=f.position.y-h.position.y;S*E+M*A>=0&&(S=-S,M=-M),v.x=S,v.y=M,g.x=-M,g.y=S,m.x=S*x,m.y=M*x,d.depth=x;var b=n._findSupports(h,f,v,1),w=0;if(i.contains(h.vertices,b[0])&&(_[w++]=b[0]),i.contains(h.vertices,b[1])&&(_[w++]=b[1]),w<2){var T=n._findSupports(f,h,v,-1);i.contains(f.vertices,T[0])&&(_[w++]=T[0]),w<2&&i.contains(f.vertices,T[1])&&(_[w++]=T[1])}return w===0&&(_[w++]=b[0]),d.supportCount=w,d},n._overlapAxes=function(h,f,c,u){var d=f.length,p=c.length,v=f[0].x,g=f[0].y,m=c[0].x,_=c[0].y,x=u.length,y=Number.MAX_VALUE,S=0,M,E,A,b,w,T;for(w=0;w<x;w++){var F=u[w],D=F.x,C=F.y,P=v*D+g*C,N=m*D+_*C,z=P,O=N;for(T=1;T<d;T+=1)b=f[T].x*D+f[T].y*C,b>z?z=b:b<P&&(P=b);for(T=1;T<p;T+=1)b=c[T].x*D+c[T].y*C,b>O?O=b:b<N&&(N=b);if(E=z-N,A=O-P,M=E<A?E:A,M<y&&(y=M,S=w,M<=0))break}h.axis=u[S],h.overlap=y},n._findSupports=function(h,f,c,u){var d=f.vertices,p=d.length,v=h.position.x,g=h.position.y,m=c.x*u,_=c.y*u,x=d[0],y=x,S=m*(v-y.x)+_*(g-y.y),M,E,A;for(A=1;A<p;A+=1)y=d[A],E=m*(v-y.x)+_*(g-y.y),E<S&&(S=E,x=y);return M=d[(p+x.index-1)%p],S=m*(v-M.x)+_*(g-M.y),y=d[(x.index+1)%p],m*(v-y.x)+_*(g-y.y)<S?(o[0]=x,o[1]=y,o):(o[0]=x,o[1]=M,o)}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(16);(function(){n.create=function(s,o){var a=s.bodyA,l=s.bodyB,h={id:n.id(a,l),bodyA:a,bodyB:l,collision:s,contacts:[i.create(),i.create()],contactCount:0,separation:0,isActive:!0,isSensor:a.isSensor||l.isSensor,timeCreated:o,timeUpdated:o,inverseMass:0,friction:0,frictionStatic:0,restitution:0,slop:0};return n.update(h,s,o),h},n.update=function(s,o,a){var l=o.supports,h=o.supportCount,f=s.contacts,c=o.parentA,u=o.parentB;s.isActive=!0,s.timeUpdated=a,s.collision=o,s.separation=o.depth,s.inverseMass=c.inverseMass+u.inverseMass,s.friction=c.friction<u.friction?c.friction:u.friction,s.frictionStatic=c.frictionStatic>u.frictionStatic?c.frictionStatic:u.frictionStatic,s.restitution=c.restitution>u.restitution?c.restitution:u.restitution,s.slop=c.slop>u.slop?c.slop:u.slop,s.contactCount=h,o.pair=s;var d=l[0],p=f[0],v=l[1],g=f[1];(g.vertex===d||p.vertex===v)&&(f[1]=p,f[0]=p=g,g=f[1]),p.vertex=d,g.vertex=v},n.setActive=function(s,o,a){o?(s.isActive=!0,s.timeUpdated=a):(s.isActive=!1,s.contactCount=0)},n.id=function(s,o){return s.id<o.id?s.id.toString(36)+":"+o.id.toString(36):o.id.toString(36)+":"+s.id.toString(36)}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(3),s=t(2),o=t(7),a=t(1),l=t(11),h=t(0);(function(){n._warming=.4,n._torqueDampen=1,n._minLength=1e-6,n.create=function(f){var c=f;c.bodyA&&!c.pointA&&(c.pointA={x:0,y:0}),c.bodyB&&!c.pointB&&(c.pointB={x:0,y:0});var u=c.bodyA?s.add(c.bodyA.position,c.pointA):c.pointA,d=c.bodyB?s.add(c.bodyB.position,c.pointB):c.pointB,p=s.magnitude(s.sub(u,d));c.length=typeof c.length<"u"?c.length:p,c.id=c.id||h.nextId(),c.label=c.label||"Constraint",c.type="constraint",c.stiffness=c.stiffness||(c.length>0?1:.7),c.damping=c.damping||0,c.angularStiffness=c.angularStiffness||0,c.angleA=c.bodyA?c.bodyA.angle:c.angleA,c.angleB=c.bodyB?c.bodyB.angle:c.angleB,c.plugin={};var v={visible:!0,lineWidth:2,strokeStyle:"#ffffff",type:"line",anchors:!0};return c.length===0&&c.stiffness>.1?(v.type="pin",v.anchors=!1):c.stiffness<.9&&(v.type="spring"),c.render=h.extend(v,c.render),c},n.preSolveAll=function(f){for(var c=0;c<f.length;c+=1){var u=f[c],d=u.constraintImpulse;u.isStatic||d.x===0&&d.y===0&&d.angle===0||(u.position.x+=d.x,u.position.y+=d.y,u.angle+=d.angle)}},n.solveAll=function(f,c){for(var u=h.clamp(c/h._baseDelta,0,1),d=0;d<f.length;d+=1){var p=f[d],v=!p.bodyA||p.bodyA&&p.bodyA.isStatic,g=!p.bodyB||p.bodyB&&p.bodyB.isStatic;(v||g)&&n.solve(f[d],u)}for(d=0;d<f.length;d+=1)p=f[d],v=!p.bodyA||p.bodyA&&p.bodyA.isStatic,g=!p.bodyB||p.bodyB&&p.bodyB.isStatic,!v&&!g&&n.solve(f[d],u)},n.solve=function(f,c){var u=f.bodyA,d=f.bodyB,p=f.pointA,v=f.pointB;if(!(!u&&!d)){u&&!u.isStatic&&(s.rotate(p,u.angle-f.angleA,p),f.angleA=u.angle),d&&!d.isStatic&&(s.rotate(v,d.angle-f.angleB,v),f.angleB=d.angle);var g=p,m=v;if(u&&(g=s.add(u.position,p)),d&&(m=s.add(d.position,v)),!(!g||!m)){var _=s.sub(g,m),x=s.magnitude(_);x<n._minLength&&(x=n._minLength);var y=(x-f.length)/x,S=f.stiffness>=1||f.length===0,M=S?f.stiffness*c:f.stiffness*c*c,E=f.damping*c,A=s.mult(_,y*M),b=(u?u.inverseMass:0)+(d?d.inverseMass:0),w=(u?u.inverseInertia:0)+(d?d.inverseInertia:0),T=b+w,F,D,C,P,N;if(E>0){var z=s.create();C=s.div(_,x),N=s.sub(d&&s.sub(d.position,d.positionPrev)||z,u&&s.sub(u.position,u.positionPrev)||z),P=s.dot(C,N)}u&&!u.isStatic&&(D=u.inverseMass/b,u.constraintImpulse.x-=A.x*D,u.constraintImpulse.y-=A.y*D,u.position.x-=A.x*D,u.position.y-=A.y*D,E>0&&(u.positionPrev.x-=E*C.x*P*D,u.positionPrev.y-=E*C.y*P*D),F=s.cross(p,A)/T*n._torqueDampen*u.inverseInertia*(1-f.angularStiffness),u.constraintImpulse.angle-=F,u.angle-=F),d&&!d.isStatic&&(D=d.inverseMass/b,d.constraintImpulse.x+=A.x*D,d.constraintImpulse.y+=A.y*D,d.position.x+=A.x*D,d.position.y+=A.y*D,E>0&&(d.positionPrev.x+=E*C.x*P*D,d.positionPrev.y+=E*C.y*P*D),F=s.cross(v,A)/T*n._torqueDampen*d.inverseInertia*(1-f.angularStiffness),d.constraintImpulse.angle+=F,d.angle+=F)}}},n.postSolveAll=function(f){for(var c=0;c<f.length;c++){var u=f[c],d=u.constraintImpulse;if(!(u.isStatic||d.x===0&&d.y===0&&d.angle===0)){o.set(u,!1);for(var p=0;p<u.parts.length;p++){var v=u.parts[p];i.translate(v.vertices,d),p>0&&(v.position.x+=d.x,v.position.y+=d.y),d.angle!==0&&(i.rotate(v.vertices,d.angle,u.position),l.rotate(v.axes,d.angle),p>0&&s.rotateAbout(v.position,d.angle,u.position,v.position)),a.update(v.bounds,v.vertices,u.velocity)}d.angle*=n._warming,d.x*=n._warming,d.y*=n._warming}}},n.pointAWorld=function(f){return{x:(f.bodyA?f.bodyA.position.x:0)+(f.pointA?f.pointA.x:0),y:(f.bodyA?f.bodyA.position.y:0)+(f.pointA?f.pointA.y:0)}},n.pointBWorld=function(f){return{x:(f.bodyB?f.bodyB.position.x:0)+(f.pointB?f.pointB.x:0),y:(f.bodyB?f.bodyB.position.y:0)+(f.pointB?f.pointB.y:0)}},n.currentLength=function(f){var c=(f.bodyA?f.bodyA.position.x:0)+(f.pointA?f.pointA.x:0),u=(f.bodyA?f.bodyA.position.y:0)+(f.pointA?f.pointA.y:0),d=(f.bodyB?f.bodyB.position.x:0)+(f.pointB?f.pointB.x:0),p=(f.bodyB?f.bodyB.position.y:0)+(f.pointB?f.pointB.y:0),v=c-d,g=u-p;return Math.sqrt(v*v+g*g)}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(2),s=t(0);(function(){n.fromVertices=function(o){for(var a={},l=0;l<o.length;l++){var h=(l+1)%o.length,f=i.normalise({x:o[h].y-o[l].y,y:o[l].x-o[h].x}),c=f.y===0?1/0:f.x/f.y;c=c.toFixed(3).toString(),a[c]=f}return s.values(a)},n.rotate=function(o,a){if(a!==0)for(var l=Math.cos(a),h=Math.sin(a),f=0;f<o.length;f++){var c=o[f],u;u=c.x*l-c.y*h,c.y=c.x*h+c.y*l,c.x=u}}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(3),s=t(0),o=t(4),a=t(1),l=t(2);(function(){n.rectangle=function(h,f,c,u,d){d=d||{};var p={label:"Rectangle Body",position:{x:h,y:f},vertices:i.fromPath("L 0 0 L "+c+" 0 L "+c+" "+u+" L 0 "+u)};if(d.chamfer){var v=d.chamfer;p.vertices=i.chamfer(p.vertices,v.radius,v.quality,v.qualityMin,v.qualityMax),delete d.chamfer}return o.create(s.extend({},p,d))},n.trapezoid=function(h,f,c,u,d,p){p=p||{},d>=1&&s.warn("Bodies.trapezoid: slope parameter must be < 1."),d*=.5;var v=(1-d*2)*c,g=c*d,m=g+v,_=m+g,x;d<.5?x="L 0 0 L "+g+" "+-u+" L "+m+" "+-u+" L "+_+" 0":x="L 0 0 L "+m+" "+-u+" L "+_+" 0";var y={label:"Trapezoid Body",position:{x:h,y:f},vertices:i.fromPath(x)};if(p.chamfer){var S=p.chamfer;y.vertices=i.chamfer(y.vertices,S.radius,S.quality,S.qualityMin,S.qualityMax),delete p.chamfer}return o.create(s.extend({},y,p))},n.circle=function(h,f,c,u,d){u=u||{};var p={label:"Circle Body",circleRadius:c};d=d||25;var v=Math.ceil(Math.max(10,Math.min(d,c)));return v%2===1&&(v+=1),n.polygon(h,f,v,c,s.extend({},p,u))},n.polygon=function(h,f,c,u,d){if(d=d||{},c<3)return n.circle(h,f,u,d);for(var p=2*Math.PI/c,v="",g=p*.5,m=0;m<c;m+=1){var _=g+m*p,x=Math.cos(_)*u,y=Math.sin(_)*u;v+="L "+x.toFixed(3)+" "+y.toFixed(3)+" "}var S={label:"Polygon Body",position:{x:h,y:f},vertices:i.fromPath(v)};if(d.chamfer){var M=d.chamfer;S.vertices=i.chamfer(S.vertices,M.radius,M.quality,M.qualityMin,M.qualityMax),delete d.chamfer}return o.create(s.extend({},S,d))},n.fromVertices=function(h,f,c,u,d,p,v,g){var m=s.getDecomp(),_,x,y,S,M,E,A,b,w,T,F;for(_=!!(m&&m.quickDecomp),u=u||{},y=[],d=typeof d<"u"?d:!1,p=typeof p<"u"?p:.01,v=typeof v<"u"?v:10,g=typeof g<"u"?g:.01,s.isArray(c[0])||(c=[c]),T=0;T<c.length;T+=1)if(E=c[T],S=i.isConvex(E),M=!S,M&&!_&&s.warnOnce("Bodies.fromVertices: Install the 'poly-decomp' library and use Common.setDecomp or provide 'decomp' as a global to decompose concave vertices."),S||!_)S?E=i.clockwiseSort(E):E=i.hull(E),y.push({position:{x:h,y:f},vertices:E});else{var D=E.map(function(Ce){return[Ce.x,Ce.y]});m.makeCCW(D),p!==!1&&m.removeCollinearPoints(D,p),g!==!1&&m.removeDuplicatePoints&&m.removeDuplicatePoints(D,g);var C=m.quickDecomp(D);for(A=0;A<C.length;A++){var P=C[A],N=P.map(function(Ce){return{x:Ce[0],y:Ce[1]}});v>0&&i.area(N)<v||y.push({position:i.centre(N),vertices:N})}}for(A=0;A<y.length;A++)y[A]=o.create(s.extend(y[A],u));if(d){var z=5;for(A=0;A<y.length;A++){var O=y[A];for(b=A+1;b<y.length;b++){var K=y[b];if(a.overlaps(O.bounds,K.bounds)){var ee=O.vertices,oe=K.vertices;for(w=0;w<O.vertices.length;w++)for(F=0;F<K.vertices.length;F++){var ae=l.magnitudeSquared(l.sub(ee[(w+1)%ee.length],oe[F])),Ge=l.magnitudeSquared(l.sub(ee[w],oe[(F+1)%oe.length]));ae<z&&Ge<z&&(ee[w].isInternal=!0,oe[F].isInternal=!0)}}}}}return y.length>1?(x=o.create(s.extend({parts:y.slice(0)},u)),o.setPosition(x,{x:h,y:f}),x):y[0]}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(0),s=t(8);(function(){n.create=function(o){var a={bodies:[],collisions:[],pairs:null};return i.extend(a,o)},n.setBodies=function(o,a){o.bodies=a.slice(0)},n.clear=function(o){o.bodies=[],o.collisions=[]},n.collisions=function(o){var a=o.pairs,l=o.bodies,h=l.length,f=n.canCollide,c=s.collides,u=o.collisions,d=0,p,v;for(l.sort(n._compareBoundsX),p=0;p<h;p++){var g=l[p],m=g.bounds,_=g.bounds.max.x,x=g.bounds.max.y,y=g.bounds.min.y,S=g.isStatic||g.isSleeping,M=g.parts.length,E=M===1;for(v=p+1;v<h;v++){var A=l[v],b=A.bounds;if(b.min.x>_)break;if(!(x<b.min.y||y>b.max.y)&&!(S&&(A.isStatic||A.isSleeping))&&f(g.collisionFilter,A.collisionFilter)){var w=A.parts.length;if(E&&w===1){var T=c(g,A,a);T&&(u[d++]=T)}else for(var F=M>1?1:0,D=w>1?1:0,C=F;C<M;C++)for(var P=g.parts[C],m=P.bounds,N=D;N<w;N++){var z=A.parts[N],b=z.bounds;if(!(m.min.x>b.max.x||m.max.x<b.min.x||m.max.y<b.min.y||m.min.y>b.max.y)){var T=c(P,z,a);T&&(u[d++]=T)}}}}}return u.length!==d&&(u.length=d),u},n.canCollide=function(o,a){return o.group===a.group&&o.group!==0?o.group>0:(o.mask&a.category)!==0&&(a.mask&o.category)!==0},n._compareBoundsX=function(o,a){return o.bounds.min.x-a.bounds.min.x}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(0);(function(){n.create=function(s){var o={};return s||i.log("Mouse.create: element was undefined, defaulting to document.body","warn"),o.element=s||document.body,o.absolute={x:0,y:0},o.position={x:0,y:0},o.mousedownPosition={x:0,y:0},o.mouseupPosition={x:0,y:0},o.offset={x:0,y:0},o.scale={x:1,y:1},o.wheelDelta=0,o.button=-1,o.pixelRatio=parseInt(o.element.getAttribute("data-pixel-ratio"),10)||1,o.sourceEvents={mousemove:null,mousedown:null,mouseup:null,mousewheel:null},o.mousemove=function(a){var l=n._getRelativeMousePosition(a,o.element,o.pixelRatio),h=a.changedTouches;h&&(o.button=0,a.preventDefault()),o.absolute.x=l.x,o.absolute.y=l.y,o.position.x=o.absolute.x*o.scale.x+o.offset.x,o.position.y=o.absolute.y*o.scale.y+o.offset.y,o.sourceEvents.mousemove=a},o.mousedown=function(a){var l=n._getRelativeMousePosition(a,o.element,o.pixelRatio),h=a.changedTouches;h?(o.button=0,a.preventDefault()):o.button=a.button,o.absolute.x=l.x,o.absolute.y=l.y,o.position.x=o.absolute.x*o.scale.x+o.offset.x,o.position.y=o.absolute.y*o.scale.y+o.offset.y,o.mousedownPosition.x=o.position.x,o.mousedownPosition.y=o.position.y,o.sourceEvents.mousedown=a},o.mouseup=function(a){var l=n._getRelativeMousePosition(a,o.element,o.pixelRatio),h=a.changedTouches;h&&a.preventDefault(),o.button=-1,o.absolute.x=l.x,o.absolute.y=l.y,o.position.x=o.absolute.x*o.scale.x+o.offset.x,o.position.y=o.absolute.y*o.scale.y+o.offset.y,o.mouseupPosition.x=o.position.x,o.mouseupPosition.y=o.position.y,o.sourceEvents.mouseup=a},o.mousewheel=function(a){o.wheelDelta=Math.max(-1,Math.min(1,a.wheelDelta||-a.detail)),a.preventDefault(),o.sourceEvents.mousewheel=a},n.setElement(o,o.element),o},n.setElement=function(s,o){s.element=o,o.addEventListener("mousemove",s.mousemove,{passive:!0}),o.addEventListener("mousedown",s.mousedown,{passive:!0}),o.addEventListener("mouseup",s.mouseup,{passive:!0}),o.addEventListener("wheel",s.mousewheel,{passive:!1}),o.addEventListener("touchmove",s.mousemove,{passive:!1}),o.addEventListener("touchstart",s.mousedown,{passive:!1}),o.addEventListener("touchend",s.mouseup,{passive:!1})},n.clearSourceEvents=function(s){s.sourceEvents.mousemove=null,s.sourceEvents.mousedown=null,s.sourceEvents.mouseup=null,s.sourceEvents.mousewheel=null,s.wheelDelta=0},n.setOffset=function(s,o){s.offset.x=o.x,s.offset.y=o.y,s.position.x=s.absolute.x*s.scale.x+s.offset.x,s.position.y=s.absolute.y*s.scale.y+s.offset.y},n.setScale=function(s,o){s.scale.x=o.x,s.scale.y=o.y,s.position.x=s.absolute.x*s.scale.x+s.offset.x,s.position.y=s.absolute.y*s.scale.y+s.offset.y},n._getRelativeMousePosition=function(s,o,a){var l=o.getBoundingClientRect(),h=document.documentElement||document.body.parentNode||document.body,f=window.pageXOffset!==void 0?window.pageXOffset:h.scrollLeft,c=window.pageYOffset!==void 0?window.pageYOffset:h.scrollTop,u=s.changedTouches,d,p;return u?(d=u[0].pageX-l.left-f,p=u[0].pageY-l.top-c):(d=s.pageX-l.left-f,p=s.pageY-l.top-c),{x:d/(o.clientWidth/(o.width||o.clientWidth)*a),y:p/(o.clientHeight/(o.height||o.clientHeight)*a)}}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(0);(function(){n._registry={},n.register=function(s){if(n.isPlugin(s)||i.warn("Plugin.register:",n.toString(s),"does not implement all required fields."),s.name in n._registry){var o=n._registry[s.name],a=n.versionParse(s.version).number,l=n.versionParse(o.version).number;a>l?(i.warn("Plugin.register:",n.toString(o),"was upgraded to",n.toString(s)),n._registry[s.name]=s):a<l?i.warn("Plugin.register:",n.toString(o),"can not be downgraded to",n.toString(s)):s!==o&&i.warn("Plugin.register:",n.toString(s),"is already registered to different plugin object")}else n._registry[s.name]=s;return s},n.resolve=function(s){return n._registry[n.dependencyParse(s).name]},n.toString=function(s){return typeof s=="string"?s:(s.name||"anonymous")+"@"+(s.version||s.range||"0.0.0")},n.isPlugin=function(s){return s&&s.name&&s.version&&s.install},n.isUsed=function(s,o){return s.used.indexOf(o)>-1},n.isFor=function(s,o){var a=s.for&&n.dependencyParse(s.for);return!s.for||o.name===a.name&&n.versionSatisfies(o.version,a.range)},n.use=function(s,o){if(s.uses=(s.uses||[]).concat(o||[]),s.uses.length===0){i.warn("Plugin.use:",n.toString(s),"does not specify any dependencies to install.");return}for(var a=n.dependencies(s),l=i.topologicalSort(a),h=[],f=0;f<l.length;f+=1)if(l[f]!==s.name){var c=n.resolve(l[f]);if(!c){h.push("\u274C "+l[f]);continue}n.isUsed(s,c.name)||(n.isFor(c,s)||(i.warn("Plugin.use:",n.toString(c),"is for",c.for,"but installed on",n.toString(s)+"."),c._warned=!0),c.install?c.install(s):(i.warn("Plugin.use:",n.toString(c),"does not specify an install function."),c._warned=!0),c._warned?(h.push("\u{1F536} "+n.toString(c)),delete c._warned):h.push("\u2705 "+n.toString(c)),s.used.push(c.name))}h.length>0&&i.info(h.join("  "))},n.dependencies=function(s,o){var a=n.dependencyParse(s),l=a.name;if(o=o||{},!(l in o)){s=n.resolve(s)||s,o[l]=i.map(s.uses||[],function(f){n.isPlugin(f)&&n.register(f);var c=n.dependencyParse(f),u=n.resolve(f);return u&&!n.versionSatisfies(u.version,c.range)?(i.warn("Plugin.dependencies:",n.toString(u),"does not satisfy",n.toString(c),"used by",n.toString(a)+"."),u._warned=!0,s._warned=!0):u||(i.warn("Plugin.dependencies:",n.toString(f),"used by",n.toString(a),"could not be resolved."),s._warned=!0),c.name});for(var h=0;h<o[l].length;h+=1)n.dependencies(o[l][h],o);return o}},n.dependencyParse=function(s){if(i.isString(s)){var o=/^[\w-]+(@(\*|[\^~]?\d+\.\d+\.\d+(-[0-9A-Za-z-+]+)?))?$/;return o.test(s)||i.warn("Plugin.dependencyParse:",s,"is not a valid dependency string."),{name:s.split("@")[0],range:s.split("@")[1]||"*"}}return{name:s.name,range:s.range||s.version}},n.versionParse=function(s){var o=/^(\*)|(\^|~|>=|>)?\s*((\d+)\.(\d+)\.(\d+))(-[0-9A-Za-z-+]+)?$/;o.test(s)||i.warn("Plugin.versionParse:",s,"is not a valid version or range.");var a=o.exec(s),l=Number(a[4]),h=Number(a[5]),f=Number(a[6]);return{isRange:!!(a[1]||a[2]),version:a[3],range:s,operator:a[1]||a[2]||"",major:l,minor:h,patch:f,parts:[l,h,f],prerelease:a[7],number:l*1e8+h*1e4+f}},n.versionSatisfies=function(s,o){o=o||"*";var a=n.versionParse(o),l=n.versionParse(s);if(a.isRange){if(a.operator==="*"||s==="*")return!0;if(a.operator===">")return l.number>a.number;if(a.operator===">=")return l.number>=a.number;if(a.operator==="~")return l.major===a.major&&l.minor===a.minor&&l.patch>=a.patch;if(a.operator==="^")return a.major>0?l.major===a.major&&l.number>=a.number:a.minor>0?l.minor===a.minor&&l.patch>=a.patch:l.patch===a.patch}return s===o||s==="*"}})()}),(function(r,e){var t={};r.exports=t,(function(){t.create=function(n){return{vertex:n,normalImpulse:0,tangentImpulse:0}}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(7),s=t(18),o=t(13),a=t(19),l=t(5),h=t(6),f=t(10),c=t(0),u=t(4);(function(){n._deltaMax=1e3/60,n.create=function(d){d=d||{};var p={positionIterations:6,velocityIterations:4,constraintIterations:2,enableSleeping:!1,events:[],plugin:{},gravity:{x:0,y:1,scale:.001},timing:{timestamp:0,timeScale:1,lastDelta:0,lastElapsed:0,lastUpdatesPerFrame:0}},v=c.extend(p,d);return v.world=d.world||h.create({label:"World"}),v.pairs=d.pairs||a.create(),v.detector=d.detector||o.create(),v.detector.pairs=v.pairs,v.grid={buckets:[]},v.world.gravity=v.gravity,v.broadphase=v.grid,v.metrics={},v},n.update=function(d,p){var v=c.now(),g=d.world,m=d.detector,_=d.pairs,x=d.timing,y=x.timestamp,S;p>n._deltaMax&&c.warnOnce("Matter.Engine.update: delta argument is recommended to be less than or equal to",n._deltaMax.toFixed(3),"ms."),p=typeof p<"u"?p:c._baseDelta,p*=x.timeScale,x.timestamp+=p,x.lastDelta=p;var M={timestamp:x.timestamp,delta:p};l.trigger(d,"beforeUpdate",M);var E=h.allBodies(g),A=h.allConstraints(g);for(g.isModified&&(o.setBodies(m,E),h.setModified(g,!1,!1,!0)),d.enableSleeping&&i.update(E,p),n._bodiesApplyGravity(E,d.gravity),p>0&&n._bodiesUpdate(E,p),l.trigger(d,"beforeSolve",M),f.preSolveAll(E),S=0;S<d.constraintIterations;S++)f.solveAll(A,p);f.postSolveAll(E);var b=o.collisions(m);a.update(_,b,y),d.enableSleeping&&i.afterCollisions(_.list),_.collisionStart.length>0&&l.trigger(d,"collisionStart",{pairs:_.collisionStart,timestamp:x.timestamp,delta:p});var w=c.clamp(20/d.positionIterations,0,1);for(s.preSolvePosition(_.list),S=0;S<d.positionIterations;S++)s.solvePosition(_.list,p,w);for(s.postSolvePosition(E),f.preSolveAll(E),S=0;S<d.constraintIterations;S++)f.solveAll(A,p);for(f.postSolveAll(E),s.preSolveVelocity(_.list),S=0;S<d.velocityIterations;S++)s.solveVelocity(_.list,p);return n._bodiesUpdateVelocities(E),_.collisionActive.length>0&&l.trigger(d,"collisionActive",{pairs:_.collisionActive,timestamp:x.timestamp,delta:p}),_.collisionEnd.length>0&&l.trigger(d,"collisionEnd",{pairs:_.collisionEnd,timestamp:x.timestamp,delta:p}),n._bodiesClearForces(E),l.trigger(d,"afterUpdate",M),d.timing.lastElapsed=c.now()-v,d},n.merge=function(d,p){if(c.extend(d,p),p.world){d.world=p.world,n.clear(d);for(var v=h.allBodies(d.world),g=0;g<v.length;g++){var m=v[g];i.set(m,!1),m.id=c.nextId()}}},n.clear=function(d){a.clear(d.pairs),o.clear(d.detector)},n._bodiesClearForces=function(d){for(var p=d.length,v=0;v<p;v++){var g=d[v];g.force.x=0,g.force.y=0,g.torque=0}},n._bodiesApplyGravity=function(d,p){var v=typeof p.scale<"u"?p.scale:.001,g=d.length;if(!(p.x===0&&p.y===0||v===0))for(var m=0;m<g;m++){var _=d[m];_.isStatic||_.isSleeping||(_.force.y+=_.mass*p.y*v,_.force.x+=_.mass*p.x*v)}},n._bodiesUpdate=function(d,p){for(var v=d.length,g=0;g<v;g++){var m=d[g];m.isStatic||m.isSleeping||u.update(m,p)}},n._bodiesUpdateVelocities=function(d){for(var p=d.length,v=0;v<p;v++)u.updateVelocities(d[v])}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(3),s=t(0),o=t(1);(function(){n._restingThresh=2,n._restingThreshTangent=Math.sqrt(6),n._positionDampen=.9,n._positionWarming=.8,n._frictionNormalMultiplier=5,n._frictionMaxStatic=Number.MAX_VALUE,n.preSolvePosition=function(a){var l,h,f,c=a.length;for(l=0;l<c;l++)h=a[l],h.isActive&&(f=h.contactCount,h.collision.parentA.totalContacts+=f,h.collision.parentB.totalContacts+=f)},n.solvePosition=function(a,l,h){var f,c,u,d,p,v,g,m,_=n._positionDampen*(h||1),x=s.clamp(l/s._baseDelta,0,1),y=a.length;for(f=0;f<y;f++)c=a[f],!(!c.isActive||c.isSensor)&&(u=c.collision,d=u.parentA,p=u.parentB,v=u.normal,c.separation=u.depth+v.x*(p.positionImpulse.x-d.positionImpulse.x)+v.y*(p.positionImpulse.y-d.positionImpulse.y));for(f=0;f<y;f++)c=a[f],!(!c.isActive||c.isSensor)&&(u=c.collision,d=u.parentA,p=u.parentB,v=u.normal,m=c.separation-c.slop*x,(d.isStatic||p.isStatic)&&(m*=2),d.isStatic||d.isSleeping||(g=_/d.totalContacts,d.positionImpulse.x+=v.x*m*g,d.positionImpulse.y+=v.y*m*g),p.isStatic||p.isSleeping||(g=_/p.totalContacts,p.positionImpulse.x-=v.x*m*g,p.positionImpulse.y-=v.y*m*g))},n.postSolvePosition=function(a){for(var l=n._positionWarming,h=a.length,f=i.translate,c=o.update,u=0;u<h;u++){var d=a[u],p=d.positionImpulse,v=p.x,g=p.y,m=d.velocity;if(d.totalContacts=0,v!==0||g!==0){for(var _=0;_<d.parts.length;_++){var x=d.parts[_];f(x.vertices,p),c(x.bounds,x.vertices,m),x.position.x+=v,x.position.y+=g}d.positionPrev.x+=v,d.positionPrev.y+=g,v*m.x+g*m.y<0?(p.x=0,p.y=0):(p.x*=l,p.y*=l)}}},n.preSolveVelocity=function(a){var l=a.length,h,f;for(h=0;h<l;h++){var c=a[h];if(!(!c.isActive||c.isSensor)){var u=c.contacts,d=c.contactCount,p=c.collision,v=p.parentA,g=p.parentB,m=p.normal,_=p.tangent;for(f=0;f<d;f++){var x=u[f],y=x.vertex,S=x.normalImpulse,M=x.tangentImpulse;if(S!==0||M!==0){var E=m.x*S+_.x*M,A=m.y*S+_.y*M;v.isStatic||v.isSleeping||(v.positionPrev.x+=E*v.inverseMass,v.positionPrev.y+=A*v.inverseMass,v.anglePrev+=v.inverseInertia*((y.x-v.position.x)*A-(y.y-v.position.y)*E)),g.isStatic||g.isSleeping||(g.positionPrev.x-=E*g.inverseMass,g.positionPrev.y-=A*g.inverseMass,g.anglePrev-=g.inverseInertia*((y.x-g.position.x)*A-(y.y-g.position.y)*E))}}}}},n.solveVelocity=function(a,l){var h=l/s._baseDelta,f=h*h,c=f*h,u=-n._restingThresh*h,d=n._restingThreshTangent,p=n._frictionNormalMultiplier*h,v=n._frictionMaxStatic,g=a.length,m,_,x,y;for(x=0;x<g;x++){var S=a[x];if(!(!S.isActive||S.isSensor)){var M=S.collision,E=M.parentA,A=M.parentB,b=M.normal.x,w=M.normal.y,T=M.tangent.x,F=M.tangent.y,D=S.inverseMass,C=S.friction*S.frictionStatic*p,P=S.contacts,N=S.contactCount,z=1/N,O=E.position.x-E.positionPrev.x,K=E.position.y-E.positionPrev.y,ee=E.angle-E.anglePrev,oe=A.position.x-A.positionPrev.x,ae=A.position.y-A.positionPrev.y,Ge=A.angle-A.anglePrev;for(y=0;y<N;y++){var Ce=P[y],We=Ce.vertex,j=We.x-E.position.x,ne=We.y-E.position.y,ye=We.x-A.position.x,De=We.y-A.position.y,Se=O-ne*ee,st=K+j*ee,Ct=oe-De*Ge,U=ae+ye*Ge,ft=Se-Ct,$e=st-U,ke=b*ft+w*$e,be=T*ft+F*$e,ht=S.separation+ke,Ee=Math.min(ht,1);Ee=ht<0?0:Ee;var Ke=Ee*C;be<-Ke||be>Ke?(_=be>0?be:-be,m=S.friction*(be>0?1:-1)*c,m<-_?m=-_:m>_&&(m=_)):(m=be,_=v);var yt=j*w-ne*b,gt=ye*w-De*b,B=z/(D+E.inverseInertia*yt*yt+A.inverseInertia*gt*gt),I=(1+S.restitution)*ke*B;if(m*=B,ke<u)Ce.normalImpulse=0;else{var X=Ce.normalImpulse;Ce.normalImpulse+=I,Ce.normalImpulse>0&&(Ce.normalImpulse=0),I=Ce.normalImpulse-X}if(be<-d||be>d)Ce.tangentImpulse=0;else{var te=Ce.tangentImpulse;Ce.tangentImpulse+=m,Ce.tangentImpulse<-_&&(Ce.tangentImpulse=-_),Ce.tangentImpulse>_&&(Ce.tangentImpulse=_),m=Ce.tangentImpulse-te}var se=b*I+T*m,Q=w*I+F*m;E.isStatic||E.isSleeping||(E.positionPrev.x+=se*E.inverseMass,E.positionPrev.y+=Q*E.inverseMass,E.anglePrev+=(j*Q-ne*se)*E.inverseInertia),A.isStatic||A.isSleeping||(A.positionPrev.x-=se*A.inverseMass,A.positionPrev.y-=Q*A.inverseMass,A.anglePrev-=(ye*Q-De*se)*A.inverseInertia)}}}}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(9),s=t(0);(function(){n.create=function(o){return s.extend({table:{},list:[],collisionStart:[],collisionActive:[],collisionEnd:[]},o)},n.update=function(o,a,l){var h=i.update,f=i.create,c=i.setActive,u=o.table,d=o.list,p=d.length,v=p,g=o.collisionStart,m=o.collisionEnd,_=o.collisionActive,x=a.length,y=0,S=0,M=0,E,A,b;for(b=0;b<x;b++)E=a[b],A=E.pair,A?(A.isActive&&(_[M++]=A),h(A,E,l)):(A=f(E,l),u[A.id]=A,g[y++]=A,d[v++]=A);for(v=0,p=d.length,b=0;b<p;b++)A=d[b],A.timeUpdated>=l?d[v++]=A:(c(A,!1,l),A.collision.bodyA.sleepCounter>0&&A.collision.bodyB.sleepCounter>0?d[v++]=A:(m[S++]=A,delete u[A.id]));d.length!==v&&(d.length=v),g.length!==y&&(g.length=y),m.length!==S&&(m.length=S),_.length!==M&&(_.length=M)},n.clear=function(o){return o.table={},o.list.length=0,o.collisionStart.length=0,o.collisionActive.length=0,o.collisionEnd.length=0,o}})()}),(function(r,e,t){var n=r.exports=t(21);n.Axes=t(11),n.Bodies=t(12),n.Body=t(4),n.Bounds=t(1),n.Collision=t(8),n.Common=t(0),n.Composite=t(6),n.Composites=t(22),n.Constraint=t(10),n.Contact=t(16),n.Detector=t(13),n.Engine=t(17),n.Events=t(5),n.Grid=t(23),n.Mouse=t(14),n.MouseConstraint=t(24),n.Pair=t(9),n.Pairs=t(19),n.Plugin=t(15),n.Query=t(25),n.Render=t(26),n.Resolver=t(18),n.Runner=t(27),n.SAT=t(28),n.Sleeping=t(7),n.Svg=t(29),n.Vector=t(2),n.Vertices=t(3),n.World=t(30),n.Engine.run=n.Runner.run,n.Common.deprecated(n.Engine,"run","Engine.run \u27A4 use Matter.Runner.run(engine) instead")}),(function(r,e,t){var n={};r.exports=n;var i=t(15),s=t(0);(function(){n.name="matter-js",n.version="0.20.0",n.uses=[],n.used=[],n.use=function(){i.use(n,Array.prototype.slice.call(arguments))},n.before=function(o,a){return o=o.replace(/^Matter./,""),s.chainPathBefore(n,o,a)},n.after=function(o,a){return o=o.replace(/^Matter./,""),s.chainPathAfter(n,o,a)}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(6),s=t(10),o=t(0),a=t(4),l=t(12),h=o.deprecated;(function(){n.stack=function(f,c,u,d,p,v,g){for(var m=i.create({label:"Stack"}),_=f,x=c,y,S=0,M=0;M<d;M++){for(var E=0,A=0;A<u;A++){var b=g(_,x,A,M,y,S);if(b){var w=b.bounds.max.y-b.bounds.min.y,T=b.bounds.max.x-b.bounds.min.x;w>E&&(E=w),a.translate(b,{x:T*.5,y:w*.5}),_=b.bounds.max.x+p,i.addBody(m,b),y=b,S+=1}else _+=p}x+=E+v,_=f}return m},n.chain=function(f,c,u,d,p,v){for(var g=f.bodies,m=1;m<g.length;m++){var _=g[m-1],x=g[m],y=_.bounds.max.y-_.bounds.min.y,S=_.bounds.max.x-_.bounds.min.x,M=x.bounds.max.y-x.bounds.min.y,E=x.bounds.max.x-x.bounds.min.x,A={bodyA:_,pointA:{x:S*c,y:y*u},bodyB:x,pointB:{x:E*d,y:M*p}},b=o.extend(A,v);i.addConstraint(f,s.create(b))}return f.label+=" Chain",f},n.mesh=function(f,c,u,d,p){var v=f.bodies,g,m,_,x,y;for(g=0;g<u;g++){for(m=1;m<c;m++)_=v[m-1+g*c],x=v[m+g*c],i.addConstraint(f,s.create(o.extend({bodyA:_,bodyB:x},p)));if(g>0)for(m=0;m<c;m++)_=v[m+(g-1)*c],x=v[m+g*c],i.addConstraint(f,s.create(o.extend({bodyA:_,bodyB:x},p))),d&&m>0&&(y=v[m-1+(g-1)*c],i.addConstraint(f,s.create(o.extend({bodyA:y,bodyB:x},p)))),d&&m<c-1&&(y=v[m+1+(g-1)*c],i.addConstraint(f,s.create(o.extend({bodyA:y,bodyB:x},p))))}return f.label+=" Mesh",f},n.pyramid=function(f,c,u,d,p,v,g){return n.stack(f,c,u,d,p,v,function(m,_,x,y,S,M){var E=Math.min(d,Math.ceil(u/2)),A=S?S.bounds.max.x-S.bounds.min.x:0;if(!(y>E)){y=E-y;var b=y,w=u-1-y;if(!(x<b||x>w)){M===1&&a.translate(S,{x:(x+(u%2===1?1:-1))*A,y:0});var T=S?x*A:0;return g(f+T+x*p,_,x,y,S,M)}}})},n.newtonsCradle=function(f,c,u,d,p){for(var v=i.create({label:"Newtons Cradle"}),g=0;g<u;g++){var m=1.9,_=l.circle(f+g*(d*m),c+p,d,{inertia:1/0,restitution:1,friction:0,frictionAir:1e-4,slop:1}),x=s.create({pointA:{x:f+g*(d*m),y:c},bodyB:_});i.addBody(v,_),i.addConstraint(v,x)}return v},h(n,"newtonsCradle","Composites.newtonsCradle \u27A4 moved to newtonsCradle example"),n.car=function(f,c,u,d,p){var v=a.nextGroup(!0),g=20,m=-u*.5+g,_=u*.5-g,x=0,y=i.create({label:"Car"}),S=l.rectangle(f,c,u,d,{collisionFilter:{group:v},chamfer:{radius:d*.5},density:2e-4}),M=l.circle(f+m,c+x,p,{collisionFilter:{group:v},friction:.8}),E=l.circle(f+_,c+x,p,{collisionFilter:{group:v},friction:.8}),A=s.create({bodyB:S,pointB:{x:m,y:x},bodyA:M,stiffness:1,length:0}),b=s.create({bodyB:S,pointB:{x:_,y:x},bodyA:E,stiffness:1,length:0});return i.addBody(y,S),i.addBody(y,M),i.addBody(y,E),i.addConstraint(y,A),i.addConstraint(y,b),y},h(n,"car","Composites.car \u27A4 moved to car example"),n.softBody=function(f,c,u,d,p,v,g,m,_,x){_=o.extend({inertia:1/0},_),x=o.extend({stiffness:.2,render:{type:"line",anchors:!1}},x);var y=n.stack(f,c,u,d,p,v,function(S,M){return l.circle(S,M,m,_)});return n.mesh(y,u,d,g,x),y.label="Soft Body",y},h(n,"softBody","Composites.softBody \u27A4 moved to softBody and cloth examples")})()}),(function(r,e,t){var n={};r.exports=n;var i=t(9),s=t(0),o=s.deprecated;(function(){n.create=function(a){var l={buckets:{},pairs:{},pairsList:[],bucketWidth:48,bucketHeight:48};return s.extend(l,a)},n.update=function(a,l,h,f){var c,u,d,p=h.world,v=a.buckets,g,m,_=!1;for(c=0;c<l.length;c++){var x=l[c];if(!(x.isSleeping&&!f)&&!(p.bounds&&(x.bounds.max.x<p.bounds.min.x||x.bounds.min.x>p.bounds.max.x||x.bounds.max.y<p.bounds.min.y||x.bounds.min.y>p.bounds.max.y))){var y=n._getRegion(a,x);if(!x.region||y.id!==x.region.id||f){(!x.region||f)&&(x.region=y);var S=n._regionUnion(y,x.region);for(u=S.startCol;u<=S.endCol;u++)for(d=S.startRow;d<=S.endRow;d++){m=n._getBucketId(u,d),g=v[m];var M=u>=y.startCol&&u<=y.endCol&&d>=y.startRow&&d<=y.endRow,E=u>=x.region.startCol&&u<=x.region.endCol&&d>=x.region.startRow&&d<=x.region.endRow;!M&&E&&E&&g&&n._bucketRemoveBody(a,g,x),(x.region===y||M&&!E||f)&&(g||(g=n._createBucket(v,m)),n._bucketAddBody(a,g,x))}x.region=y,_=!0}}}_&&(a.pairsList=n._createActivePairsList(a))},o(n,"update","Grid.update \u27A4 replaced by Matter.Detector"),n.clear=function(a){a.buckets={},a.pairs={},a.pairsList=[]},o(n,"clear","Grid.clear \u27A4 replaced by Matter.Detector"),n._regionUnion=function(a,l){var h=Math.min(a.startCol,l.startCol),f=Math.max(a.endCol,l.endCol),c=Math.min(a.startRow,l.startRow),u=Math.max(a.endRow,l.endRow);return n._createRegion(h,f,c,u)},n._getRegion=function(a,l){var h=l.bounds,f=Math.floor(h.min.x/a.bucketWidth),c=Math.floor(h.max.x/a.bucketWidth),u=Math.floor(h.min.y/a.bucketHeight),d=Math.floor(h.max.y/a.bucketHeight);return n._createRegion(f,c,u,d)},n._createRegion=function(a,l,h,f){return{id:a+","+l+","+h+","+f,startCol:a,endCol:l,startRow:h,endRow:f}},n._getBucketId=function(a,l){return"C"+a+"R"+l},n._createBucket=function(a,l){var h=a[l]=[];return h},n._bucketAddBody=function(a,l,h){var f=a.pairs,c=i.id,u=l.length,d;for(d=0;d<u;d++){var p=l[d];if(!(h.id===p.id||h.isStatic&&p.isStatic)){var v=c(h,p),g=f[v];g?g[2]+=1:f[v]=[h,p,1]}}l.push(h)},n._bucketRemoveBody=function(a,l,h){var f=a.pairs,c=i.id,u;l.splice(s.indexOf(l,h),1);var d=l.length;for(u=0;u<d;u++){var p=f[c(h,l[u])];p&&(p[2]-=1)}},n._createActivePairsList=function(a){var l,h=a.pairs,f=s.keys(h),c=f.length,u=[],d;for(d=0;d<c;d++)l=h[f[d]],l[2]>0?u.push(l):delete h[f[d]];return u}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(3),s=t(7),o=t(14),a=t(5),l=t(13),h=t(10),f=t(6),c=t(0),u=t(1);(function(){n.create=function(d,p){var v=(d?d.mouse:null)||(p?p.mouse:null);v||(d&&d.render&&d.render.canvas?v=o.create(d.render.canvas):p&&p.element?v=o.create(p.element):(v=o.create(),c.warn("MouseConstraint.create: options.mouse was undefined, options.element was undefined, may not function as expected")));var g=h.create({label:"Mouse Constraint",pointA:v.position,pointB:{x:0,y:0},length:.01,stiffness:.1,angularStiffness:1,render:{strokeStyle:"#90EE90",lineWidth:3}}),m={type:"mouseConstraint",mouse:v,element:null,body:null,constraint:g,collisionFilter:{category:1,mask:4294967295,group:0}},_=c.extend(m,p);return a.on(d,"beforeUpdate",function(){var x=f.allBodies(d.world);n.update(_,x),n._triggerEvents(_)}),_},n.update=function(d,p){var v=d.mouse,g=d.constraint,m=d.body;if(v.button===0){if(g.bodyB)s.set(g.bodyB,!1),g.pointA=v.position;else for(var _=0;_<p.length;_++)if(m=p[_],u.contains(m.bounds,v.position)&&l.canCollide(m.collisionFilter,d.collisionFilter))for(var x=m.parts.length>1?1:0;x<m.parts.length;x++){var y=m.parts[x];if(i.contains(y.vertices,v.position)){g.pointA=v.position,g.bodyB=d.body=m,g.pointB={x:v.position.x-m.position.x,y:v.position.y-m.position.y},g.angleB=m.angle,s.set(m,!1),a.trigger(d,"startdrag",{mouse:v,body:m});break}}}else g.bodyB=d.body=null,g.pointB=null,m&&a.trigger(d,"enddrag",{mouse:v,body:m})},n._triggerEvents=function(d){var p=d.mouse,v=p.sourceEvents;v.mousemove&&a.trigger(d,"mousemove",{mouse:p}),v.mousedown&&a.trigger(d,"mousedown",{mouse:p}),v.mouseup&&a.trigger(d,"mouseup",{mouse:p}),o.clearSourceEvents(p)}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(2),s=t(8),o=t(1),a=t(12),l=t(3);(function(){n.collides=function(h,f){for(var c=[],u=f.length,d=h.bounds,p=s.collides,v=o.overlaps,g=0;g<u;g++){var m=f[g],_=m.parts.length,x=_===1?0:1;if(v(m.bounds,d))for(var y=x;y<_;y++){var S=m.parts[y];if(v(S.bounds,d)){var M=p(S,h);if(M){c.push(M);break}}}}return c},n.ray=function(h,f,c,u){u=u||1e-100;for(var d=i.angle(f,c),p=i.magnitude(i.sub(f,c)),v=(c.x+f.x)*.5,g=(c.y+f.y)*.5,m=a.rectangle(v,g,p,u,{angle:d}),_=n.collides(m,h),x=0;x<_.length;x+=1){var y=_[x];y.body=y.bodyB=y.bodyA}return _},n.region=function(h,f,c){for(var u=[],d=0;d<h.length;d++){var p=h[d],v=o.overlaps(p.bounds,f);(v&&!c||!v&&c)&&u.push(p)}return u},n.point=function(h,f){for(var c=[],u=0;u<h.length;u++){var d=h[u];if(o.contains(d.bounds,f))for(var p=d.parts.length===1?0:1;p<d.parts.length;p++){var v=d.parts[p];if(o.contains(v.bounds,f)&&l.contains(v.vertices,f)){c.push(d);break}}}return c}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(4),s=t(0),o=t(6),a=t(1),l=t(5),h=t(2),f=t(14);(function(){var c,u;typeof window<"u"&&(c=window.requestAnimationFrame||window.webkitRequestAnimationFrame||window.mozRequestAnimationFrame||window.msRequestAnimationFrame||function(x){window.setTimeout(function(){x(s.now())},1e3/60)},u=window.cancelAnimationFrame||window.mozCancelAnimationFrame||window.webkitCancelAnimationFrame||window.msCancelAnimationFrame),n._goodFps=30,n._goodDelta=1e3/60,n.create=function(x){var y={engine:null,element:null,canvas:null,mouse:null,frameRequestId:null,timing:{historySize:60,delta:0,deltaHistory:[],lastTime:0,lastTimestamp:0,lastElapsed:0,timestampElapsed:0,timestampElapsedHistory:[],engineDeltaHistory:[],engineElapsedHistory:[],engineUpdatesHistory:[],elapsedHistory:[]},options:{width:800,height:600,pixelRatio:1,background:"#14151f",wireframeBackground:"#14151f",wireframeStrokeStyle:"#bbb",hasBounds:!!x.bounds,enabled:!0,wireframes:!0,showSleeping:!0,showDebug:!1,showStats:!1,showPerformance:!1,showBounds:!1,showVelocity:!1,showCollisions:!1,showSeparations:!1,showAxes:!1,showPositions:!1,showAngleIndicator:!1,showIds:!1,showVertexNumbers:!1,showConvexHulls:!1,showInternalEdges:!1,showMousePosition:!1}},S=s.extend(y,x);return S.canvas&&(S.canvas.width=S.options.width||S.canvas.width,S.canvas.height=S.options.height||S.canvas.height),S.mouse=x.mouse,S.engine=x.engine,S.canvas=S.canvas||v(S.options.width,S.options.height),S.context=S.canvas.getContext("2d"),S.textures={},S.bounds=S.bounds||{min:{x:0,y:0},max:{x:S.canvas.width,y:S.canvas.height}},S.controller=n,S.options.showBroadphase=!1,S.options.pixelRatio!==1&&n.setPixelRatio(S,S.options.pixelRatio),s.isElement(S.element)&&S.element.appendChild(S.canvas),S},n.run=function(x){(function y(S){x.frameRequestId=c(y),d(x,S),n.world(x,S),x.context.setTransform(x.options.pixelRatio,0,0,x.options.pixelRatio,0,0),(x.options.showStats||x.options.showDebug)&&n.stats(x,x.context,S),(x.options.showPerformance||x.options.showDebug)&&n.performance(x,x.context,S),x.context.setTransform(1,0,0,1,0,0)})()},n.stop=function(x){u(x.frameRequestId)},n.setPixelRatio=function(x,y){var S=x.options,M=x.canvas;y==="auto"&&(y=g(M)),S.pixelRatio=y,M.setAttribute("data-pixel-ratio",y),M.width=S.width*y,M.height=S.height*y,M.style.width=S.width+"px",M.style.height=S.height+"px"},n.setSize=function(x,y,S){x.options.width=y,x.options.height=S,x.bounds.max.x=x.bounds.min.x+y,x.bounds.max.y=x.bounds.min.y+S,x.options.pixelRatio!==1?n.setPixelRatio(x,x.options.pixelRatio):(x.canvas.width=y,x.canvas.height=S)},n.lookAt=function(x,y,S,M){M=typeof M<"u"?M:!0,y=s.isArray(y)?y:[y],S=S||{x:0,y:0};for(var E={min:{x:1/0,y:1/0},max:{x:-1/0,y:-1/0}},A=0;A<y.length;A+=1){var b=y[A],w=b.bounds?b.bounds.min:b.min||b.position||b,T=b.bounds?b.bounds.max:b.max||b.position||b;w&&T&&(w.x<E.min.x&&(E.min.x=w.x),T.x>E.max.x&&(E.max.x=T.x),w.y<E.min.y&&(E.min.y=w.y),T.y>E.max.y&&(E.max.y=T.y))}var F=E.max.x-E.min.x+2*S.x,D=E.max.y-E.min.y+2*S.y,C=x.canvas.height,P=x.canvas.width,N=P/C,z=F/D,O=1,K=1;z>N?K=z/N:O=N/z,x.options.hasBounds=!0,x.bounds.min.x=E.min.x,x.bounds.max.x=E.min.x+F*O,x.bounds.min.y=E.min.y,x.bounds.max.y=E.min.y+D*K,M&&(x.bounds.min.x+=F*.5-F*O*.5,x.bounds.max.x+=F*.5-F*O*.5,x.bounds.min.y+=D*.5-D*K*.5,x.bounds.max.y+=D*.5-D*K*.5),x.bounds.min.x-=S.x,x.bounds.max.x-=S.x,x.bounds.min.y-=S.y,x.bounds.max.y-=S.y,x.mouse&&(f.setScale(x.mouse,{x:(x.bounds.max.x-x.bounds.min.x)/x.canvas.width,y:(x.bounds.max.y-x.bounds.min.y)/x.canvas.height}),f.setOffset(x.mouse,x.bounds.min))},n.startViewTransform=function(x){var y=x.bounds.max.x-x.bounds.min.x,S=x.bounds.max.y-x.bounds.min.y,M=y/x.options.width,E=S/x.options.height;x.context.setTransform(x.options.pixelRatio/M,0,0,x.options.pixelRatio/E,0,0),x.context.translate(-x.bounds.min.x,-x.bounds.min.y)},n.endViewTransform=function(x){x.context.setTransform(x.options.pixelRatio,0,0,x.options.pixelRatio,0,0)},n.world=function(x,y){var S=s.now(),M=x.engine,E=M.world,A=x.canvas,b=x.context,w=x.options,T=x.timing,F=o.allBodies(E),D=o.allConstraints(E),C=w.wireframes?w.wireframeBackground:w.background,P=[],N=[],z,O={timestamp:M.timing.timestamp};if(l.trigger(x,"beforeRender",O),x.currentBackground!==C&&_(x,C),b.globalCompositeOperation="source-in",b.fillStyle="transparent",b.fillRect(0,0,A.width,A.height),b.globalCompositeOperation="source-over",w.hasBounds){for(z=0;z<F.length;z++){var K=F[z];a.overlaps(K.bounds,x.bounds)&&P.push(K)}for(z=0;z<D.length;z++){var ee=D[z],oe=ee.bodyA,ae=ee.bodyB,Ge=ee.pointA,Ce=ee.pointB;oe&&(Ge=h.add(oe.position,ee.pointA)),ae&&(Ce=h.add(ae.position,ee.pointB)),!(!Ge||!Ce)&&(a.contains(x.bounds,Ge)||a.contains(x.bounds,Ce))&&N.push(ee)}n.startViewTransform(x),x.mouse&&(f.setScale(x.mouse,{x:(x.bounds.max.x-x.bounds.min.x)/x.options.width,y:(x.bounds.max.y-x.bounds.min.y)/x.options.height}),f.setOffset(x.mouse,x.bounds.min))}else N=D,P=F,x.options.pixelRatio!==1&&x.context.setTransform(x.options.pixelRatio,0,0,x.options.pixelRatio,0,0);!w.wireframes||M.enableSleeping&&w.showSleeping?n.bodies(x,P,b):(w.showConvexHulls&&n.bodyConvexHulls(x,P,b),n.bodyWireframes(x,P,b)),w.showBounds&&n.bodyBounds(x,P,b),(w.showAxes||w.showAngleIndicator)&&n.bodyAxes(x,P,b),w.showPositions&&n.bodyPositions(x,P,b),w.showVelocity&&n.bodyVelocity(x,P,b),w.showIds&&n.bodyIds(x,P,b),w.showSeparations&&n.separations(x,M.pairs.list,b),w.showCollisions&&n.collisions(x,M.pairs.list,b),w.showVertexNumbers&&n.vertexNumbers(x,P,b),w.showMousePosition&&n.mousePosition(x,x.mouse,b),n.constraints(N,b),w.hasBounds&&n.endViewTransform(x),l.trigger(x,"afterRender",O),T.lastElapsed=s.now()-S},n.stats=function(x,y,S){for(var M=x.engine,E=M.world,A=o.allBodies(E),b=0,w=55,T=44,F=0,D=0,C=0;C<A.length;C+=1)b+=A[C].parts.length;var P={Part:b,Body:A.length,Cons:o.allConstraints(E).length,Comp:o.allComposites(E).length,Pair:M.pairs.list.length};y.fillStyle="#0e0f19",y.fillRect(F,D,w*5.5,T),y.font="12px Arial",y.textBaseline="top",y.textAlign="right";for(var N in P){var z=P[N];y.fillStyle="#aaa",y.fillText(N,F+w,D+8),y.fillStyle="#eee",y.fillText(z,F+w,D+26),F+=w}},n.performance=function(x,y){var S=x.engine,M=x.timing,E=M.deltaHistory,A=M.elapsedHistory,b=M.timestampElapsedHistory,w=M.engineDeltaHistory,T=M.engineUpdatesHistory,F=M.engineElapsedHistory,D=S.timing.lastUpdatesPerFrame,C=S.timing.lastDelta,P=p(E),N=p(A),z=p(w),O=p(T),K=p(F),ee=p(b),oe=ee/P||0,ae=Math.round(P/C),Ge=1e3/P||0,Ce=4,We=12,j=60,ne=34,ye=10,De=69;y.fillStyle="#0e0f19",y.fillRect(0,50,We*5+j*6+22,ne),n.status(y,ye,De,j,Ce,E.length,Math.round(Ge)+" fps",Ge/n._goodFps,function(Se){return E[Se]/P-1}),n.status(y,ye+We+j,De,j,Ce,w.length,C.toFixed(2)+" dt",n._goodDelta/C,function(Se){return w[Se]/z-1}),n.status(y,ye+(We+j)*2,De,j,Ce,T.length,D+" upf",Math.pow(s.clamp(O/ae||1,0,1),4),function(Se){return T[Se]/O-1}),n.status(y,ye+(We+j)*3,De,j,Ce,F.length,K.toFixed(2)+" ut",1-D*K/n._goodFps,function(Se){return F[Se]/K-1}),n.status(y,ye+(We+j)*4,De,j,Ce,A.length,N.toFixed(2)+" rt",1-N/n._goodFps,function(Se){return A[Se]/N-1}),n.status(y,ye+(We+j)*5,De,j,Ce,b.length,oe.toFixed(2)+" x",oe*oe*oe,function(Se){return(b[Se]/E[Se]/oe||0)-1})},n.status=function(x,y,S,M,E,A,b,w,T){x.strokeStyle="#888",x.fillStyle="#444",x.lineWidth=1,x.fillRect(y,S+7,M,1),x.beginPath(),x.moveTo(y,S+7-E*s.clamp(.4*T(0),-2,2));for(var F=0;F<M;F+=1)x.lineTo(y+F,S+7-(F<A?E*s.clamp(.4*T(F),-2,2):0));x.stroke(),x.fillStyle="hsl("+s.clamp(25+95*w,0,120)+",100%,60%)",x.fillRect(y,S-7,4,4),x.font="12px Arial",x.textBaseline="middle",x.textAlign="right",x.fillStyle="#eee",x.fillText(b,y+M,S-5)},n.constraints=function(x,y){for(var S=y,M=0;M<x.length;M++){var E=x[M];if(!(!E.render.visible||!E.pointA||!E.pointB)){var A=E.bodyA,b=E.bodyB,w,T;if(A?w=h.add(A.position,E.pointA):w=E.pointA,E.render.type==="pin")S.beginPath(),S.arc(w.x,w.y,3,0,2*Math.PI),S.closePath();else{if(b?T=h.add(b.position,E.pointB):T=E.pointB,S.beginPath(),S.moveTo(w.x,w.y),E.render.type==="spring")for(var F=h.sub(T,w),D=h.perp(h.normalise(F)),C=Math.ceil(s.clamp(E.length/5,12,20)),P,N=1;N<C;N+=1)P=N%2===0?1:-1,S.lineTo(w.x+F.x*(N/C)+D.x*P*4,w.y+F.y*(N/C)+D.y*P*4);S.lineTo(T.x,T.y)}E.render.lineWidth&&(S.lineWidth=E.render.lineWidth,S.strokeStyle=E.render.strokeStyle,S.stroke()),E.render.anchors&&(S.fillStyle=E.render.strokeStyle,S.beginPath(),S.arc(w.x,w.y,3,0,2*Math.PI),S.arc(T.x,T.y,3,0,2*Math.PI),S.closePath(),S.fill())}}},n.bodies=function(x,y,S){var M=S,E=x.engine,A=x.options,b=A.showInternalEdges||!A.wireframes,w,T,F,D;for(F=0;F<y.length;F++)if(w=y[F],!!w.render.visible){for(D=w.parts.length>1?1:0;D<w.parts.length;D++)if(T=w.parts[D],!!T.render.visible){if(A.showSleeping&&w.isSleeping?M.globalAlpha=.5*T.render.opacity:T.render.opacity!==1&&(M.globalAlpha=T.render.opacity),T.render.sprite&&T.render.sprite.texture&&!A.wireframes){var C=T.render.sprite,P=m(x,C.texture);M.translate(T.position.x,T.position.y),M.rotate(T.angle),M.drawImage(P,P.width*-C.xOffset*C.xScale,P.height*-C.yOffset*C.yScale,P.width*C.xScale,P.height*C.yScale),M.rotate(-T.angle),M.translate(-T.position.x,-T.position.y)}else{if(T.circleRadius)M.beginPath(),M.arc(T.position.x,T.position.y,T.circleRadius,0,2*Math.PI);else{M.beginPath(),M.moveTo(T.vertices[0].x,T.vertices[0].y);for(var N=1;N<T.vertices.length;N++)!T.vertices[N-1].isInternal||b?M.lineTo(T.vertices[N].x,T.vertices[N].y):M.moveTo(T.vertices[N].x,T.vertices[N].y),T.vertices[N].isInternal&&!b&&M.moveTo(T.vertices[(N+1)%T.vertices.length].x,T.vertices[(N+1)%T.vertices.length].y);M.lineTo(T.vertices[0].x,T.vertices[0].y),M.closePath()}A.wireframes?(M.lineWidth=1,M.strokeStyle=x.options.wireframeStrokeStyle,M.stroke()):(M.fillStyle=T.render.fillStyle,T.render.lineWidth&&(M.lineWidth=T.render.lineWidth,M.strokeStyle=T.render.strokeStyle,M.stroke()),M.fill())}M.globalAlpha=1}}},n.bodyWireframes=function(x,y,S){var M=S,E=x.options.showInternalEdges,A,b,w,T,F;for(M.beginPath(),w=0;w<y.length;w++)if(A=y[w],!!A.render.visible)for(F=A.parts.length>1?1:0;F<A.parts.length;F++){for(b=A.parts[F],M.moveTo(b.vertices[0].x,b.vertices[0].y),T=1;T<b.vertices.length;T++)!b.vertices[T-1].isInternal||E?M.lineTo(b.vertices[T].x,b.vertices[T].y):M.moveTo(b.vertices[T].x,b.vertices[T].y),b.vertices[T].isInternal&&!E&&M.moveTo(b.vertices[(T+1)%b.vertices.length].x,b.vertices[(T+1)%b.vertices.length].y);M.lineTo(b.vertices[0].x,b.vertices[0].y)}M.lineWidth=1,M.strokeStyle=x.options.wireframeStrokeStyle,M.stroke()},n.bodyConvexHulls=function(x,y,S){var M=S,E,A,b,w,T;for(M.beginPath(),b=0;b<y.length;b++)if(E=y[b],!(!E.render.visible||E.parts.length===1)){for(M.moveTo(E.vertices[0].x,E.vertices[0].y),w=1;w<E.vertices.length;w++)M.lineTo(E.vertices[w].x,E.vertices[w].y);M.lineTo(E.vertices[0].x,E.vertices[0].y)}M.lineWidth=1,M.strokeStyle="rgba(255,255,255,0.2)",M.stroke()},n.vertexNumbers=function(x,y,S){var M=S,E,A,b;for(E=0;E<y.length;E++){var w=y[E].parts;for(b=w.length>1?1:0;b<w.length;b++){var T=w[b];for(A=0;A<T.vertices.length;A++)M.fillStyle="rgba(255,255,255,0.2)",M.fillText(E+"_"+A,T.position.x+(T.vertices[A].x-T.position.x)*.8,T.position.y+(T.vertices[A].y-T.position.y)*.8)}}},n.mousePosition=function(x,y,S){var M=S;M.fillStyle="rgba(255,255,255,0.8)",M.fillText(y.position.x+"  "+y.position.y,y.position.x+5,y.position.y-5)},n.bodyBounds=function(x,y,S){var M=S,E=x.engine,A=x.options;M.beginPath();for(var b=0;b<y.length;b++){var w=y[b];if(w.render.visible)for(var T=y[b].parts,F=T.length>1?1:0;F<T.length;F++){var D=T[F];M.rect(D.bounds.min.x,D.bounds.min.y,D.bounds.max.x-D.bounds.min.x,D.bounds.max.y-D.bounds.min.y)}}A.wireframes?M.strokeStyle="rgba(255,255,255,0.08)":M.strokeStyle="rgba(0,0,0,0.1)",M.lineWidth=1,M.stroke()},n.bodyAxes=function(x,y,S){var M=S,E=x.engine,A=x.options,b,w,T,F;for(M.beginPath(),w=0;w<y.length;w++){var D=y[w],C=D.parts;if(D.render.visible)if(A.showAxes)for(T=C.length>1?1:0;T<C.length;T++)for(b=C[T],F=0;F<b.axes.length;F++){var P=b.axes[F];M.moveTo(b.position.x,b.position.y),M.lineTo(b.position.x+P.x*20,b.position.y+P.y*20)}else for(T=C.length>1?1:0;T<C.length;T++)for(b=C[T],F=0;F<b.axes.length;F++)M.moveTo(b.position.x,b.position.y),M.lineTo((b.vertices[0].x+b.vertices[b.vertices.length-1].x)/2,(b.vertices[0].y+b.vertices[b.vertices.length-1].y)/2)}A.wireframes?(M.strokeStyle="indianred",M.lineWidth=1):(M.strokeStyle="rgba(255, 255, 255, 0.4)",M.globalCompositeOperation="overlay",M.lineWidth=2),M.stroke(),M.globalCompositeOperation="source-over"},n.bodyPositions=function(x,y,S){var M=S,E=x.engine,A=x.options,b,w,T,F;for(M.beginPath(),T=0;T<y.length;T++)if(b=y[T],!!b.render.visible)for(F=0;F<b.parts.length;F++)w=b.parts[F],M.arc(w.position.x,w.position.y,3,0,2*Math.PI,!1),M.closePath();for(A.wireframes?M.fillStyle="indianred":M.fillStyle="rgba(0,0,0,0.5)",M.fill(),M.beginPath(),T=0;T<y.length;T++)b=y[T],b.render.visible&&(M.arc(b.positionPrev.x,b.positionPrev.y,2,0,2*Math.PI,!1),M.closePath());M.fillStyle="rgba(255,165,0,0.8)",M.fill()},n.bodyVelocity=function(x,y,S){var M=S;M.beginPath();for(var E=0;E<y.length;E++){var A=y[E];if(A.render.visible){var b=i.getVelocity(A);M.moveTo(A.position.x,A.position.y),M.lineTo(A.position.x+b.x,A.position.y+b.y)}}M.lineWidth=3,M.strokeStyle="cornflowerblue",M.stroke()},n.bodyIds=function(x,y,S){var M=S,E,A;for(E=0;E<y.length;E++)if(y[E].render.visible){var b=y[E].parts;for(A=b.length>1?1:0;A<b.length;A++){var w=b[A];M.font="12px Arial",M.fillStyle="rgba(255,255,255,0.5)",M.fillText(w.id,w.position.x+10,w.position.y-10)}}},n.collisions=function(x,y,S){var M=S,E=x.options,A,b,w,T,F,D,C;for(M.beginPath(),D=0;D<y.length;D++)if(A=y[D],!!A.isActive)for(b=A.collision,C=0;C<A.contactCount;C++){var P=A.contacts[C],N=P.vertex;M.rect(N.x-1.5,N.y-1.5,3.5,3.5)}for(E.wireframes?M.fillStyle="rgba(255,255,255,0.7)":M.fillStyle="orange",M.fill(),M.beginPath(),D=0;D<y.length;D++)if(A=y[D],!!A.isActive&&(b=A.collision,A.contactCount>0)){var z=A.contacts[0].vertex.x,O=A.contacts[0].vertex.y;A.contactCount===2&&(z=(A.contacts[0].vertex.x+A.contacts[1].vertex.x)/2,O=(A.contacts[0].vertex.y+A.contacts[1].vertex.y)/2),b.bodyB===b.supports[0].body||b.bodyA.isStatic===!0?M.moveTo(z-b.normal.x*8,O-b.normal.y*8):M.moveTo(z+b.normal.x*8,O+b.normal.y*8),M.lineTo(z,O)}E.wireframes?M.strokeStyle="rgba(255,165,0,0.7)":M.strokeStyle="orange",M.lineWidth=1,M.stroke()},n.separations=function(x,y,S){var M=S,E=x.options,A,b,w,T,F,D,C;for(M.beginPath(),D=0;D<y.length;D++)if(A=y[D],!!A.isActive){b=A.collision,T=b.bodyA,F=b.bodyB;var P=1;!F.isStatic&&!T.isStatic&&(P=.5),F.isStatic&&(P=0),M.moveTo(F.position.x,F.position.y),M.lineTo(F.position.x-b.penetration.x*P,F.position.y-b.penetration.y*P),P=1,!F.isStatic&&!T.isStatic&&(P=.5),T.isStatic&&(P=0),M.moveTo(T.position.x,T.position.y),M.lineTo(T.position.x+b.penetration.x*P,T.position.y+b.penetration.y*P)}E.wireframes?M.strokeStyle="rgba(255,165,0,0.5)":M.strokeStyle="orange",M.stroke()},n.inspector=function(x,y){var S=x.engine,M=x.selected,E=x.render,A=E.options,b;if(A.hasBounds){var w=E.bounds.max.x-E.bounds.min.x,T=E.bounds.max.y-E.bounds.min.y,F=w/E.options.width,D=T/E.options.height;y.scale(1/F,1/D),y.translate(-E.bounds.min.x,-E.bounds.min.y)}for(var C=0;C<M.length;C++){var P=M[C].data;switch(y.translate(.5,.5),y.lineWidth=1,y.strokeStyle="rgba(255,165,0,0.9)",y.setLineDash([1,2]),P.type){case"body":b=P.bounds,y.beginPath(),y.rect(Math.floor(b.min.x-3),Math.floor(b.min.y-3),Math.floor(b.max.x-b.min.x+6),Math.floor(b.max.y-b.min.y+6)),y.closePath(),y.stroke();break;case"constraint":var N=P.pointA;P.bodyA&&(N=P.pointB),y.beginPath(),y.arc(N.x,N.y,10,0,2*Math.PI),y.closePath(),y.stroke();break}y.setLineDash([]),y.translate(-.5,-.5)}x.selectStart!==null&&(y.translate(.5,.5),y.lineWidth=1,y.strokeStyle="rgba(255,165,0,0.6)",y.fillStyle="rgba(255,165,0,0.1)",b=x.selectBounds,y.beginPath(),y.rect(Math.floor(b.min.x),Math.floor(b.min.y),Math.floor(b.max.x-b.min.x),Math.floor(b.max.y-b.min.y)),y.closePath(),y.stroke(),y.fill(),y.translate(-.5,-.5)),A.hasBounds&&y.setTransform(1,0,0,1,0,0)};var d=function(x,y){var S=x.engine,M=x.timing,E=M.historySize,A=S.timing.timestamp;M.delta=y-M.lastTime||n._goodDelta,M.lastTime=y,M.timestampElapsed=A-M.lastTimestamp||0,M.lastTimestamp=A,M.deltaHistory.unshift(M.delta),M.deltaHistory.length=Math.min(M.deltaHistory.length,E),M.engineDeltaHistory.unshift(S.timing.lastDelta),M.engineDeltaHistory.length=Math.min(M.engineDeltaHistory.length,E),M.timestampElapsedHistory.unshift(M.timestampElapsed),M.timestampElapsedHistory.length=Math.min(M.timestampElapsedHistory.length,E),M.engineUpdatesHistory.unshift(S.timing.lastUpdatesPerFrame),M.engineUpdatesHistory.length=Math.min(M.engineUpdatesHistory.length,E),M.engineElapsedHistory.unshift(S.timing.lastElapsed),M.engineElapsedHistory.length=Math.min(M.engineElapsedHistory.length,E),M.elapsedHistory.unshift(M.lastElapsed),M.elapsedHistory.length=Math.min(M.elapsedHistory.length,E)},p=function(x){for(var y=0,S=0;S<x.length;S+=1)y+=x[S];return y/x.length||0},v=function(x,y){var S=document.createElement("canvas");return S.width=x,S.height=y,S.oncontextmenu=function(){return!1},S.onselectstart=function(){return!1},S},g=function(x){var y=x.getContext("2d"),S=window.devicePixelRatio||1,M=y.webkitBackingStorePixelRatio||y.mozBackingStorePixelRatio||y.msBackingStorePixelRatio||y.oBackingStorePixelRatio||y.backingStorePixelRatio||1;return S/M},m=function(x,y){var S=x.textures[y];return S||(S=x.textures[y]=new Image,S.src=y,S)},_=function(x,y){var S=y;/(jpg|gif|png)$/.test(y)&&(S="url("+y+")"),x.canvas.style.background=S,x.canvas.style.backgroundSize="contain",x.currentBackground=y}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(5),s=t(17),o=t(0);(function(){n._maxFrameDelta=1e3/15,n._frameDeltaFallback=1e3/60,n._timeBufferMargin=1.5,n._elapsedNextEstimate=1,n._smoothingLowerBound=.1,n._smoothingUpperBound=.9,n.create=function(l){var h={delta:16.666666666666668,frameDelta:null,frameDeltaSmoothing:!0,frameDeltaSnapping:!0,frameDeltaHistory:[],frameDeltaHistorySize:100,frameRequestId:null,timeBuffer:0,timeLastTick:null,maxUpdates:null,maxFrameTime:33.333333333333336,lastUpdatesDeferred:0,enabled:!0},f=o.extend(h,l);return f.fps=0,f},n.run=function(l,h){return l.timeBuffer=n._frameDeltaFallback,(function f(c){l.frameRequestId=n._onNextFrame(l,f),c&&l.enabled&&n.tick(l,h,c)})(),l},n.tick=function(l,h,f){var c=o.now(),u=l.delta,d=0,p=f-l.timeLastTick;if((!p||!l.timeLastTick||p>Math.max(n._maxFrameDelta,l.maxFrameTime))&&(p=l.frameDelta||n._frameDeltaFallback),l.frameDeltaSmoothing){l.frameDeltaHistory.push(p),l.frameDeltaHistory=l.frameDeltaHistory.slice(-l.frameDeltaHistorySize);var v=l.frameDeltaHistory.slice(0).sort(),g=l.frameDeltaHistory.slice(v.length*n._smoothingLowerBound,v.length*n._smoothingUpperBound),m=a(g);p=m||p}l.frameDeltaSnapping&&(p=1e3/Math.round(1e3/p)),l.frameDelta=p,l.timeLastTick=f,l.timeBuffer+=l.frameDelta,l.timeBuffer=o.clamp(l.timeBuffer,0,l.frameDelta+u*n._timeBufferMargin),l.lastUpdatesDeferred=0;var _=l.maxUpdates||Math.ceil(l.maxFrameTime/u),x={timestamp:h.timing.timestamp};i.trigger(l,"beforeTick",x),i.trigger(l,"tick",x);for(var y=o.now();u>0&&l.timeBuffer>=u*n._timeBufferMargin;){i.trigger(l,"beforeUpdate",x),s.update(h,u),i.trigger(l,"afterUpdate",x),l.timeBuffer-=u,d+=1;var S=o.now()-c,M=o.now()-y,E=S+n._elapsedNextEstimate*M/d;if(d>=_||E>l.maxFrameTime){l.lastUpdatesDeferred=Math.round(Math.max(0,l.timeBuffer/u-n._timeBufferMargin));break}}h.timing.lastUpdatesPerFrame=d,i.trigger(l,"afterTick",x),l.frameDeltaHistory.length>=100&&(l.lastUpdatesDeferred&&Math.round(l.frameDelta/u)>_?o.warnOnce("Matter.Runner: runner reached runner.maxUpdates, see docs."):l.lastUpdatesDeferred&&o.warnOnce("Matter.Runner: runner reached runner.maxFrameTime, see docs."),typeof l.isFixed<"u"&&o.warnOnce("Matter.Runner: runner.isFixed is now redundant, see docs."),(l.deltaMin||l.deltaMax)&&o.warnOnce("Matter.Runner: runner.deltaMin and runner.deltaMax were removed, see docs."),l.fps!==0&&o.warnOnce("Matter.Runner: runner.fps was replaced by runner.delta, see docs."))},n.stop=function(l){n._cancelNextFrame(l)},n._onNextFrame=function(l,h){if(typeof window<"u"&&window.requestAnimationFrame)l.frameRequestId=window.requestAnimationFrame(h);else throw new Error("Matter.Runner: missing required global window.requestAnimationFrame.");return l.frameRequestId},n._cancelNextFrame=function(l){if(typeof window<"u"&&window.cancelAnimationFrame)window.cancelAnimationFrame(l.frameRequestId);else throw new Error("Matter.Runner: missing required global window.cancelAnimationFrame.")};var a=function(l){for(var h=0,f=l.length,c=0;c<f;c+=1)h+=l[c];return h/f||0}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(8),s=t(0),o=s.deprecated;(function(){n.collides=function(a,l){return i.collides(a,l)},o(n,"collides","SAT.collides \u27A4 replaced by Collision.collides")})()}),(function(r,e,t){var n={};r.exports=n;var i=t(1),s=t(0);(function(){n.pathToVertices=function(o,a){typeof window<"u"&&!("SVGPathSeg"in window)&&s.warn("Svg.pathToVertices: SVGPathSeg not defined, a polyfill is required.");var l,h,f,c,u,d,p,v,g,m,_=[],x,y,S=0,M=0,E=0;a=a||15;var A=function(w,T,F){var D=F%2===1&&F>1;if(!g||w!=g.x||T!=g.y){g&&D?(x=g.x,y=g.y):(x=0,y=0);var C={x:x+w,y:y+T};(D||!g)&&(g=C),_.push(C),M=x+w,E=y+T}},b=function(w){var T=w.pathSegTypeAsLetter.toUpperCase();if(T!=="Z"){switch(T){case"M":case"L":case"T":case"C":case"S":case"Q":M=w.x,E=w.y;break;case"H":M=w.x;break;case"V":E=w.y;break}A(M,E,w.pathSegType)}};for(n._svgPathToAbsolute(o),f=o.getTotalLength(),d=[],l=0;l<o.pathSegList.numberOfItems;l+=1)d.push(o.pathSegList.getItem(l));for(p=d.concat();S<f;){if(m=o.getPathSegAtLength(S),u=d[m],u!=v){for(;p.length&&p[0]!=u;)b(p.shift());v=u}switch(u.pathSegTypeAsLetter.toUpperCase()){case"C":case"T":case"S":case"Q":case"A":c=o.getPointAtLength(S),A(c.x,c.y,0);break}S+=a}for(l=0,h=p.length;l<h;++l)b(p[l]);return _},n._svgPathToAbsolute=function(o){for(var a,l,h,f,c,u,d=o.pathSegList,p=0,v=0,g=d.numberOfItems,m=0;m<g;++m){var _=d.getItem(m),x=_.pathSegTypeAsLetter;if(/[MLHVCSQTA]/.test(x))"x"in _&&(p=_.x),"y"in _&&(v=_.y);else switch("x1"in _&&(h=p+_.x1),"x2"in _&&(c=p+_.x2),"y1"in _&&(f=v+_.y1),"y2"in _&&(u=v+_.y2),"x"in _&&(p+=_.x),"y"in _&&(v+=_.y),x){case"m":d.replaceItem(o.createSVGPathSegMovetoAbs(p,v),m);break;case"l":d.replaceItem(o.createSVGPathSegLinetoAbs(p,v),m);break;case"h":d.replaceItem(o.createSVGPathSegLinetoHorizontalAbs(p),m);break;case"v":d.replaceItem(o.createSVGPathSegLinetoVerticalAbs(v),m);break;case"c":d.replaceItem(o.createSVGPathSegCurvetoCubicAbs(p,v,h,f,c,u),m);break;case"s":d.replaceItem(o.createSVGPathSegCurvetoCubicSmoothAbs(p,v,c,u),m);break;case"q":d.replaceItem(o.createSVGPathSegCurvetoQuadraticAbs(p,v,h,f),m);break;case"t":d.replaceItem(o.createSVGPathSegCurvetoQuadraticSmoothAbs(p,v),m);break;case"a":d.replaceItem(o.createSVGPathSegArcAbs(p,v,_.r1,_.r2,_.angle,_.largeArcFlag,_.sweepFlag),m);break;case"z":case"Z":p=a,v=l;break}(x=="M"||x=="m")&&(a=p,l=v)}}})()}),(function(r,e,t){var n={};r.exports=n;var i=t(6),s=t(0);(function(){n.create=i.create,n.add=i.add,n.remove=i.remove,n.clear=i.clear,n.addComposite=i.addComposite,n.addBody=i.addBody,n.addConstraint=i.addConstraint})()})])})});var Lu=0,kc=1,Du=2;var Vc=1,ba=2,li=3,Si=0,on=1,bn=2,Ai=0,ps=1,Hc=2,Gc=3,Wc=4,Fu=5,Xi=100,Bu=101,Uu=102,Ou=103,zu=104,ku=200,Vu=201,Hu=202,Gu=203,Qo=204,ea=205,Wu=206,qu=207,Xu=208,$u=209,Yu=210,Zu=211,Ku=212,Ju=213,ju=214,wa=0,Ea=1,Aa=2,ms=3,Ta=4,Ca=5,Ra=6,Pa=7,qc=0,Qu=1,ef=2,Ti=0,tf=1,nf=2,sf=3,Ia=4,rf=5,of=6,af=7;var Xc=300,Ms=301,Ss=302,Na=303,La=304,no=306,Ys=1e3,qi=1001,ta=1002,Fn=1003,lf=1004;var io=1005;var Yn=1006,Da=1007;var ji=1008;var Jn=1009,$c=1010,Yc=1011,or=1012,Fa=1013,Qi=1014,ci=1015,ar=1016,Ba=1017,Ua=1018,lr=1020,Zc=35902,Kc=35899,Jc=1021,jc=1022,Bn=1023,Zs=1026,cr=1027,Qc=1028,Oa=1029,eh=1030,za=1031;var ka=1033,so=33776,ro=33777,oo=33778,ao=33779,Va=35840,Ha=35841,Ga=35842,Wa=35843,qa=36196,Xa=37492,$a=37496,Ya=37808,Za=37809,Ka=37810,Ja=37811,ja=37812,Qa=37813,el=37814,tl=37815,nl=37816,il=37817,sl=37818,rl=37819,ol=37820,al=37821,ll=36492,cl=36494,hl=36495,ul=36283,fl=36284,dl=36285,pl=36286;var Nr=2300,na=2301,jo=2302,Ic=2400,Nc=2401,Lc=2402;var cf=3200,hf=3201;var th=0,uf=1,Ci="",jt="srgb",gs="srgb-linear",Lr="linear",dt="srgb";var ds=7680;var Dc=519,ff=512,df=513,pf=514,nh=515,mf=516,gf=517,vf=518,xf=519,Fc=35044;var ih="300 es",Xn=2e3,Dr=2001;var bi=class{addEventListener(e,t){this._listeners===void 0&&(this._listeners={});let n=this._listeners;n[e]===void 0&&(n[e]=[]),n[e].indexOf(t)===-1&&n[e].push(t)}hasEventListener(e,t){let n=this._listeners;return n===void 0?!1:n[e]!==void 0&&n[e].indexOf(t)!==-1}removeEventListener(e,t){let n=this._listeners;if(n===void 0)return;let i=n[e];if(i!==void 0){let s=i.indexOf(t);s!==-1&&i.splice(s,1)}}dispatchEvent(e){let t=this._listeners;if(t===void 0)return;let n=t[e.type];if(n!==void 0){e.target=this;let i=n.slice(0);for(let s=0,o=i.length;s<o;s++)i[s].call(this,e);e.target=null}}},Kt=["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f","10","11","12","13","14","15","16","17","18","19","1a","1b","1c","1d","1e","1f","20","21","22","23","24","25","26","27","28","29","2a","2b","2c","2d","2e","2f","30","31","32","33","34","35","36","37","38","39","3a","3b","3c","3d","3e","3f","40","41","42","43","44","45","46","47","48","49","4a","4b","4c","4d","4e","4f","50","51","52","53","54","55","56","57","58","59","5a","5b","5c","5d","5e","5f","60","61","62","63","64","65","66","67","68","69","6a","6b","6c","6d","6e","6f","70","71","72","73","74","75","76","77","78","79","7a","7b","7c","7d","7e","7f","80","81","82","83","84","85","86","87","88","89","8a","8b","8c","8d","8e","8f","90","91","92","93","94","95","96","97","98","99","9a","9b","9c","9d","9e","9f","a0","a1","a2","a3","a4","a5","a6","a7","a8","a9","aa","ab","ac","ad","ae","af","b0","b1","b2","b3","b4","b5","b6","b7","b8","b9","ba","bb","bc","bd","be","bf","c0","c1","c2","c3","c4","c5","c6","c7","c8","c9","ca","cb","cc","cd","ce","cf","d0","d1","d2","d3","d4","d5","d6","d7","d8","d9","da","db","dc","dd","de","df","e0","e1","e2","e3","e4","e5","e6","e7","e8","e9","ea","eb","ec","ed","ee","ef","f0","f1","f2","f3","f4","f5","f6","f7","f8","f9","fa","fb","fc","fd","fe","ff"];var oc=Math.PI/180,ia=180/Math.PI;function lo(){let r=Math.random()*4294967295|0,e=Math.random()*4294967295|0,t=Math.random()*4294967295|0,n=Math.random()*4294967295|0;return(Kt[r&255]+Kt[r>>8&255]+Kt[r>>16&255]+Kt[r>>24&255]+"-"+Kt[e&255]+Kt[e>>8&255]+"-"+Kt[e>>16&15|64]+Kt[e>>24&255]+"-"+Kt[t&63|128]+Kt[t>>8&255]+"-"+Kt[t>>16&255]+Kt[t>>24&255]+Kt[n&255]+Kt[n>>8&255]+Kt[n>>16&255]+Kt[n>>24&255]).toLowerCase()}function at(r,e,t){return Math.max(e,Math.min(t,r))}function ip(r,e){return(r%e+e)%e}function ac(r,e,t){return(1-t)*r+t*e}function Ar(r,e){switch(e.constructor){case Float32Array:return r;case Uint32Array:return r/4294967295;case Uint16Array:return r/65535;case Uint8Array:return r/255;case Int32Array:return Math.max(r/2147483647,-1);case Int16Array:return Math.max(r/32767,-1);case Int8Array:return Math.max(r/127,-1);default:throw new Error("Invalid component type.")}}function hn(r,e){switch(e.constructor){case Float32Array:return r;case Uint32Array:return Math.round(r*4294967295);case Uint16Array:return Math.round(r*65535);case Uint8Array:return Math.round(r*255);case Int32Array:return Math.round(r*2147483647);case Int16Array:return Math.round(r*32767);case Int8Array:return Math.round(r*127);default:throw new Error("Invalid component type.")}}var et=class r{constructor(e=0,t=0){r.prototype.isVector2=!0,this.x=e,this.y=t}get width(){return this.x}set width(e){this.x=e}get height(){return this.y}set height(e){this.y=e}set(e,t){return this.x=e,this.y=t,this}setScalar(e){return this.x=e,this.y=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y)}copy(e){return this.x=e.x,this.y=e.y,this}add(e){return this.x+=e.x,this.y+=e.y,this}addScalar(e){return this.x+=e,this.y+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this}subScalar(e){return this.x-=e,this.y-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this}multiply(e){return this.x*=e.x,this.y*=e.y,this}multiplyScalar(e){return this.x*=e,this.y*=e,this}divide(e){return this.x/=e.x,this.y/=e.y,this}divideScalar(e){return this.multiplyScalar(1/e)}applyMatrix3(e){let t=this.x,n=this.y,i=e.elements;return this.x=i[0]*t+i[3]*n+i[6],this.y=i[1]*t+i[4]*n+i[7],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this}clamp(e,t){return this.x=at(this.x,e.x,t.x),this.y=at(this.y,e.y,t.y),this}clampScalar(e,t){return this.x=at(this.x,e,t),this.y=at(this.y,e,t),this}clampLength(e,t){let n=this.length();return this.divideScalar(n||1).multiplyScalar(at(n,e,t))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this}negate(){return this.x=-this.x,this.y=-this.y,this}dot(e){return this.x*e.x+this.y*e.y}cross(e){return this.x*e.y-this.y*e.x}lengthSq(){return this.x*this.x+this.y*this.y}length(){return Math.sqrt(this.x*this.x+this.y*this.y)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)}normalize(){return this.divideScalar(this.length()||1)}angle(){return Math.atan2(-this.y,-this.x)+Math.PI}angleTo(e){let t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;let n=this.dot(e)/t;return Math.acos(at(n,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){let t=this.x-e.x,n=this.y-e.y;return t*t+n*n}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this}lerpVectors(e,t,n){return this.x=e.x+(t.x-e.x)*n,this.y=e.y+(t.y-e.y)*n,this}equals(e){return e.x===this.x&&e.y===this.y}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this}rotateAround(e,t){let n=Math.cos(t),i=Math.sin(t),s=this.x-e.x,o=this.y-e.y;return this.x=s*n-o*i+e.x,this.y=s*i+o*n+e.y,this}random(){return this.x=Math.random(),this.y=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y}},wi=class{constructor(e=0,t=0,n=0,i=1){this.isQuaternion=!0,this._x=e,this._y=t,this._z=n,this._w=i}static slerpFlat(e,t,n,i,s,o,a){let l=n[i+0],h=n[i+1],f=n[i+2],c=n[i+3],u=s[o+0],d=s[o+1],p=s[o+2],v=s[o+3];if(a===0){e[t+0]=l,e[t+1]=h,e[t+2]=f,e[t+3]=c;return}if(a===1){e[t+0]=u,e[t+1]=d,e[t+2]=p,e[t+3]=v;return}if(c!==v||l!==u||h!==d||f!==p){let g=1-a,m=l*u+h*d+f*p+c*v,_=m>=0?1:-1,x=1-m*m;if(x>Number.EPSILON){let S=Math.sqrt(x),M=Math.atan2(S,m*_);g=Math.sin(g*M)/S,a=Math.sin(a*M)/S}let y=a*_;if(l=l*g+u*y,h=h*g+d*y,f=f*g+p*y,c=c*g+v*y,g===1-a){let S=1/Math.sqrt(l*l+h*h+f*f+c*c);l*=S,h*=S,f*=S,c*=S}}e[t]=l,e[t+1]=h,e[t+2]=f,e[t+3]=c}static multiplyQuaternionsFlat(e,t,n,i,s,o){let a=n[i],l=n[i+1],h=n[i+2],f=n[i+3],c=s[o],u=s[o+1],d=s[o+2],p=s[o+3];return e[t]=a*p+f*c+l*d-h*u,e[t+1]=l*p+f*u+h*c-a*d,e[t+2]=h*p+f*d+a*u-l*c,e[t+3]=f*p-a*c-l*u-h*d,e}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get w(){return this._w}set w(e){this._w=e,this._onChangeCallback()}set(e,t,n,i){return this._x=e,this._y=t,this._z=n,this._w=i,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._w)}copy(e){return this._x=e.x,this._y=e.y,this._z=e.z,this._w=e.w,this._onChangeCallback(),this}setFromEuler(e,t=!0){let n=e._x,i=e._y,s=e._z,o=e._order,a=Math.cos,l=Math.sin,h=a(n/2),f=a(i/2),c=a(s/2),u=l(n/2),d=l(i/2),p=l(s/2);switch(o){case"XYZ":this._x=u*f*c+h*d*p,this._y=h*d*c-u*f*p,this._z=h*f*p+u*d*c,this._w=h*f*c-u*d*p;break;case"YXZ":this._x=u*f*c+h*d*p,this._y=h*d*c-u*f*p,this._z=h*f*p-u*d*c,this._w=h*f*c+u*d*p;break;case"ZXY":this._x=u*f*c-h*d*p,this._y=h*d*c+u*f*p,this._z=h*f*p+u*d*c,this._w=h*f*c-u*d*p;break;case"ZYX":this._x=u*f*c-h*d*p,this._y=h*d*c+u*f*p,this._z=h*f*p-u*d*c,this._w=h*f*c+u*d*p;break;case"YZX":this._x=u*f*c+h*d*p,this._y=h*d*c+u*f*p,this._z=h*f*p-u*d*c,this._w=h*f*c-u*d*p;break;case"XZY":this._x=u*f*c-h*d*p,this._y=h*d*c-u*f*p,this._z=h*f*p+u*d*c,this._w=h*f*c+u*d*p;break;default:console.warn("THREE.Quaternion: .setFromEuler() encountered an unknown order: "+o)}return t===!0&&this._onChangeCallback(),this}setFromAxisAngle(e,t){let n=t/2,i=Math.sin(n);return this._x=e.x*i,this._y=e.y*i,this._z=e.z*i,this._w=Math.cos(n),this._onChangeCallback(),this}setFromRotationMatrix(e){let t=e.elements,n=t[0],i=t[4],s=t[8],o=t[1],a=t[5],l=t[9],h=t[2],f=t[6],c=t[10],u=n+a+c;if(u>0){let d=.5/Math.sqrt(u+1);this._w=.25/d,this._x=(f-l)*d,this._y=(s-h)*d,this._z=(o-i)*d}else if(n>a&&n>c){let d=2*Math.sqrt(1+n-a-c);this._w=(f-l)/d,this._x=.25*d,this._y=(i+o)/d,this._z=(s+h)/d}else if(a>c){let d=2*Math.sqrt(1+a-n-c);this._w=(s-h)/d,this._x=(i+o)/d,this._y=.25*d,this._z=(l+f)/d}else{let d=2*Math.sqrt(1+c-n-a);this._w=(o-i)/d,this._x=(s+h)/d,this._y=(l+f)/d,this._z=.25*d}return this._onChangeCallback(),this}setFromUnitVectors(e,t){let n=e.dot(t)+1;return n<1e-8?(n=0,Math.abs(e.x)>Math.abs(e.z)?(this._x=-e.y,this._y=e.x,this._z=0,this._w=n):(this._x=0,this._y=-e.z,this._z=e.y,this._w=n)):(this._x=e.y*t.z-e.z*t.y,this._y=e.z*t.x-e.x*t.z,this._z=e.x*t.y-e.y*t.x,this._w=n),this.normalize()}angleTo(e){return 2*Math.acos(Math.abs(at(this.dot(e),-1,1)))}rotateTowards(e,t){let n=this.angleTo(e);if(n===0)return this;let i=Math.min(1,t/n);return this.slerp(e,i),this}identity(){return this.set(0,0,0,1)}invert(){return this.conjugate()}conjugate(){return this._x*=-1,this._y*=-1,this._z*=-1,this._onChangeCallback(),this}dot(e){return this._x*e._x+this._y*e._y+this._z*e._z+this._w*e._w}lengthSq(){return this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w}length(){return Math.sqrt(this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w)}normalize(){let e=this.length();return e===0?(this._x=0,this._y=0,this._z=0,this._w=1):(e=1/e,this._x=this._x*e,this._y=this._y*e,this._z=this._z*e,this._w=this._w*e),this._onChangeCallback(),this}multiply(e){return this.multiplyQuaternions(this,e)}premultiply(e){return this.multiplyQuaternions(e,this)}multiplyQuaternions(e,t){let n=e._x,i=e._y,s=e._z,o=e._w,a=t._x,l=t._y,h=t._z,f=t._w;return this._x=n*f+o*a+i*h-s*l,this._y=i*f+o*l+s*a-n*h,this._z=s*f+o*h+n*l-i*a,this._w=o*f-n*a-i*l-s*h,this._onChangeCallback(),this}slerp(e,t){if(t===0)return this;if(t===1)return this.copy(e);let n=this._x,i=this._y,s=this._z,o=this._w,a=o*e._w+n*e._x+i*e._y+s*e._z;if(a<0?(this._w=-e._w,this._x=-e._x,this._y=-e._y,this._z=-e._z,a=-a):this.copy(e),a>=1)return this._w=o,this._x=n,this._y=i,this._z=s,this;let l=1-a*a;if(l<=Number.EPSILON){let d=1-t;return this._w=d*o+t*this._w,this._x=d*n+t*this._x,this._y=d*i+t*this._y,this._z=d*s+t*this._z,this.normalize(),this}let h=Math.sqrt(l),f=Math.atan2(h,a),c=Math.sin((1-t)*f)/h,u=Math.sin(t*f)/h;return this._w=o*c+this._w*u,this._x=n*c+this._x*u,this._y=i*c+this._y*u,this._z=s*c+this._z*u,this._onChangeCallback(),this}slerpQuaternions(e,t,n){return this.copy(e).slerp(t,n)}random(){let e=2*Math.PI*Math.random(),t=2*Math.PI*Math.random(),n=Math.random(),i=Math.sqrt(1-n),s=Math.sqrt(n);return this.set(i*Math.sin(e),i*Math.cos(e),s*Math.sin(t),s*Math.cos(t))}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._w===this._w}fromArray(e,t=0){return this._x=e[t],this._y=e[t+1],this._z=e[t+2],this._w=e[t+3],this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._w,e}fromBufferAttribute(e,t){return this._x=e.getX(t),this._y=e.getY(t),this._z=e.getZ(t),this._w=e.getW(t),this._onChangeCallback(),this}toJSON(){return this.toArray()}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._w}},G=class r{constructor(e=0,t=0,n=0){r.prototype.isVector3=!0,this.x=e,this.y=t,this.z=n}set(e,t,n){return n===void 0&&(n=this.z),this.x=e,this.y=t,this.z=n,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this}multiplyVectors(e,t){return this.x=e.x*t.x,this.y=e.y*t.y,this.z=e.z*t.z,this}applyEuler(e){return this.applyQuaternion(hu.setFromEuler(e))}applyAxisAngle(e,t){return this.applyQuaternion(hu.setFromAxisAngle(e,t))}applyMatrix3(e){let t=this.x,n=this.y,i=this.z,s=e.elements;return this.x=s[0]*t+s[3]*n+s[6]*i,this.y=s[1]*t+s[4]*n+s[7]*i,this.z=s[2]*t+s[5]*n+s[8]*i,this}applyNormalMatrix(e){return this.applyMatrix3(e).normalize()}applyMatrix4(e){let t=this.x,n=this.y,i=this.z,s=e.elements,o=1/(s[3]*t+s[7]*n+s[11]*i+s[15]);return this.x=(s[0]*t+s[4]*n+s[8]*i+s[12])*o,this.y=(s[1]*t+s[5]*n+s[9]*i+s[13])*o,this.z=(s[2]*t+s[6]*n+s[10]*i+s[14])*o,this}applyQuaternion(e){let t=this.x,n=this.y,i=this.z,s=e.x,o=e.y,a=e.z,l=e.w,h=2*(o*i-a*n),f=2*(a*t-s*i),c=2*(s*n-o*t);return this.x=t+l*h+o*c-a*f,this.y=n+l*f+a*h-s*c,this.z=i+l*c+s*f-o*h,this}project(e){return this.applyMatrix4(e.matrixWorldInverse).applyMatrix4(e.projectionMatrix)}unproject(e){return this.applyMatrix4(e.projectionMatrixInverse).applyMatrix4(e.matrixWorld)}transformDirection(e){let t=this.x,n=this.y,i=this.z,s=e.elements;return this.x=s[0]*t+s[4]*n+s[8]*i,this.y=s[1]*t+s[5]*n+s[9]*i,this.z=s[2]*t+s[6]*n+s[10]*i,this.normalize()}divide(e){return this.x/=e.x,this.y/=e.y,this.z/=e.z,this}divideScalar(e){return this.multiplyScalar(1/e)}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this}clamp(e,t){return this.x=at(this.x,e.x,t.x),this.y=at(this.y,e.y,t.y),this.z=at(this.z,e.z,t.z),this}clampScalar(e,t){return this.x=at(this.x,e,t),this.y=at(this.y,e,t),this.z=at(this.z,e,t),this}clampLength(e,t){let n=this.length();return this.divideScalar(n||1).multiplyScalar(at(n,e,t))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this}lerpVectors(e,t,n){return this.x=e.x+(t.x-e.x)*n,this.y=e.y+(t.y-e.y)*n,this.z=e.z+(t.z-e.z)*n,this}cross(e){return this.crossVectors(this,e)}crossVectors(e,t){let n=e.x,i=e.y,s=e.z,o=t.x,a=t.y,l=t.z;return this.x=i*l-s*a,this.y=s*o-n*l,this.z=n*a-i*o,this}projectOnVector(e){let t=e.lengthSq();if(t===0)return this.set(0,0,0);let n=e.dot(this)/t;return this.copy(e).multiplyScalar(n)}projectOnPlane(e){return lc.copy(this).projectOnVector(e),this.sub(lc)}reflect(e){return this.sub(lc.copy(e).multiplyScalar(2*this.dot(e)))}angleTo(e){let t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;let n=this.dot(e)/t;return Math.acos(at(n,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){let t=this.x-e.x,n=this.y-e.y,i=this.z-e.z;return t*t+n*n+i*i}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)+Math.abs(this.z-e.z)}setFromSpherical(e){return this.setFromSphericalCoords(e.radius,e.phi,e.theta)}setFromSphericalCoords(e,t,n){let i=Math.sin(t)*e;return this.x=i*Math.sin(n),this.y=Math.cos(t)*e,this.z=i*Math.cos(n),this}setFromCylindrical(e){return this.setFromCylindricalCoords(e.radius,e.theta,e.y)}setFromCylindricalCoords(e,t,n){return this.x=e*Math.sin(t),this.y=n,this.z=e*Math.cos(t),this}setFromMatrixPosition(e){let t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this}setFromMatrixScale(e){let t=this.setFromMatrixColumn(e,0).length(),n=this.setFromMatrixColumn(e,1).length(),i=this.setFromMatrixColumn(e,2).length();return this.x=t,this.y=n,this.z=i,this}setFromMatrixColumn(e,t){return this.fromArray(e.elements,t*4)}setFromMatrix3Column(e,t){return this.fromArray(e.elements,t*3)}setFromEuler(e){return this.x=e._x,this.y=e._y,this.z=e._z,this}setFromColor(e){return this.x=e.r,this.y=e.g,this.z=e.b,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this}randomDirection(){let e=Math.random()*Math.PI*2,t=Math.random()*2-1,n=Math.sqrt(1-t*t);return this.x=n*Math.cos(e),this.y=t,this.z=n*Math.sin(e),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z}},lc=new G,hu=new wi,tt=class r{constructor(e,t,n,i,s,o,a,l,h){r.prototype.isMatrix3=!0,this.elements=[1,0,0,0,1,0,0,0,1],e!==void 0&&this.set(e,t,n,i,s,o,a,l,h)}set(e,t,n,i,s,o,a,l,h){let f=this.elements;return f[0]=e,f[1]=i,f[2]=a,f[3]=t,f[4]=s,f[5]=l,f[6]=n,f[7]=o,f[8]=h,this}identity(){return this.set(1,0,0,0,1,0,0,0,1),this}copy(e){let t=this.elements,n=e.elements;return t[0]=n[0],t[1]=n[1],t[2]=n[2],t[3]=n[3],t[4]=n[4],t[5]=n[5],t[6]=n[6],t[7]=n[7],t[8]=n[8],this}extractBasis(e,t,n){return e.setFromMatrix3Column(this,0),t.setFromMatrix3Column(this,1),n.setFromMatrix3Column(this,2),this}setFromMatrix4(e){let t=e.elements;return this.set(t[0],t[4],t[8],t[1],t[5],t[9],t[2],t[6],t[10]),this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){let n=e.elements,i=t.elements,s=this.elements,o=n[0],a=n[3],l=n[6],h=n[1],f=n[4],c=n[7],u=n[2],d=n[5],p=n[8],v=i[0],g=i[3],m=i[6],_=i[1],x=i[4],y=i[7],S=i[2],M=i[5],E=i[8];return s[0]=o*v+a*_+l*S,s[3]=o*g+a*x+l*M,s[6]=o*m+a*y+l*E,s[1]=h*v+f*_+c*S,s[4]=h*g+f*x+c*M,s[7]=h*m+f*y+c*E,s[2]=u*v+d*_+p*S,s[5]=u*g+d*x+p*M,s[8]=u*m+d*y+p*E,this}multiplyScalar(e){let t=this.elements;return t[0]*=e,t[3]*=e,t[6]*=e,t[1]*=e,t[4]*=e,t[7]*=e,t[2]*=e,t[5]*=e,t[8]*=e,this}determinant(){let e=this.elements,t=e[0],n=e[1],i=e[2],s=e[3],o=e[4],a=e[5],l=e[6],h=e[7],f=e[8];return t*o*f-t*a*h-n*s*f+n*a*l+i*s*h-i*o*l}invert(){let e=this.elements,t=e[0],n=e[1],i=e[2],s=e[3],o=e[4],a=e[5],l=e[6],h=e[7],f=e[8],c=f*o-a*h,u=a*l-f*s,d=h*s-o*l,p=t*c+n*u+i*d;if(p===0)return this.set(0,0,0,0,0,0,0,0,0);let v=1/p;return e[0]=c*v,e[1]=(i*h-f*n)*v,e[2]=(a*n-i*o)*v,e[3]=u*v,e[4]=(f*t-i*l)*v,e[5]=(i*s-a*t)*v,e[6]=d*v,e[7]=(n*l-h*t)*v,e[8]=(o*t-n*s)*v,this}transpose(){let e,t=this.elements;return e=t[1],t[1]=t[3],t[3]=e,e=t[2],t[2]=t[6],t[6]=e,e=t[5],t[5]=t[7],t[7]=e,this}getNormalMatrix(e){return this.setFromMatrix4(e).invert().transpose()}transposeIntoArray(e){let t=this.elements;return e[0]=t[0],e[1]=t[3],e[2]=t[6],e[3]=t[1],e[4]=t[4],e[5]=t[7],e[6]=t[2],e[7]=t[5],e[8]=t[8],this}setUvTransform(e,t,n,i,s,o,a){let l=Math.cos(s),h=Math.sin(s);return this.set(n*l,n*h,-n*(l*o+h*a)+o+e,-i*h,i*l,-i*(-h*o+l*a)+a+t,0,0,1),this}scale(e,t){return this.premultiply(cc.makeScale(e,t)),this}rotate(e){return this.premultiply(cc.makeRotation(-e)),this}translate(e,t){return this.premultiply(cc.makeTranslation(e,t)),this}makeTranslation(e,t){return e.isVector2?this.set(1,0,e.x,0,1,e.y,0,0,1):this.set(1,0,e,0,1,t,0,0,1),this}makeRotation(e){let t=Math.cos(e),n=Math.sin(e);return this.set(t,-n,0,n,t,0,0,0,1),this}makeScale(e,t){return this.set(e,0,0,0,t,0,0,0,1),this}equals(e){let t=this.elements,n=e.elements;for(let i=0;i<9;i++)if(t[i]!==n[i])return!1;return!0}fromArray(e,t=0){for(let n=0;n<9;n++)this.elements[n]=e[n+t];return this}toArray(e=[],t=0){let n=this.elements;return e[t]=n[0],e[t+1]=n[1],e[t+2]=n[2],e[t+3]=n[3],e[t+4]=n[4],e[t+5]=n[5],e[t+6]=n[6],e[t+7]=n[7],e[t+8]=n[8],e}clone(){return new this.constructor().fromArray(this.elements)}},cc=new tt;function sh(r){for(let e=r.length-1;e>=0;--e)if(r[e]>=65535)return!0;return!1}function Fr(r){return document.createElementNS("http://www.w3.org/1999/xhtml",r)}function yf(){let r=Fr("canvas");return r.style.display="block",r}var uu={};function Ks(r){r in uu||(uu[r]=!0,console.warn(r))}function _f(r,e,t){return new Promise(function(n,i){function s(){switch(r.clientWaitSync(e,r.SYNC_FLUSH_COMMANDS_BIT,0)){case r.WAIT_FAILED:i();break;case r.TIMEOUT_EXPIRED:setTimeout(s,t);break;default:n()}}setTimeout(s,t)})}var fu=new tt().set(.4123908,.3575843,.1804808,.212639,.7151687,.0721923,.0193308,.1191948,.9505322),du=new tt().set(3.2409699,-1.5373832,-.4986108,-.9692436,1.8759675,.0415551,.0556301,-.203977,1.0569715);function sp(){let r={enabled:!0,workingColorSpace:gs,spaces:{},convert:function(i,s,o){return this.enabled===!1||s===o||!s||!o||(this.spaces[s].transfer===dt&&(i.r=Mi(i.r),i.g=Mi(i.g),i.b=Mi(i.b)),this.spaces[s].primaries!==this.spaces[o].primaries&&(i.applyMatrix3(this.spaces[s].toXYZ),i.applyMatrix3(this.spaces[o].fromXYZ)),this.spaces[o].transfer===dt&&(i.r=$s(i.r),i.g=$s(i.g),i.b=$s(i.b))),i},workingToColorSpace:function(i,s){return this.convert(i,this.workingColorSpace,s)},colorSpaceToWorking:function(i,s){return this.convert(i,s,this.workingColorSpace)},getPrimaries:function(i){return this.spaces[i].primaries},getTransfer:function(i){return i===Ci?Lr:this.spaces[i].transfer},getToneMappingMode:function(i){return this.spaces[i].outputColorSpaceConfig.toneMappingMode||"standard"},getLuminanceCoefficients:function(i,s=this.workingColorSpace){return i.fromArray(this.spaces[s].luminanceCoefficients)},define:function(i){Object.assign(this.spaces,i)},_getMatrix:function(i,s,o){return i.copy(this.spaces[s].toXYZ).multiply(this.spaces[o].fromXYZ)},_getDrawingBufferColorSpace:function(i){return this.spaces[i].outputColorSpaceConfig.drawingBufferColorSpace},_getUnpackColorSpace:function(i=this.workingColorSpace){return this.spaces[i].workingColorSpaceConfig.unpackColorSpace},fromWorkingColorSpace:function(i,s){return Ks("THREE.ColorManagement: .fromWorkingColorSpace() has been renamed to .workingToColorSpace()."),r.workingToColorSpace(i,s)},toWorkingColorSpace:function(i,s){return Ks("THREE.ColorManagement: .toWorkingColorSpace() has been renamed to .colorSpaceToWorking()."),r.colorSpaceToWorking(i,s)}},e=[.64,.33,.3,.6,.15,.06],t=[.2126,.7152,.0722],n=[.3127,.329];return r.define({[gs]:{primaries:e,whitePoint:n,transfer:Lr,toXYZ:fu,fromXYZ:du,luminanceCoefficients:t,workingColorSpaceConfig:{unpackColorSpace:jt},outputColorSpaceConfig:{drawingBufferColorSpace:jt}},[jt]:{primaries:e,whitePoint:n,transfer:dt,toXYZ:fu,fromXYZ:du,luminanceCoefficients:t,outputColorSpaceConfig:{drawingBufferColorSpace:jt}}}),r}var lt=sp();function Mi(r){return r<.04045?r*.0773993808:Math.pow(r*.9478672986+.0521327014,2.4)}function $s(r){return r<.0031308?r*12.92:1.055*Math.pow(r,.41666)-.055}var Fs,sa=class{static getDataURL(e,t="image/png"){if(/^data:/i.test(e.src)||typeof HTMLCanvasElement>"u")return e.src;let n;if(e instanceof HTMLCanvasElement)n=e;else{Fs===void 0&&(Fs=Fr("canvas")),Fs.width=e.width,Fs.height=e.height;let i=Fs.getContext("2d");e instanceof ImageData?i.putImageData(e,0,0):i.drawImage(e,0,0,e.width,e.height),n=Fs}return n.toDataURL(t)}static sRGBToLinear(e){if(typeof HTMLImageElement<"u"&&e instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&e instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&e instanceof ImageBitmap){let t=Fr("canvas");t.width=e.width,t.height=e.height;let n=t.getContext("2d");n.drawImage(e,0,0,e.width,e.height);let i=n.getImageData(0,0,e.width,e.height),s=i.data;for(let o=0;o<s.length;o++)s[o]=Mi(s[o]/255)*255;return n.putImageData(i,0,0),t}else if(e.data){let t=e.data.slice(0);for(let n=0;n<t.length;n++)t instanceof Uint8Array||t instanceof Uint8ClampedArray?t[n]=Math.floor(Mi(t[n]/255)*255):t[n]=Mi(t[n]);return{data:t,width:e.width,height:e.height}}else return console.warn("THREE.ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied."),e}},rp=0,Js=class{constructor(e=null){this.isSource=!0,Object.defineProperty(this,"id",{value:rp++}),this.uuid=lo(),this.data=e,this.dataReady=!0,this.version=0}getSize(e){let t=this.data;return typeof HTMLVideoElement<"u"&&t instanceof HTMLVideoElement?e.set(t.videoWidth,t.videoHeight,0):t instanceof VideoFrame?e.set(t.displayHeight,t.displayWidth,0):t!==null?e.set(t.width,t.height,t.depth||0):e.set(0,0,0),e}set needsUpdate(e){e===!0&&this.version++}toJSON(e){let t=e===void 0||typeof e=="string";if(!t&&e.images[this.uuid]!==void 0)return e.images[this.uuid];let n={uuid:this.uuid,url:""},i=this.data;if(i!==null){let s;if(Array.isArray(i)){s=[];for(let o=0,a=i.length;o<a;o++)i[o].isDataTexture?s.push(hc(i[o].image)):s.push(hc(i[o]))}else s=hc(i);n.url=s}return t||(e.images[this.uuid]=n),n}};function hc(r){return typeof HTMLImageElement<"u"&&r instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&r instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&r instanceof ImageBitmap?sa.getDataURL(r):r.data?{data:Array.from(r.data),width:r.width,height:r.height,type:r.data.constructor.name}:(console.warn("THREE.Texture: Unable to serialize Texture."),{})}var op=0,uc=new G,un=class r extends bi{constructor(e=r.DEFAULT_IMAGE,t=r.DEFAULT_MAPPING,n=qi,i=qi,s=Yn,o=ji,a=Bn,l=Jn,h=r.DEFAULT_ANISOTROPY,f=Ci){super(),this.isTexture=!0,Object.defineProperty(this,"id",{value:op++}),this.uuid=lo(),this.name="",this.source=new Js(e),this.mipmaps=[],this.mapping=t,this.channel=0,this.wrapS=n,this.wrapT=i,this.magFilter=s,this.minFilter=o,this.anisotropy=h,this.format=a,this.internalFormat=null,this.type=l,this.offset=new et(0,0),this.repeat=new et(1,1),this.center=new et(0,0),this.rotation=0,this.matrixAutoUpdate=!0,this.matrix=new tt,this.generateMipmaps=!0,this.premultiplyAlpha=!1,this.flipY=!0,this.unpackAlignment=4,this.colorSpace=f,this.userData={},this.updateRanges=[],this.version=0,this.onUpdate=null,this.renderTarget=null,this.isRenderTargetTexture=!1,this.isArrayTexture=!!(e&&e.depth&&e.depth>1),this.pmremVersion=0}get width(){return this.source.getSize(uc).x}get height(){return this.source.getSize(uc).y}get depth(){return this.source.getSize(uc).z}get image(){return this.source.data}set image(e=null){this.source.data=e}updateMatrix(){this.matrix.setUvTransform(this.offset.x,this.offset.y,this.repeat.x,this.repeat.y,this.rotation,this.center.x,this.center.y)}addUpdateRange(e,t){this.updateRanges.push({start:e,count:t})}clearUpdateRanges(){this.updateRanges.length=0}clone(){return new this.constructor().copy(this)}copy(e){return this.name=e.name,this.source=e.source,this.mipmaps=e.mipmaps.slice(0),this.mapping=e.mapping,this.channel=e.channel,this.wrapS=e.wrapS,this.wrapT=e.wrapT,this.magFilter=e.magFilter,this.minFilter=e.minFilter,this.anisotropy=e.anisotropy,this.format=e.format,this.internalFormat=e.internalFormat,this.type=e.type,this.offset.copy(e.offset),this.repeat.copy(e.repeat),this.center.copy(e.center),this.rotation=e.rotation,this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrix.copy(e.matrix),this.generateMipmaps=e.generateMipmaps,this.premultiplyAlpha=e.premultiplyAlpha,this.flipY=e.flipY,this.unpackAlignment=e.unpackAlignment,this.colorSpace=e.colorSpace,this.renderTarget=e.renderTarget,this.isRenderTargetTexture=e.isRenderTargetTexture,this.isArrayTexture=e.isArrayTexture,this.userData=JSON.parse(JSON.stringify(e.userData)),this.needsUpdate=!0,this}setValues(e){for(let t in e){let n=e[t];if(n===void 0){console.warn(`THREE.Texture.setValues(): parameter '${t}' has value of undefined.`);continue}let i=this[t];if(i===void 0){console.warn(`THREE.Texture.setValues(): property '${t}' does not exist.`);continue}i&&n&&i.isVector2&&n.isVector2||i&&n&&i.isVector3&&n.isVector3||i&&n&&i.isMatrix3&&n.isMatrix3?i.copy(n):this[t]=n}}toJSON(e){let t=e===void 0||typeof e=="string";if(!t&&e.textures[this.uuid]!==void 0)return e.textures[this.uuid];let n={metadata:{version:4.7,type:"Texture",generator:"Texture.toJSON"},uuid:this.uuid,name:this.name,image:this.source.toJSON(e).uuid,mapping:this.mapping,channel:this.channel,repeat:[this.repeat.x,this.repeat.y],offset:[this.offset.x,this.offset.y],center:[this.center.x,this.center.y],rotation:this.rotation,wrap:[this.wrapS,this.wrapT],format:this.format,internalFormat:this.internalFormat,type:this.type,colorSpace:this.colorSpace,minFilter:this.minFilter,magFilter:this.magFilter,anisotropy:this.anisotropy,flipY:this.flipY,generateMipmaps:this.generateMipmaps,premultiplyAlpha:this.premultiplyAlpha,unpackAlignment:this.unpackAlignment};return Object.keys(this.userData).length>0&&(n.userData=this.userData),t||(e.textures[this.uuid]=n),n}dispose(){this.dispatchEvent({type:"dispose"})}transformUv(e){if(this.mapping!==Xc)return e;if(e.applyMatrix3(this.matrix),e.x<0||e.x>1)switch(this.wrapS){case Ys:e.x=e.x-Math.floor(e.x);break;case qi:e.x=e.x<0?0:1;break;case ta:Math.abs(Math.floor(e.x)%2)===1?e.x=Math.ceil(e.x)-e.x:e.x=e.x-Math.floor(e.x);break}if(e.y<0||e.y>1)switch(this.wrapT){case Ys:e.y=e.y-Math.floor(e.y);break;case qi:e.y=e.y<0?0:1;break;case ta:Math.abs(Math.floor(e.y)%2)===1?e.y=Math.ceil(e.y)-e.y:e.y=e.y-Math.floor(e.y);break}return this.flipY&&(e.y=1-e.y),e}set needsUpdate(e){e===!0&&(this.version++,this.source.needsUpdate=!0)}set needsPMREMUpdate(e){e===!0&&this.pmremVersion++}};un.DEFAULT_IMAGE=null;un.DEFAULT_MAPPING=Xc;un.DEFAULT_ANISOTROPY=1;var St=class r{constructor(e=0,t=0,n=0,i=1){r.prototype.isVector4=!0,this.x=e,this.y=t,this.z=n,this.w=i}get width(){return this.z}set width(e){this.z=e}get height(){return this.w}set height(e){this.w=e}set(e,t,n,i){return this.x=e,this.y=t,this.z=n,this.w=i,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this.w=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setW(e){return this.w=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;case 3:this.w=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;case 3:return this.w;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z,this.w)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this.w=e.w!==void 0?e.w:1,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this.w+=e.w,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this.w+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this.w=e.w+t.w,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this.w+=e.w*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this.w-=e.w,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this.w-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this.w=e.w-t.w,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this.w*=e.w,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this.w*=e,this}applyMatrix4(e){let t=this.x,n=this.y,i=this.z,s=this.w,o=e.elements;return this.x=o[0]*t+o[4]*n+o[8]*i+o[12]*s,this.y=o[1]*t+o[5]*n+o[9]*i+o[13]*s,this.z=o[2]*t+o[6]*n+o[10]*i+o[14]*s,this.w=o[3]*t+o[7]*n+o[11]*i+o[15]*s,this}divide(e){return this.x/=e.x,this.y/=e.y,this.z/=e.z,this.w/=e.w,this}divideScalar(e){return this.multiplyScalar(1/e)}setAxisAngleFromQuaternion(e){this.w=2*Math.acos(e.w);let t=Math.sqrt(1-e.w*e.w);return t<1e-4?(this.x=1,this.y=0,this.z=0):(this.x=e.x/t,this.y=e.y/t,this.z=e.z/t),this}setAxisAngleFromRotationMatrix(e){let t,n,i,s,l=e.elements,h=l[0],f=l[4],c=l[8],u=l[1],d=l[5],p=l[9],v=l[2],g=l[6],m=l[10];if(Math.abs(f-u)<.01&&Math.abs(c-v)<.01&&Math.abs(p-g)<.01){if(Math.abs(f+u)<.1&&Math.abs(c+v)<.1&&Math.abs(p+g)<.1&&Math.abs(h+d+m-3)<.1)return this.set(1,0,0,0),this;t=Math.PI;let x=(h+1)/2,y=(d+1)/2,S=(m+1)/2,M=(f+u)/4,E=(c+v)/4,A=(p+g)/4;return x>y&&x>S?x<.01?(n=0,i=.707106781,s=.707106781):(n=Math.sqrt(x),i=M/n,s=E/n):y>S?y<.01?(n=.707106781,i=0,s=.707106781):(i=Math.sqrt(y),n=M/i,s=A/i):S<.01?(n=.707106781,i=.707106781,s=0):(s=Math.sqrt(S),n=E/s,i=A/s),this.set(n,i,s,t),this}let _=Math.sqrt((g-p)*(g-p)+(c-v)*(c-v)+(u-f)*(u-f));return Math.abs(_)<.001&&(_=1),this.x=(g-p)/_,this.y=(c-v)/_,this.z=(u-f)/_,this.w=Math.acos((h+d+m-1)/2),this}setFromMatrixPosition(e){let t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this.w=t[15],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this.w=Math.min(this.w,e.w),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this.w=Math.max(this.w,e.w),this}clamp(e,t){return this.x=at(this.x,e.x,t.x),this.y=at(this.y,e.y,t.y),this.z=at(this.z,e.z,t.z),this.w=at(this.w,e.w,t.w),this}clampScalar(e,t){return this.x=at(this.x,e,t),this.y=at(this.y,e,t),this.z=at(this.z,e,t),this.w=at(this.w,e,t),this}clampLength(e,t){let n=this.length();return this.divideScalar(n||1).multiplyScalar(at(n,e,t))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this.w=Math.floor(this.w),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this.w=Math.ceil(this.w),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this.w=Math.round(this.w),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this.w=Math.trunc(this.w),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this.w=-this.w,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z+this.w*e.w}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)+Math.abs(this.w)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this.w+=(e.w-this.w)*t,this}lerpVectors(e,t,n){return this.x=e.x+(t.x-e.x)*n,this.y=e.y+(t.y-e.y)*n,this.z=e.z+(t.z-e.z)*n,this.w=e.w+(t.w-e.w)*n,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z&&e.w===this.w}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this.w=e[t+3],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e[t+3]=this.w,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this.w=e.getW(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this.w=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z,yield this.w}},ra=class extends bi{constructor(e=1,t=1,n={}){super(),n=Object.assign({generateMipmaps:!1,internalFormat:null,minFilter:Yn,depthBuffer:!0,stencilBuffer:!1,resolveDepthBuffer:!0,resolveStencilBuffer:!0,depthTexture:null,samples:0,count:1,depth:1,multiview:!1},n),this.isRenderTarget=!0,this.width=e,this.height=t,this.depth=n.depth,this.scissor=new St(0,0,e,t),this.scissorTest=!1,this.viewport=new St(0,0,e,t);let i={width:e,height:t,depth:n.depth},s=new un(i);this.textures=[];let o=n.count;for(let a=0;a<o;a++)this.textures[a]=s.clone(),this.textures[a].isRenderTargetTexture=!0,this.textures[a].renderTarget=this;this._setTextureOptions(n),this.depthBuffer=n.depthBuffer,this.stencilBuffer=n.stencilBuffer,this.resolveDepthBuffer=n.resolveDepthBuffer,this.resolveStencilBuffer=n.resolveStencilBuffer,this._depthTexture=null,this.depthTexture=n.depthTexture,this.samples=n.samples,this.multiview=n.multiview}_setTextureOptions(e={}){let t={minFilter:Yn,generateMipmaps:!1,flipY:!1,internalFormat:null};e.mapping!==void 0&&(t.mapping=e.mapping),e.wrapS!==void 0&&(t.wrapS=e.wrapS),e.wrapT!==void 0&&(t.wrapT=e.wrapT),e.wrapR!==void 0&&(t.wrapR=e.wrapR),e.magFilter!==void 0&&(t.magFilter=e.magFilter),e.minFilter!==void 0&&(t.minFilter=e.minFilter),e.format!==void 0&&(t.format=e.format),e.type!==void 0&&(t.type=e.type),e.anisotropy!==void 0&&(t.anisotropy=e.anisotropy),e.colorSpace!==void 0&&(t.colorSpace=e.colorSpace),e.flipY!==void 0&&(t.flipY=e.flipY),e.generateMipmaps!==void 0&&(t.generateMipmaps=e.generateMipmaps),e.internalFormat!==void 0&&(t.internalFormat=e.internalFormat);for(let n=0;n<this.textures.length;n++)this.textures[n].setValues(t)}get texture(){return this.textures[0]}set texture(e){this.textures[0]=e}set depthTexture(e){this._depthTexture!==null&&(this._depthTexture.renderTarget=null),e!==null&&(e.renderTarget=this),this._depthTexture=e}get depthTexture(){return this._depthTexture}setSize(e,t,n=1){if(this.width!==e||this.height!==t||this.depth!==n){this.width=e,this.height=t,this.depth=n;for(let i=0,s=this.textures.length;i<s;i++)this.textures[i].image.width=e,this.textures[i].image.height=t,this.textures[i].image.depth=n,this.textures[i].isArrayTexture=this.textures[i].image.depth>1;this.dispose()}this.viewport.set(0,0,e,t),this.scissor.set(0,0,e,t)}clone(){return new this.constructor().copy(this)}copy(e){this.width=e.width,this.height=e.height,this.depth=e.depth,this.scissor.copy(e.scissor),this.scissorTest=e.scissorTest,this.viewport.copy(e.viewport),this.textures.length=0;for(let t=0,n=e.textures.length;t<n;t++){this.textures[t]=e.textures[t].clone(),this.textures[t].isRenderTargetTexture=!0,this.textures[t].renderTarget=this;let i=Object.assign({},e.textures[t].image);this.textures[t].source=new Js(i)}return this.depthBuffer=e.depthBuffer,this.stencilBuffer=e.stencilBuffer,this.resolveDepthBuffer=e.resolveDepthBuffer,this.resolveStencilBuffer=e.resolveStencilBuffer,e.depthTexture!==null&&(this.depthTexture=e.depthTexture.clone()),this.samples=e.samples,this}dispose(){this.dispatchEvent({type:"dispose"})}},oi=class extends ra{constructor(e=1,t=1,n={}){super(e,t,n),this.isWebGLRenderTarget=!0}},Br=class extends un{constructor(e=null,t=1,n=1,i=1){super(null),this.isDataArrayTexture=!0,this.image={data:e,width:t,height:n,depth:i},this.magFilter=Fn,this.minFilter=Fn,this.wrapR=qi,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1,this.layerUpdates=new Set}addLayerUpdate(e){this.layerUpdates.add(e)}clearLayerUpdates(){this.layerUpdates.clear()}};var oa=class extends un{constructor(e=null,t=1,n=1,i=1){super(null),this.isData3DTexture=!0,this.image={data:e,width:t,height:n,depth:i},this.magFilter=Fn,this.minFilter=Fn,this.wrapR=qi,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}};var $i=class{constructor(e=new G(1/0,1/0,1/0),t=new G(-1/0,-1/0,-1/0)){this.isBox3=!0,this.min=e,this.max=t}set(e,t){return this.min.copy(e),this.max.copy(t),this}setFromArray(e){this.makeEmpty();for(let t=0,n=e.length;t<n;t+=3)this.expandByPoint(Gn.fromArray(e,t));return this}setFromBufferAttribute(e){this.makeEmpty();for(let t=0,n=e.count;t<n;t++)this.expandByPoint(Gn.fromBufferAttribute(e,t));return this}setFromPoints(e){this.makeEmpty();for(let t=0,n=e.length;t<n;t++)this.expandByPoint(e[t]);return this}setFromCenterAndSize(e,t){let n=Gn.copy(t).multiplyScalar(.5);return this.min.copy(e).sub(n),this.max.copy(e).add(n),this}setFromObject(e,t=!1){return this.makeEmpty(),this.expandByObject(e,t)}clone(){return new this.constructor().copy(this)}copy(e){return this.min.copy(e.min),this.max.copy(e.max),this}makeEmpty(){return this.min.x=this.min.y=this.min.z=1/0,this.max.x=this.max.y=this.max.z=-1/0,this}isEmpty(){return this.max.x<this.min.x||this.max.y<this.min.y||this.max.z<this.min.z}getCenter(e){return this.isEmpty()?e.set(0,0,0):e.addVectors(this.min,this.max).multiplyScalar(.5)}getSize(e){return this.isEmpty()?e.set(0,0,0):e.subVectors(this.max,this.min)}expandByPoint(e){return this.min.min(e),this.max.max(e),this}expandByVector(e){return this.min.sub(e),this.max.add(e),this}expandByScalar(e){return this.min.addScalar(-e),this.max.addScalar(e),this}expandByObject(e,t=!1){e.updateWorldMatrix(!1,!1);let n=e.geometry;if(n!==void 0){let s=n.getAttribute("position");if(t===!0&&s!==void 0&&e.isInstancedMesh!==!0)for(let o=0,a=s.count;o<a;o++)e.isMesh===!0?e.getVertexPosition(o,Gn):Gn.fromBufferAttribute(s,o),Gn.applyMatrix4(e.matrixWorld),this.expandByPoint(Gn);else e.boundingBox!==void 0?(e.boundingBox===null&&e.computeBoundingBox(),No.copy(e.boundingBox)):(n.boundingBox===null&&n.computeBoundingBox(),No.copy(n.boundingBox)),No.applyMatrix4(e.matrixWorld),this.union(No)}let i=e.children;for(let s=0,o=i.length;s<o;s++)this.expandByObject(i[s],t);return this}containsPoint(e){return e.x>=this.min.x&&e.x<=this.max.x&&e.y>=this.min.y&&e.y<=this.max.y&&e.z>=this.min.z&&e.z<=this.max.z}containsBox(e){return this.min.x<=e.min.x&&e.max.x<=this.max.x&&this.min.y<=e.min.y&&e.max.y<=this.max.y&&this.min.z<=e.min.z&&e.max.z<=this.max.z}getParameter(e,t){return t.set((e.x-this.min.x)/(this.max.x-this.min.x),(e.y-this.min.y)/(this.max.y-this.min.y),(e.z-this.min.z)/(this.max.z-this.min.z))}intersectsBox(e){return e.max.x>=this.min.x&&e.min.x<=this.max.x&&e.max.y>=this.min.y&&e.min.y<=this.max.y&&e.max.z>=this.min.z&&e.min.z<=this.max.z}intersectsSphere(e){return this.clampPoint(e.center,Gn),Gn.distanceToSquared(e.center)<=e.radius*e.radius}intersectsPlane(e){let t,n;return e.normal.x>0?(t=e.normal.x*this.min.x,n=e.normal.x*this.max.x):(t=e.normal.x*this.max.x,n=e.normal.x*this.min.x),e.normal.y>0?(t+=e.normal.y*this.min.y,n+=e.normal.y*this.max.y):(t+=e.normal.y*this.max.y,n+=e.normal.y*this.min.y),e.normal.z>0?(t+=e.normal.z*this.min.z,n+=e.normal.z*this.max.z):(t+=e.normal.z*this.max.z,n+=e.normal.z*this.min.z),t<=-e.constant&&n>=-e.constant}intersectsTriangle(e){if(this.isEmpty())return!1;this.getCenter(Tr),Lo.subVectors(this.max,Tr),Bs.subVectors(e.a,Tr),Us.subVectors(e.b,Tr),Os.subVectors(e.c,Tr),Oi.subVectors(Us,Bs),zi.subVectors(Os,Us),cs.subVectors(Bs,Os);let t=[0,-Oi.z,Oi.y,0,-zi.z,zi.y,0,-cs.z,cs.y,Oi.z,0,-Oi.x,zi.z,0,-zi.x,cs.z,0,-cs.x,-Oi.y,Oi.x,0,-zi.y,zi.x,0,-cs.y,cs.x,0];return!fc(t,Bs,Us,Os,Lo)||(t=[1,0,0,0,1,0,0,0,1],!fc(t,Bs,Us,Os,Lo))?!1:(Do.crossVectors(Oi,zi),t=[Do.x,Do.y,Do.z],fc(t,Bs,Us,Os,Lo))}clampPoint(e,t){return t.copy(e).clamp(this.min,this.max)}distanceToPoint(e){return this.clampPoint(e,Gn).distanceTo(e)}getBoundingSphere(e){return this.isEmpty()?e.makeEmpty():(this.getCenter(e.center),e.radius=this.getSize(Gn).length()*.5),e}intersect(e){return this.min.max(e.min),this.max.min(e.max),this.isEmpty()&&this.makeEmpty(),this}union(e){return this.min.min(e.min),this.max.max(e.max),this}applyMatrix4(e){return this.isEmpty()?this:(gi[0].set(this.min.x,this.min.y,this.min.z).applyMatrix4(e),gi[1].set(this.min.x,this.min.y,this.max.z).applyMatrix4(e),gi[2].set(this.min.x,this.max.y,this.min.z).applyMatrix4(e),gi[3].set(this.min.x,this.max.y,this.max.z).applyMatrix4(e),gi[4].set(this.max.x,this.min.y,this.min.z).applyMatrix4(e),gi[5].set(this.max.x,this.min.y,this.max.z).applyMatrix4(e),gi[6].set(this.max.x,this.max.y,this.min.z).applyMatrix4(e),gi[7].set(this.max.x,this.max.y,this.max.z).applyMatrix4(e),this.setFromPoints(gi),this)}translate(e){return this.min.add(e),this.max.add(e),this}equals(e){return e.min.equals(this.min)&&e.max.equals(this.max)}toJSON(){return{min:this.min.toArray(),max:this.max.toArray()}}fromJSON(e){return this.min.fromArray(e.min),this.max.fromArray(e.max),this}},gi=[new G,new G,new G,new G,new G,new G,new G,new G],Gn=new G,No=new $i,Bs=new G,Us=new G,Os=new G,Oi=new G,zi=new G,cs=new G,Tr=new G,Lo=new G,Do=new G,hs=new G;function fc(r,e,t,n,i){for(let s=0,o=r.length-3;s<=o;s+=3){hs.fromArray(r,s);let a=i.x*Math.abs(hs.x)+i.y*Math.abs(hs.y)+i.z*Math.abs(hs.z),l=e.dot(hs),h=t.dot(hs),f=n.dot(hs);if(Math.max(-Math.max(l,h,f),Math.min(l,h,f))>a)return!1}return!0}var ap=new $i,Cr=new G,dc=new G,vs=class{constructor(e=new G,t=-1){this.isSphere=!0,this.center=e,this.radius=t}set(e,t){return this.center.copy(e),this.radius=t,this}setFromPoints(e,t){let n=this.center;t!==void 0?n.copy(t):ap.setFromPoints(e).getCenter(n);let i=0;for(let s=0,o=e.length;s<o;s++)i=Math.max(i,n.distanceToSquared(e[s]));return this.radius=Math.sqrt(i),this}copy(e){return this.center.copy(e.center),this.radius=e.radius,this}isEmpty(){return this.radius<0}makeEmpty(){return this.center.set(0,0,0),this.radius=-1,this}containsPoint(e){return e.distanceToSquared(this.center)<=this.radius*this.radius}distanceToPoint(e){return e.distanceTo(this.center)-this.radius}intersectsSphere(e){let t=this.radius+e.radius;return e.center.distanceToSquared(this.center)<=t*t}intersectsBox(e){return e.intersectsSphere(this)}intersectsPlane(e){return Math.abs(e.distanceToPoint(this.center))<=this.radius}clampPoint(e,t){let n=this.center.distanceToSquared(e);return t.copy(e),n>this.radius*this.radius&&(t.sub(this.center).normalize(),t.multiplyScalar(this.radius).add(this.center)),t}getBoundingBox(e){return this.isEmpty()?(e.makeEmpty(),e):(e.set(this.center,this.center),e.expandByScalar(this.radius),e)}applyMatrix4(e){return this.center.applyMatrix4(e),this.radius=this.radius*e.getMaxScaleOnAxis(),this}translate(e){return this.center.add(e),this}expandByPoint(e){if(this.isEmpty())return this.center.copy(e),this.radius=0,this;Cr.subVectors(e,this.center);let t=Cr.lengthSq();if(t>this.radius*this.radius){let n=Math.sqrt(t),i=(n-this.radius)*.5;this.center.addScaledVector(Cr,i/n),this.radius+=i}return this}union(e){return e.isEmpty()?this:this.isEmpty()?(this.copy(e),this):(this.center.equals(e.center)===!0?this.radius=Math.max(this.radius,e.radius):(dc.subVectors(e.center,this.center).setLength(e.radius),this.expandByPoint(Cr.copy(e.center).add(dc)),this.expandByPoint(Cr.copy(e.center).sub(dc))),this)}equals(e){return e.center.equals(this.center)&&e.radius===this.radius}clone(){return new this.constructor().copy(this)}toJSON(){return{radius:this.radius,center:this.center.toArray()}}fromJSON(e){return this.radius=e.radius,this.center.fromArray(e.center),this}},vi=new G,pc=new G,Fo=new G,ki=new G,mc=new G,Bo=new G,gc=new G,js=class{constructor(e=new G,t=new G(0,0,-1)){this.origin=e,this.direction=t}set(e,t){return this.origin.copy(e),this.direction.copy(t),this}copy(e){return this.origin.copy(e.origin),this.direction.copy(e.direction),this}at(e,t){return t.copy(this.origin).addScaledVector(this.direction,e)}lookAt(e){return this.direction.copy(e).sub(this.origin).normalize(),this}recast(e){return this.origin.copy(this.at(e,vi)),this}closestPointToPoint(e,t){t.subVectors(e,this.origin);let n=t.dot(this.direction);return n<0?t.copy(this.origin):t.copy(this.origin).addScaledVector(this.direction,n)}distanceToPoint(e){return Math.sqrt(this.distanceSqToPoint(e))}distanceSqToPoint(e){let t=vi.subVectors(e,this.origin).dot(this.direction);return t<0?this.origin.distanceToSquared(e):(vi.copy(this.origin).addScaledVector(this.direction,t),vi.distanceToSquared(e))}distanceSqToSegment(e,t,n,i){pc.copy(e).add(t).multiplyScalar(.5),Fo.copy(t).sub(e).normalize(),ki.copy(this.origin).sub(pc);let s=e.distanceTo(t)*.5,o=-this.direction.dot(Fo),a=ki.dot(this.direction),l=-ki.dot(Fo),h=ki.lengthSq(),f=Math.abs(1-o*o),c,u,d,p;if(f>0)if(c=o*l-a,u=o*a-l,p=s*f,c>=0)if(u>=-p)if(u<=p){let v=1/f;c*=v,u*=v,d=c*(c+o*u+2*a)+u*(o*c+u+2*l)+h}else u=s,c=Math.max(0,-(o*u+a)),d=-c*c+u*(u+2*l)+h;else u=-s,c=Math.max(0,-(o*u+a)),d=-c*c+u*(u+2*l)+h;else u<=-p?(c=Math.max(0,-(-o*s+a)),u=c>0?-s:Math.min(Math.max(-s,-l),s),d=-c*c+u*(u+2*l)+h):u<=p?(c=0,u=Math.min(Math.max(-s,-l),s),d=u*(u+2*l)+h):(c=Math.max(0,-(o*s+a)),u=c>0?s:Math.min(Math.max(-s,-l),s),d=-c*c+u*(u+2*l)+h);else u=o>0?-s:s,c=Math.max(0,-(o*u+a)),d=-c*c+u*(u+2*l)+h;return n&&n.copy(this.origin).addScaledVector(this.direction,c),i&&i.copy(pc).addScaledVector(Fo,u),d}intersectSphere(e,t){vi.subVectors(e.center,this.origin);let n=vi.dot(this.direction),i=vi.dot(vi)-n*n,s=e.radius*e.radius;if(i>s)return null;let o=Math.sqrt(s-i),a=n-o,l=n+o;return l<0?null:a<0?this.at(l,t):this.at(a,t)}intersectsSphere(e){return e.radius<0?!1:this.distanceSqToPoint(e.center)<=e.radius*e.radius}distanceToPlane(e){let t=e.normal.dot(this.direction);if(t===0)return e.distanceToPoint(this.origin)===0?0:null;let n=-(this.origin.dot(e.normal)+e.constant)/t;return n>=0?n:null}intersectPlane(e,t){let n=this.distanceToPlane(e);return n===null?null:this.at(n,t)}intersectsPlane(e){let t=e.distanceToPoint(this.origin);return t===0||e.normal.dot(this.direction)*t<0}intersectBox(e,t){let n,i,s,o,a,l,h=1/this.direction.x,f=1/this.direction.y,c=1/this.direction.z,u=this.origin;return h>=0?(n=(e.min.x-u.x)*h,i=(e.max.x-u.x)*h):(n=(e.max.x-u.x)*h,i=(e.min.x-u.x)*h),f>=0?(s=(e.min.y-u.y)*f,o=(e.max.y-u.y)*f):(s=(e.max.y-u.y)*f,o=(e.min.y-u.y)*f),n>o||s>i||((s>n||isNaN(n))&&(n=s),(o<i||isNaN(i))&&(i=o),c>=0?(a=(e.min.z-u.z)*c,l=(e.max.z-u.z)*c):(a=(e.max.z-u.z)*c,l=(e.min.z-u.z)*c),n>l||a>i)||((a>n||n!==n)&&(n=a),(l<i||i!==i)&&(i=l),i<0)?null:this.at(n>=0?n:i,t)}intersectsBox(e){return this.intersectBox(e,vi)!==null}intersectTriangle(e,t,n,i,s){mc.subVectors(t,e),Bo.subVectors(n,e),gc.crossVectors(mc,Bo);let o=this.direction.dot(gc),a;if(o>0){if(i)return null;a=1}else if(o<0)a=-1,o=-o;else return null;ki.subVectors(this.origin,e);let l=a*this.direction.dot(Bo.crossVectors(ki,Bo));if(l<0)return null;let h=a*this.direction.dot(mc.cross(ki));if(h<0||l+h>o)return null;let f=-a*ki.dot(gc);return f<0?null:this.at(f/o,s)}applyMatrix4(e){return this.origin.applyMatrix4(e),this.direction.transformDirection(e),this}equals(e){return e.origin.equals(this.origin)&&e.direction.equals(this.direction)}clone(){return new this.constructor().copy(this)}},Mt=class r{constructor(e,t,n,i,s,o,a,l,h,f,c,u,d,p,v,g){r.prototype.isMatrix4=!0,this.elements=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],e!==void 0&&this.set(e,t,n,i,s,o,a,l,h,f,c,u,d,p,v,g)}set(e,t,n,i,s,o,a,l,h,f,c,u,d,p,v,g){let m=this.elements;return m[0]=e,m[4]=t,m[8]=n,m[12]=i,m[1]=s,m[5]=o,m[9]=a,m[13]=l,m[2]=h,m[6]=f,m[10]=c,m[14]=u,m[3]=d,m[7]=p,m[11]=v,m[15]=g,this}identity(){return this.set(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),this}clone(){return new r().fromArray(this.elements)}copy(e){let t=this.elements,n=e.elements;return t[0]=n[0],t[1]=n[1],t[2]=n[2],t[3]=n[3],t[4]=n[4],t[5]=n[5],t[6]=n[6],t[7]=n[7],t[8]=n[8],t[9]=n[9],t[10]=n[10],t[11]=n[11],t[12]=n[12],t[13]=n[13],t[14]=n[14],t[15]=n[15],this}copyPosition(e){let t=this.elements,n=e.elements;return t[12]=n[12],t[13]=n[13],t[14]=n[14],this}setFromMatrix3(e){let t=e.elements;return this.set(t[0],t[3],t[6],0,t[1],t[4],t[7],0,t[2],t[5],t[8],0,0,0,0,1),this}extractBasis(e,t,n){return e.setFromMatrixColumn(this,0),t.setFromMatrixColumn(this,1),n.setFromMatrixColumn(this,2),this}makeBasis(e,t,n){return this.set(e.x,t.x,n.x,0,e.y,t.y,n.y,0,e.z,t.z,n.z,0,0,0,0,1),this}extractRotation(e){let t=this.elements,n=e.elements,i=1/zs.setFromMatrixColumn(e,0).length(),s=1/zs.setFromMatrixColumn(e,1).length(),o=1/zs.setFromMatrixColumn(e,2).length();return t[0]=n[0]*i,t[1]=n[1]*i,t[2]=n[2]*i,t[3]=0,t[4]=n[4]*s,t[5]=n[5]*s,t[6]=n[6]*s,t[7]=0,t[8]=n[8]*o,t[9]=n[9]*o,t[10]=n[10]*o,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromEuler(e){let t=this.elements,n=e.x,i=e.y,s=e.z,o=Math.cos(n),a=Math.sin(n),l=Math.cos(i),h=Math.sin(i),f=Math.cos(s),c=Math.sin(s);if(e.order==="XYZ"){let u=o*f,d=o*c,p=a*f,v=a*c;t[0]=l*f,t[4]=-l*c,t[8]=h,t[1]=d+p*h,t[5]=u-v*h,t[9]=-a*l,t[2]=v-u*h,t[6]=p+d*h,t[10]=o*l}else if(e.order==="YXZ"){let u=l*f,d=l*c,p=h*f,v=h*c;t[0]=u+v*a,t[4]=p*a-d,t[8]=o*h,t[1]=o*c,t[5]=o*f,t[9]=-a,t[2]=d*a-p,t[6]=v+u*a,t[10]=o*l}else if(e.order==="ZXY"){let u=l*f,d=l*c,p=h*f,v=h*c;t[0]=u-v*a,t[4]=-o*c,t[8]=p+d*a,t[1]=d+p*a,t[5]=o*f,t[9]=v-u*a,t[2]=-o*h,t[6]=a,t[10]=o*l}else if(e.order==="ZYX"){let u=o*f,d=o*c,p=a*f,v=a*c;t[0]=l*f,t[4]=p*h-d,t[8]=u*h+v,t[1]=l*c,t[5]=v*h+u,t[9]=d*h-p,t[2]=-h,t[6]=a*l,t[10]=o*l}else if(e.order==="YZX"){let u=o*l,d=o*h,p=a*l,v=a*h;t[0]=l*f,t[4]=v-u*c,t[8]=p*c+d,t[1]=c,t[5]=o*f,t[9]=-a*f,t[2]=-h*f,t[6]=d*c+p,t[10]=u-v*c}else if(e.order==="XZY"){let u=o*l,d=o*h,p=a*l,v=a*h;t[0]=l*f,t[4]=-c,t[8]=h*f,t[1]=u*c+v,t[5]=o*f,t[9]=d*c-p,t[2]=p*c-d,t[6]=a*f,t[10]=v*c+u}return t[3]=0,t[7]=0,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromQuaternion(e){return this.compose(lp,e,cp)}lookAt(e,t,n){let i=this.elements;return yn.subVectors(e,t),yn.lengthSq()===0&&(yn.z=1),yn.normalize(),Vi.crossVectors(n,yn),Vi.lengthSq()===0&&(Math.abs(n.z)===1?yn.x+=1e-4:yn.z+=1e-4,yn.normalize(),Vi.crossVectors(n,yn)),Vi.normalize(),Uo.crossVectors(yn,Vi),i[0]=Vi.x,i[4]=Uo.x,i[8]=yn.x,i[1]=Vi.y,i[5]=Uo.y,i[9]=yn.y,i[2]=Vi.z,i[6]=Uo.z,i[10]=yn.z,this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){let n=e.elements,i=t.elements,s=this.elements,o=n[0],a=n[4],l=n[8],h=n[12],f=n[1],c=n[5],u=n[9],d=n[13],p=n[2],v=n[6],g=n[10],m=n[14],_=n[3],x=n[7],y=n[11],S=n[15],M=i[0],E=i[4],A=i[8],b=i[12],w=i[1],T=i[5],F=i[9],D=i[13],C=i[2],P=i[6],N=i[10],z=i[14],O=i[3],K=i[7],ee=i[11],oe=i[15];return s[0]=o*M+a*w+l*C+h*O,s[4]=o*E+a*T+l*P+h*K,s[8]=o*A+a*F+l*N+h*ee,s[12]=o*b+a*D+l*z+h*oe,s[1]=f*M+c*w+u*C+d*O,s[5]=f*E+c*T+u*P+d*K,s[9]=f*A+c*F+u*N+d*ee,s[13]=f*b+c*D+u*z+d*oe,s[2]=p*M+v*w+g*C+m*O,s[6]=p*E+v*T+g*P+m*K,s[10]=p*A+v*F+g*N+m*ee,s[14]=p*b+v*D+g*z+m*oe,s[3]=_*M+x*w+y*C+S*O,s[7]=_*E+x*T+y*P+S*K,s[11]=_*A+x*F+y*N+S*ee,s[15]=_*b+x*D+y*z+S*oe,this}multiplyScalar(e){let t=this.elements;return t[0]*=e,t[4]*=e,t[8]*=e,t[12]*=e,t[1]*=e,t[5]*=e,t[9]*=e,t[13]*=e,t[2]*=e,t[6]*=e,t[10]*=e,t[14]*=e,t[3]*=e,t[7]*=e,t[11]*=e,t[15]*=e,this}determinant(){let e=this.elements,t=e[0],n=e[4],i=e[8],s=e[12],o=e[1],a=e[5],l=e[9],h=e[13],f=e[2],c=e[6],u=e[10],d=e[14],p=e[3],v=e[7],g=e[11],m=e[15];return p*(+s*l*c-i*h*c-s*a*u+n*h*u+i*a*d-n*l*d)+v*(+t*l*d-t*h*u+s*o*u-i*o*d+i*h*f-s*l*f)+g*(+t*h*c-t*a*d-s*o*c+n*o*d+s*a*f-n*h*f)+m*(-i*a*f-t*l*c+t*a*u+i*o*c-n*o*u+n*l*f)}transpose(){let e=this.elements,t;return t=e[1],e[1]=e[4],e[4]=t,t=e[2],e[2]=e[8],e[8]=t,t=e[6],e[6]=e[9],e[9]=t,t=e[3],e[3]=e[12],e[12]=t,t=e[7],e[7]=e[13],e[13]=t,t=e[11],e[11]=e[14],e[14]=t,this}setPosition(e,t,n){let i=this.elements;return e.isVector3?(i[12]=e.x,i[13]=e.y,i[14]=e.z):(i[12]=e,i[13]=t,i[14]=n),this}invert(){let e=this.elements,t=e[0],n=e[1],i=e[2],s=e[3],o=e[4],a=e[5],l=e[6],h=e[7],f=e[8],c=e[9],u=e[10],d=e[11],p=e[12],v=e[13],g=e[14],m=e[15],_=c*g*h-v*u*h+v*l*d-a*g*d-c*l*m+a*u*m,x=p*u*h-f*g*h-p*l*d+o*g*d+f*l*m-o*u*m,y=f*v*h-p*c*h+p*a*d-o*v*d-f*a*m+o*c*m,S=p*c*l-f*v*l-p*a*u+o*v*u+f*a*g-o*c*g,M=t*_+n*x+i*y+s*S;if(M===0)return this.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);let E=1/M;return e[0]=_*E,e[1]=(v*u*s-c*g*s-v*i*d+n*g*d+c*i*m-n*u*m)*E,e[2]=(a*g*s-v*l*s+v*i*h-n*g*h-a*i*m+n*l*m)*E,e[3]=(c*l*s-a*u*s-c*i*h+n*u*h+a*i*d-n*l*d)*E,e[4]=x*E,e[5]=(f*g*s-p*u*s+p*i*d-t*g*d-f*i*m+t*u*m)*E,e[6]=(p*l*s-o*g*s-p*i*h+t*g*h+o*i*m-t*l*m)*E,e[7]=(o*u*s-f*l*s+f*i*h-t*u*h-o*i*d+t*l*d)*E,e[8]=y*E,e[9]=(p*c*s-f*v*s-p*n*d+t*v*d+f*n*m-t*c*m)*E,e[10]=(o*v*s-p*a*s+p*n*h-t*v*h-o*n*m+t*a*m)*E,e[11]=(f*a*s-o*c*s-f*n*h+t*c*h+o*n*d-t*a*d)*E,e[12]=S*E,e[13]=(f*v*i-p*c*i+p*n*u-t*v*u-f*n*g+t*c*g)*E,e[14]=(p*a*i-o*v*i-p*n*l+t*v*l+o*n*g-t*a*g)*E,e[15]=(o*c*i-f*a*i+f*n*l-t*c*l-o*n*u+t*a*u)*E,this}scale(e){let t=this.elements,n=e.x,i=e.y,s=e.z;return t[0]*=n,t[4]*=i,t[8]*=s,t[1]*=n,t[5]*=i,t[9]*=s,t[2]*=n,t[6]*=i,t[10]*=s,t[3]*=n,t[7]*=i,t[11]*=s,this}getMaxScaleOnAxis(){let e=this.elements,t=e[0]*e[0]+e[1]*e[1]+e[2]*e[2],n=e[4]*e[4]+e[5]*e[5]+e[6]*e[6],i=e[8]*e[8]+e[9]*e[9]+e[10]*e[10];return Math.sqrt(Math.max(t,n,i))}makeTranslation(e,t,n){return e.isVector3?this.set(1,0,0,e.x,0,1,0,e.y,0,0,1,e.z,0,0,0,1):this.set(1,0,0,e,0,1,0,t,0,0,1,n,0,0,0,1),this}makeRotationX(e){let t=Math.cos(e),n=Math.sin(e);return this.set(1,0,0,0,0,t,-n,0,0,n,t,0,0,0,0,1),this}makeRotationY(e){let t=Math.cos(e),n=Math.sin(e);return this.set(t,0,n,0,0,1,0,0,-n,0,t,0,0,0,0,1),this}makeRotationZ(e){let t=Math.cos(e),n=Math.sin(e);return this.set(t,-n,0,0,n,t,0,0,0,0,1,0,0,0,0,1),this}makeRotationAxis(e,t){let n=Math.cos(t),i=Math.sin(t),s=1-n,o=e.x,a=e.y,l=e.z,h=s*o,f=s*a;return this.set(h*o+n,h*a-i*l,h*l+i*a,0,h*a+i*l,f*a+n,f*l-i*o,0,h*l-i*a,f*l+i*o,s*l*l+n,0,0,0,0,1),this}makeScale(e,t,n){return this.set(e,0,0,0,0,t,0,0,0,0,n,0,0,0,0,1),this}makeShear(e,t,n,i,s,o){return this.set(1,n,s,0,e,1,o,0,t,i,1,0,0,0,0,1),this}compose(e,t,n){let i=this.elements,s=t._x,o=t._y,a=t._z,l=t._w,h=s+s,f=o+o,c=a+a,u=s*h,d=s*f,p=s*c,v=o*f,g=o*c,m=a*c,_=l*h,x=l*f,y=l*c,S=n.x,M=n.y,E=n.z;return i[0]=(1-(v+m))*S,i[1]=(d+y)*S,i[2]=(p-x)*S,i[3]=0,i[4]=(d-y)*M,i[5]=(1-(u+m))*M,i[6]=(g+_)*M,i[7]=0,i[8]=(p+x)*E,i[9]=(g-_)*E,i[10]=(1-(u+v))*E,i[11]=0,i[12]=e.x,i[13]=e.y,i[14]=e.z,i[15]=1,this}decompose(e,t,n){let i=this.elements,s=zs.set(i[0],i[1],i[2]).length(),o=zs.set(i[4],i[5],i[6]).length(),a=zs.set(i[8],i[9],i[10]).length();this.determinant()<0&&(s=-s),e.x=i[12],e.y=i[13],e.z=i[14],Wn.copy(this);let h=1/s,f=1/o,c=1/a;return Wn.elements[0]*=h,Wn.elements[1]*=h,Wn.elements[2]*=h,Wn.elements[4]*=f,Wn.elements[5]*=f,Wn.elements[6]*=f,Wn.elements[8]*=c,Wn.elements[9]*=c,Wn.elements[10]*=c,t.setFromRotationMatrix(Wn),n.x=s,n.y=o,n.z=a,this}makePerspective(e,t,n,i,s,o,a=Xn,l=!1){let h=this.elements,f=2*s/(t-e),c=2*s/(n-i),u=(t+e)/(t-e),d=(n+i)/(n-i),p,v;if(l)p=s/(o-s),v=o*s/(o-s);else if(a===Xn)p=-(o+s)/(o-s),v=-2*o*s/(o-s);else if(a===Dr)p=-o/(o-s),v=-o*s/(o-s);else throw new Error("THREE.Matrix4.makePerspective(): Invalid coordinate system: "+a);return h[0]=f,h[4]=0,h[8]=u,h[12]=0,h[1]=0,h[5]=c,h[9]=d,h[13]=0,h[2]=0,h[6]=0,h[10]=p,h[14]=v,h[3]=0,h[7]=0,h[11]=-1,h[15]=0,this}makeOrthographic(e,t,n,i,s,o,a=Xn,l=!1){let h=this.elements,f=2/(t-e),c=2/(n-i),u=-(t+e)/(t-e),d=-(n+i)/(n-i),p,v;if(l)p=1/(o-s),v=o/(o-s);else if(a===Xn)p=-2/(o-s),v=-(o+s)/(o-s);else if(a===Dr)p=-1/(o-s),v=-s/(o-s);else throw new Error("THREE.Matrix4.makeOrthographic(): Invalid coordinate system: "+a);return h[0]=f,h[4]=0,h[8]=0,h[12]=u,h[1]=0,h[5]=c,h[9]=0,h[13]=d,h[2]=0,h[6]=0,h[10]=p,h[14]=v,h[3]=0,h[7]=0,h[11]=0,h[15]=1,this}equals(e){let t=this.elements,n=e.elements;for(let i=0;i<16;i++)if(t[i]!==n[i])return!1;return!0}fromArray(e,t=0){for(let n=0;n<16;n++)this.elements[n]=e[n+t];return this}toArray(e=[],t=0){let n=this.elements;return e[t]=n[0],e[t+1]=n[1],e[t+2]=n[2],e[t+3]=n[3],e[t+4]=n[4],e[t+5]=n[5],e[t+6]=n[6],e[t+7]=n[7],e[t+8]=n[8],e[t+9]=n[9],e[t+10]=n[10],e[t+11]=n[11],e[t+12]=n[12],e[t+13]=n[13],e[t+14]=n[14],e[t+15]=n[15],e}},zs=new G,Wn=new Mt,lp=new G(0,0,0),cp=new G(1,1,1),Vi=new G,Uo=new G,yn=new G,pu=new Mt,mu=new wi,Zn=class r{constructor(e=0,t=0,n=0,i=r.DEFAULT_ORDER){this.isEuler=!0,this._x=e,this._y=t,this._z=n,this._order=i}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get order(){return this._order}set order(e){this._order=e,this._onChangeCallback()}set(e,t,n,i=this._order){return this._x=e,this._y=t,this._z=n,this._order=i,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._order)}copy(e){return this._x=e._x,this._y=e._y,this._z=e._z,this._order=e._order,this._onChangeCallback(),this}setFromRotationMatrix(e,t=this._order,n=!0){let i=e.elements,s=i[0],o=i[4],a=i[8],l=i[1],h=i[5],f=i[9],c=i[2],u=i[6],d=i[10];switch(t){case"XYZ":this._y=Math.asin(at(a,-1,1)),Math.abs(a)<.9999999?(this._x=Math.atan2(-f,d),this._z=Math.atan2(-o,s)):(this._x=Math.atan2(u,h),this._z=0);break;case"YXZ":this._x=Math.asin(-at(f,-1,1)),Math.abs(f)<.9999999?(this._y=Math.atan2(a,d),this._z=Math.atan2(l,h)):(this._y=Math.atan2(-c,s),this._z=0);break;case"ZXY":this._x=Math.asin(at(u,-1,1)),Math.abs(u)<.9999999?(this._y=Math.atan2(-c,d),this._z=Math.atan2(-o,h)):(this._y=0,this._z=Math.atan2(l,s));break;case"ZYX":this._y=Math.asin(-at(c,-1,1)),Math.abs(c)<.9999999?(this._x=Math.atan2(u,d),this._z=Math.atan2(l,s)):(this._x=0,this._z=Math.atan2(-o,h));break;case"YZX":this._z=Math.asin(at(l,-1,1)),Math.abs(l)<.9999999?(this._x=Math.atan2(-f,h),this._y=Math.atan2(-c,s)):(this._x=0,this._y=Math.atan2(a,d));break;case"XZY":this._z=Math.asin(-at(o,-1,1)),Math.abs(o)<.9999999?(this._x=Math.atan2(u,h),this._y=Math.atan2(a,s)):(this._x=Math.atan2(-f,d),this._y=0);break;default:console.warn("THREE.Euler: .setFromRotationMatrix() encountered an unknown order: "+t)}return this._order=t,n===!0&&this._onChangeCallback(),this}setFromQuaternion(e,t,n){return pu.makeRotationFromQuaternion(e),this.setFromRotationMatrix(pu,t,n)}setFromVector3(e,t=this._order){return this.set(e.x,e.y,e.z,t)}reorder(e){return mu.setFromEuler(this),this.setFromQuaternion(mu,e)}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._order===this._order}fromArray(e){return this._x=e[0],this._y=e[1],this._z=e[2],e[3]!==void 0&&(this._order=e[3]),this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._order,e}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._order}};Zn.DEFAULT_ORDER="XYZ";var Qs=class{constructor(){this.mask=1}set(e){this.mask=(1<<e|0)>>>0}enable(e){this.mask|=1<<e|0}enableAll(){this.mask=-1}toggle(e){this.mask^=1<<e|0}disable(e){this.mask&=~(1<<e|0)}disableAll(){this.mask=0}test(e){return(this.mask&e.mask)!==0}isEnabled(e){return(this.mask&(1<<e|0))!==0}},hp=0,gu=new G,ks=new wi,xi=new Mt,Oo=new G,Rr=new G,up=new G,fp=new wi,vu=new G(1,0,0),xu=new G(0,1,0),yu=new G(0,0,1),_u={type:"added"},dp={type:"removed"},Vs={type:"childadded",child:null},vc={type:"childremoved",child:null},Xt=class r extends bi{constructor(){super(),this.isObject3D=!0,Object.defineProperty(this,"id",{value:hp++}),this.uuid=lo(),this.name="",this.type="Object3D",this.parent=null,this.children=[],this.up=r.DEFAULT_UP.clone();let e=new G,t=new Zn,n=new wi,i=new G(1,1,1);function s(){n.setFromEuler(t,!1)}function o(){t.setFromQuaternion(n,void 0,!1)}t._onChange(s),n._onChange(o),Object.defineProperties(this,{position:{configurable:!0,enumerable:!0,value:e},rotation:{configurable:!0,enumerable:!0,value:t},quaternion:{configurable:!0,enumerable:!0,value:n},scale:{configurable:!0,enumerable:!0,value:i},modelViewMatrix:{value:new Mt},normalMatrix:{value:new tt}}),this.matrix=new Mt,this.matrixWorld=new Mt,this.matrixAutoUpdate=r.DEFAULT_MATRIX_AUTO_UPDATE,this.matrixWorldAutoUpdate=r.DEFAULT_MATRIX_WORLD_AUTO_UPDATE,this.matrixWorldNeedsUpdate=!1,this.layers=new Qs,this.visible=!0,this.castShadow=!1,this.receiveShadow=!1,this.frustumCulled=!0,this.renderOrder=0,this.animations=[],this.customDepthMaterial=void 0,this.customDistanceMaterial=void 0,this.userData={}}onBeforeShadow(){}onAfterShadow(){}onBeforeRender(){}onAfterRender(){}applyMatrix4(e){this.matrixAutoUpdate&&this.updateMatrix(),this.matrix.premultiply(e),this.matrix.decompose(this.position,this.quaternion,this.scale)}applyQuaternion(e){return this.quaternion.premultiply(e),this}setRotationFromAxisAngle(e,t){this.quaternion.setFromAxisAngle(e,t)}setRotationFromEuler(e){this.quaternion.setFromEuler(e,!0)}setRotationFromMatrix(e){this.quaternion.setFromRotationMatrix(e)}setRotationFromQuaternion(e){this.quaternion.copy(e)}rotateOnAxis(e,t){return ks.setFromAxisAngle(e,t),this.quaternion.multiply(ks),this}rotateOnWorldAxis(e,t){return ks.setFromAxisAngle(e,t),this.quaternion.premultiply(ks),this}rotateX(e){return this.rotateOnAxis(vu,e)}rotateY(e){return this.rotateOnAxis(xu,e)}rotateZ(e){return this.rotateOnAxis(yu,e)}translateOnAxis(e,t){return gu.copy(e).applyQuaternion(this.quaternion),this.position.add(gu.multiplyScalar(t)),this}translateX(e){return this.translateOnAxis(vu,e)}translateY(e){return this.translateOnAxis(xu,e)}translateZ(e){return this.translateOnAxis(yu,e)}localToWorld(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(this.matrixWorld)}worldToLocal(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(xi.copy(this.matrixWorld).invert())}lookAt(e,t,n){e.isVector3?Oo.copy(e):Oo.set(e,t,n);let i=this.parent;this.updateWorldMatrix(!0,!1),Rr.setFromMatrixPosition(this.matrixWorld),this.isCamera||this.isLight?xi.lookAt(Rr,Oo,this.up):xi.lookAt(Oo,Rr,this.up),this.quaternion.setFromRotationMatrix(xi),i&&(xi.extractRotation(i.matrixWorld),ks.setFromRotationMatrix(xi),this.quaternion.premultiply(ks.invert()))}add(e){if(arguments.length>1){for(let t=0;t<arguments.length;t++)this.add(arguments[t]);return this}return e===this?(console.error("THREE.Object3D.add: object can't be added as a child of itself.",e),this):(e&&e.isObject3D?(e.removeFromParent(),e.parent=this,this.children.push(e),e.dispatchEvent(_u),Vs.child=e,this.dispatchEvent(Vs),Vs.child=null):console.error("THREE.Object3D.add: object not an instance of THREE.Object3D.",e),this)}remove(e){if(arguments.length>1){for(let n=0;n<arguments.length;n++)this.remove(arguments[n]);return this}let t=this.children.indexOf(e);return t!==-1&&(e.parent=null,this.children.splice(t,1),e.dispatchEvent(dp),vc.child=e,this.dispatchEvent(vc),vc.child=null),this}removeFromParent(){let e=this.parent;return e!==null&&e.remove(this),this}clear(){return this.remove(...this.children)}attach(e){return this.updateWorldMatrix(!0,!1),xi.copy(this.matrixWorld).invert(),e.parent!==null&&(e.parent.updateWorldMatrix(!0,!1),xi.multiply(e.parent.matrixWorld)),e.applyMatrix4(xi),e.removeFromParent(),e.parent=this,this.children.push(e),e.updateWorldMatrix(!1,!0),e.dispatchEvent(_u),Vs.child=e,this.dispatchEvent(Vs),Vs.child=null,this}getObjectById(e){return this.getObjectByProperty("id",e)}getObjectByName(e){return this.getObjectByProperty("name",e)}getObjectByProperty(e,t){if(this[e]===t)return this;for(let n=0,i=this.children.length;n<i;n++){let o=this.children[n].getObjectByProperty(e,t);if(o!==void 0)return o}}getObjectsByProperty(e,t,n=[]){this[e]===t&&n.push(this);let i=this.children;for(let s=0,o=i.length;s<o;s++)i[s].getObjectsByProperty(e,t,n);return n}getWorldPosition(e){return this.updateWorldMatrix(!0,!1),e.setFromMatrixPosition(this.matrixWorld)}getWorldQuaternion(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(Rr,e,up),e}getWorldScale(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(Rr,fp,e),e}getWorldDirection(e){this.updateWorldMatrix(!0,!1);let t=this.matrixWorld.elements;return e.set(t[8],t[9],t[10]).normalize()}raycast(){}traverse(e){e(this);let t=this.children;for(let n=0,i=t.length;n<i;n++)t[n].traverse(e)}traverseVisible(e){if(this.visible===!1)return;e(this);let t=this.children;for(let n=0,i=t.length;n<i;n++)t[n].traverseVisible(e)}traverseAncestors(e){let t=this.parent;t!==null&&(e(t),t.traverseAncestors(e))}updateMatrix(){this.matrix.compose(this.position,this.quaternion,this.scale),this.matrixWorldNeedsUpdate=!0}updateMatrixWorld(e){this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||e)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,e=!0);let t=this.children;for(let n=0,i=t.length;n<i;n++)t[n].updateMatrixWorld(e)}updateWorldMatrix(e,t){let n=this.parent;if(e===!0&&n!==null&&n.updateWorldMatrix(!0,!1),this.matrixAutoUpdate&&this.updateMatrix(),this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),t===!0){let i=this.children;for(let s=0,o=i.length;s<o;s++)i[s].updateWorldMatrix(!1,!0)}}toJSON(e){let t=e===void 0||typeof e=="string",n={};t&&(e={geometries:{},materials:{},textures:{},images:{},shapes:{},skeletons:{},animations:{},nodes:{}},n.metadata={version:4.7,type:"Object",generator:"Object3D.toJSON"});let i={};i.uuid=this.uuid,i.type=this.type,this.name!==""&&(i.name=this.name),this.castShadow===!0&&(i.castShadow=!0),this.receiveShadow===!0&&(i.receiveShadow=!0),this.visible===!1&&(i.visible=!1),this.frustumCulled===!1&&(i.frustumCulled=!1),this.renderOrder!==0&&(i.renderOrder=this.renderOrder),Object.keys(this.userData).length>0&&(i.userData=this.userData),i.layers=this.layers.mask,i.matrix=this.matrix.toArray(),i.up=this.up.toArray(),this.matrixAutoUpdate===!1&&(i.matrixAutoUpdate=!1),this.isInstancedMesh&&(i.type="InstancedMesh",i.count=this.count,i.instanceMatrix=this.instanceMatrix.toJSON(),this.instanceColor!==null&&(i.instanceColor=this.instanceColor.toJSON())),this.isBatchedMesh&&(i.type="BatchedMesh",i.perObjectFrustumCulled=this.perObjectFrustumCulled,i.sortObjects=this.sortObjects,i.drawRanges=this._drawRanges,i.reservedRanges=this._reservedRanges,i.geometryInfo=this._geometryInfo.map(a=>({...a,boundingBox:a.boundingBox?a.boundingBox.toJSON():void 0,boundingSphere:a.boundingSphere?a.boundingSphere.toJSON():void 0})),i.instanceInfo=this._instanceInfo.map(a=>({...a})),i.availableInstanceIds=this._availableInstanceIds.slice(),i.availableGeometryIds=this._availableGeometryIds.slice(),i.nextIndexStart=this._nextIndexStart,i.nextVertexStart=this._nextVertexStart,i.geometryCount=this._geometryCount,i.maxInstanceCount=this._maxInstanceCount,i.maxVertexCount=this._maxVertexCount,i.maxIndexCount=this._maxIndexCount,i.geometryInitialized=this._geometryInitialized,i.matricesTexture=this._matricesTexture.toJSON(e),i.indirectTexture=this._indirectTexture.toJSON(e),this._colorsTexture!==null&&(i.colorsTexture=this._colorsTexture.toJSON(e)),this.boundingSphere!==null&&(i.boundingSphere=this.boundingSphere.toJSON()),this.boundingBox!==null&&(i.boundingBox=this.boundingBox.toJSON()));function s(a,l){return a[l.uuid]===void 0&&(a[l.uuid]=l.toJSON(e)),l.uuid}if(this.isScene)this.background&&(this.background.isColor?i.background=this.background.toJSON():this.background.isTexture&&(i.background=this.background.toJSON(e).uuid)),this.environment&&this.environment.isTexture&&this.environment.isRenderTargetTexture!==!0&&(i.environment=this.environment.toJSON(e).uuid);else if(this.isMesh||this.isLine||this.isPoints){i.geometry=s(e.geometries,this.geometry);let a=this.geometry.parameters;if(a!==void 0&&a.shapes!==void 0){let l=a.shapes;if(Array.isArray(l))for(let h=0,f=l.length;h<f;h++){let c=l[h];s(e.shapes,c)}else s(e.shapes,l)}}if(this.isSkinnedMesh&&(i.bindMode=this.bindMode,i.bindMatrix=this.bindMatrix.toArray(),this.skeleton!==void 0&&(s(e.skeletons,this.skeleton),i.skeleton=this.skeleton.uuid)),this.material!==void 0)if(Array.isArray(this.material)){let a=[];for(let l=0,h=this.material.length;l<h;l++)a.push(s(e.materials,this.material[l]));i.material=a}else i.material=s(e.materials,this.material);if(this.children.length>0){i.children=[];for(let a=0;a<this.children.length;a++)i.children.push(this.children[a].toJSON(e).object)}if(this.animations.length>0){i.animations=[];for(let a=0;a<this.animations.length;a++){let l=this.animations[a];i.animations.push(s(e.animations,l))}}if(t){let a=o(e.geometries),l=o(e.materials),h=o(e.textures),f=o(e.images),c=o(e.shapes),u=o(e.skeletons),d=o(e.animations),p=o(e.nodes);a.length>0&&(n.geometries=a),l.length>0&&(n.materials=l),h.length>0&&(n.textures=h),f.length>0&&(n.images=f),c.length>0&&(n.shapes=c),u.length>0&&(n.skeletons=u),d.length>0&&(n.animations=d),p.length>0&&(n.nodes=p)}return n.object=i,n;function o(a){let l=[];for(let h in a){let f=a[h];delete f.metadata,l.push(f)}return l}}clone(e){return new this.constructor().copy(this,e)}copy(e,t=!0){if(this.name=e.name,this.up.copy(e.up),this.position.copy(e.position),this.rotation.order=e.rotation.order,this.quaternion.copy(e.quaternion),this.scale.copy(e.scale),this.matrix.copy(e.matrix),this.matrixWorld.copy(e.matrixWorld),this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrixWorldAutoUpdate=e.matrixWorldAutoUpdate,this.matrixWorldNeedsUpdate=e.matrixWorldNeedsUpdate,this.layers.mask=e.layers.mask,this.visible=e.visible,this.castShadow=e.castShadow,this.receiveShadow=e.receiveShadow,this.frustumCulled=e.frustumCulled,this.renderOrder=e.renderOrder,this.animations=e.animations.slice(),this.userData=JSON.parse(JSON.stringify(e.userData)),t===!0)for(let n=0;n<e.children.length;n++){let i=e.children[n];this.add(i.clone())}return this}};Xt.DEFAULT_UP=new G(0,1,0);Xt.DEFAULT_MATRIX_AUTO_UPDATE=!0;Xt.DEFAULT_MATRIX_WORLD_AUTO_UPDATE=!0;var qn=new G,yi=new G,xc=new G,_i=new G,Hs=new G,Gs=new G,Mu=new G,yc=new G,_c=new G,Mc=new G,Sc=new St,bc=new St,wc=new St,Wi=class r{constructor(e=new G,t=new G,n=new G){this.a=e,this.b=t,this.c=n}static getNormal(e,t,n,i){i.subVectors(n,t),qn.subVectors(e,t),i.cross(qn);let s=i.lengthSq();return s>0?i.multiplyScalar(1/Math.sqrt(s)):i.set(0,0,0)}static getBarycoord(e,t,n,i,s){qn.subVectors(i,t),yi.subVectors(n,t),xc.subVectors(e,t);let o=qn.dot(qn),a=qn.dot(yi),l=qn.dot(xc),h=yi.dot(yi),f=yi.dot(xc),c=o*h-a*a;if(c===0)return s.set(0,0,0),null;let u=1/c,d=(h*l-a*f)*u,p=(o*f-a*l)*u;return s.set(1-d-p,p,d)}static containsPoint(e,t,n,i){return this.getBarycoord(e,t,n,i,_i)===null?!1:_i.x>=0&&_i.y>=0&&_i.x+_i.y<=1}static getInterpolation(e,t,n,i,s,o,a,l){return this.getBarycoord(e,t,n,i,_i)===null?(l.x=0,l.y=0,"z"in l&&(l.z=0),"w"in l&&(l.w=0),null):(l.setScalar(0),l.addScaledVector(s,_i.x),l.addScaledVector(o,_i.y),l.addScaledVector(a,_i.z),l)}static getInterpolatedAttribute(e,t,n,i,s,o){return Sc.setScalar(0),bc.setScalar(0),wc.setScalar(0),Sc.fromBufferAttribute(e,t),bc.fromBufferAttribute(e,n),wc.fromBufferAttribute(e,i),o.setScalar(0),o.addScaledVector(Sc,s.x),o.addScaledVector(bc,s.y),o.addScaledVector(wc,s.z),o}static isFrontFacing(e,t,n,i){return qn.subVectors(n,t),yi.subVectors(e,t),qn.cross(yi).dot(i)<0}set(e,t,n){return this.a.copy(e),this.b.copy(t),this.c.copy(n),this}setFromPointsAndIndices(e,t,n,i){return this.a.copy(e[t]),this.b.copy(e[n]),this.c.copy(e[i]),this}setFromAttributeAndIndices(e,t,n,i){return this.a.fromBufferAttribute(e,t),this.b.fromBufferAttribute(e,n),this.c.fromBufferAttribute(e,i),this}clone(){return new this.constructor().copy(this)}copy(e){return this.a.copy(e.a),this.b.copy(e.b),this.c.copy(e.c),this}getArea(){return qn.subVectors(this.c,this.b),yi.subVectors(this.a,this.b),qn.cross(yi).length()*.5}getMidpoint(e){return e.addVectors(this.a,this.b).add(this.c).multiplyScalar(1/3)}getNormal(e){return r.getNormal(this.a,this.b,this.c,e)}getPlane(e){return e.setFromCoplanarPoints(this.a,this.b,this.c)}getBarycoord(e,t){return r.getBarycoord(e,this.a,this.b,this.c,t)}getInterpolation(e,t,n,i,s){return r.getInterpolation(e,this.a,this.b,this.c,t,n,i,s)}containsPoint(e){return r.containsPoint(e,this.a,this.b,this.c)}isFrontFacing(e){return r.isFrontFacing(this.a,this.b,this.c,e)}intersectsBox(e){return e.intersectsTriangle(this)}closestPointToPoint(e,t){let n=this.a,i=this.b,s=this.c,o,a;Hs.subVectors(i,n),Gs.subVectors(s,n),yc.subVectors(e,n);let l=Hs.dot(yc),h=Gs.dot(yc);if(l<=0&&h<=0)return t.copy(n);_c.subVectors(e,i);let f=Hs.dot(_c),c=Gs.dot(_c);if(f>=0&&c<=f)return t.copy(i);let u=l*c-f*h;if(u<=0&&l>=0&&f<=0)return o=l/(l-f),t.copy(n).addScaledVector(Hs,o);Mc.subVectors(e,s);let d=Hs.dot(Mc),p=Gs.dot(Mc);if(p>=0&&d<=p)return t.copy(s);let v=d*h-l*p;if(v<=0&&h>=0&&p<=0)return a=h/(h-p),t.copy(n).addScaledVector(Gs,a);let g=f*p-d*c;if(g<=0&&c-f>=0&&d-p>=0)return Mu.subVectors(s,i),a=(c-f)/(c-f+(d-p)),t.copy(i).addScaledVector(Mu,a);let m=1/(g+v+u);return o=v*m,a=u*m,t.copy(n).addScaledVector(Hs,o).addScaledVector(Gs,a)}equals(e){return e.a.equals(this.a)&&e.b.equals(this.b)&&e.c.equals(this.c)}},Mf={aliceblue:15792383,antiquewhite:16444375,aqua:65535,aquamarine:8388564,azure:15794175,beige:16119260,bisque:16770244,black:0,blanchedalmond:16772045,blue:255,blueviolet:9055202,brown:10824234,burlywood:14596231,cadetblue:6266528,chartreuse:8388352,chocolate:13789470,coral:16744272,cornflowerblue:6591981,cornsilk:16775388,crimson:14423100,cyan:65535,darkblue:139,darkcyan:35723,darkgoldenrod:12092939,darkgray:11119017,darkgreen:25600,darkgrey:11119017,darkkhaki:12433259,darkmagenta:9109643,darkolivegreen:5597999,darkorange:16747520,darkorchid:10040012,darkred:9109504,darksalmon:15308410,darkseagreen:9419919,darkslateblue:4734347,darkslategray:3100495,darkslategrey:3100495,darkturquoise:52945,darkviolet:9699539,deeppink:16716947,deepskyblue:49151,dimgray:6908265,dimgrey:6908265,dodgerblue:2003199,firebrick:11674146,floralwhite:16775920,forestgreen:2263842,fuchsia:16711935,gainsboro:14474460,ghostwhite:16316671,gold:16766720,goldenrod:14329120,gray:8421504,green:32768,greenyellow:11403055,grey:8421504,honeydew:15794160,hotpink:16738740,indianred:13458524,indigo:4915330,ivory:16777200,khaki:15787660,lavender:15132410,lavenderblush:16773365,lawngreen:8190976,lemonchiffon:16775885,lightblue:11393254,lightcoral:15761536,lightcyan:14745599,lightgoldenrodyellow:16448210,lightgray:13882323,lightgreen:9498256,lightgrey:13882323,lightpink:16758465,lightsalmon:16752762,lightseagreen:2142890,lightskyblue:8900346,lightslategray:7833753,lightslategrey:7833753,lightsteelblue:11584734,lightyellow:16777184,lime:65280,limegreen:3329330,linen:16445670,magenta:16711935,maroon:8388608,mediumaquamarine:6737322,mediumblue:205,mediumorchid:12211667,mediumpurple:9662683,mediumseagreen:3978097,mediumslateblue:8087790,mediumspringgreen:64154,mediumturquoise:4772300,mediumvioletred:13047173,midnightblue:1644912,mintcream:16121850,mistyrose:16770273,moccasin:16770229,navajowhite:16768685,navy:128,oldlace:16643558,olive:8421376,olivedrab:7048739,orange:16753920,orangered:16729344,orchid:14315734,palegoldenrod:15657130,palegreen:10025880,paleturquoise:11529966,palevioletred:14381203,papayawhip:16773077,peachpuff:16767673,peru:13468991,pink:16761035,plum:14524637,powderblue:11591910,purple:8388736,rebeccapurple:6697881,red:16711680,rosybrown:12357519,royalblue:4286945,saddlebrown:9127187,salmon:16416882,sandybrown:16032864,seagreen:3050327,seashell:16774638,sienna:10506797,silver:12632256,skyblue:8900331,slateblue:6970061,slategray:7372944,slategrey:7372944,snow:16775930,springgreen:65407,steelblue:4620980,tan:13808780,teal:32896,thistle:14204888,tomato:16737095,turquoise:4251856,violet:15631086,wheat:16113331,white:16777215,whitesmoke:16119285,yellow:16776960,yellowgreen:10145074},Hi={h:0,s:0,l:0},zo={h:0,s:0,l:0};function Ec(r,e,t){return t<0&&(t+=1),t>1&&(t-=1),t<1/6?r+(e-r)*6*t:t<1/2?e:t<2/3?r+(e-r)*6*(2/3-t):r}var ot=class{constructor(e,t,n){return this.isColor=!0,this.r=1,this.g=1,this.b=1,this.set(e,t,n)}set(e,t,n){if(t===void 0&&n===void 0){let i=e;i&&i.isColor?this.copy(i):typeof i=="number"?this.setHex(i):typeof i=="string"&&this.setStyle(i)}else this.setRGB(e,t,n);return this}setScalar(e){return this.r=e,this.g=e,this.b=e,this}setHex(e,t=jt){return e=Math.floor(e),this.r=(e>>16&255)/255,this.g=(e>>8&255)/255,this.b=(e&255)/255,lt.colorSpaceToWorking(this,t),this}setRGB(e,t,n,i=lt.workingColorSpace){return this.r=e,this.g=t,this.b=n,lt.colorSpaceToWorking(this,i),this}setHSL(e,t,n,i=lt.workingColorSpace){if(e=ip(e,1),t=at(t,0,1),n=at(n,0,1),t===0)this.r=this.g=this.b=n;else{let s=n<=.5?n*(1+t):n+t-n*t,o=2*n-s;this.r=Ec(o,s,e+1/3),this.g=Ec(o,s,e),this.b=Ec(o,s,e-1/3)}return lt.colorSpaceToWorking(this,i),this}setStyle(e,t=jt){function n(s){s!==void 0&&parseFloat(s)<1&&console.warn("THREE.Color: Alpha component of "+e+" will be ignored.")}let i;if(i=/^(\w+)\(([^\)]*)\)/.exec(e)){let s,o=i[1],a=i[2];switch(o){case"rgb":case"rgba":if(s=/^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(a))return n(s[4]),this.setRGB(Math.min(255,parseInt(s[1],10))/255,Math.min(255,parseInt(s[2],10))/255,Math.min(255,parseInt(s[3],10))/255,t);if(s=/^\s*(\d+)\%\s*,\s*(\d+)\%\s*,\s*(\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(a))return n(s[4]),this.setRGB(Math.min(100,parseInt(s[1],10))/100,Math.min(100,parseInt(s[2],10))/100,Math.min(100,parseInt(s[3],10))/100,t);break;case"hsl":case"hsla":if(s=/^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)\%\s*,\s*(\d*\.?\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(a))return n(s[4]),this.setHSL(parseFloat(s[1])/360,parseFloat(s[2])/100,parseFloat(s[3])/100,t);break;default:console.warn("THREE.Color: Unknown color model "+e)}}else if(i=/^\#([A-Fa-f\d]+)$/.exec(e)){let s=i[1],o=s.length;if(o===3)return this.setRGB(parseInt(s.charAt(0),16)/15,parseInt(s.charAt(1),16)/15,parseInt(s.charAt(2),16)/15,t);if(o===6)return this.setHex(parseInt(s,16),t);console.warn("THREE.Color: Invalid hex color "+e)}else if(e&&e.length>0)return this.setColorName(e,t);return this}setColorName(e,t=jt){let n=Mf[e.toLowerCase()];return n!==void 0?this.setHex(n,t):console.warn("THREE.Color: Unknown color "+e),this}clone(){return new this.constructor(this.r,this.g,this.b)}copy(e){return this.r=e.r,this.g=e.g,this.b=e.b,this}copySRGBToLinear(e){return this.r=Mi(e.r),this.g=Mi(e.g),this.b=Mi(e.b),this}copyLinearToSRGB(e){return this.r=$s(e.r),this.g=$s(e.g),this.b=$s(e.b),this}convertSRGBToLinear(){return this.copySRGBToLinear(this),this}convertLinearToSRGB(){return this.copyLinearToSRGB(this),this}getHex(e=jt){return lt.workingToColorSpace(Jt.copy(this),e),Math.round(at(Jt.r*255,0,255))*65536+Math.round(at(Jt.g*255,0,255))*256+Math.round(at(Jt.b*255,0,255))}getHexString(e=jt){return("000000"+this.getHex(e).toString(16)).slice(-6)}getHSL(e,t=lt.workingColorSpace){lt.workingToColorSpace(Jt.copy(this),t);let n=Jt.r,i=Jt.g,s=Jt.b,o=Math.max(n,i,s),a=Math.min(n,i,s),l,h,f=(a+o)/2;if(a===o)l=0,h=0;else{let c=o-a;switch(h=f<=.5?c/(o+a):c/(2-o-a),o){case n:l=(i-s)/c+(i<s?6:0);break;case i:l=(s-n)/c+2;break;case s:l=(n-i)/c+4;break}l/=6}return e.h=l,e.s=h,e.l=f,e}getRGB(e,t=lt.workingColorSpace){return lt.workingToColorSpace(Jt.copy(this),t),e.r=Jt.r,e.g=Jt.g,e.b=Jt.b,e}getStyle(e=jt){lt.workingToColorSpace(Jt.copy(this),e);let t=Jt.r,n=Jt.g,i=Jt.b;return e!==jt?`color(${e} ${t.toFixed(3)} ${n.toFixed(3)} ${i.toFixed(3)})`:`rgb(${Math.round(t*255)},${Math.round(n*255)},${Math.round(i*255)})`}offsetHSL(e,t,n){return this.getHSL(Hi),this.setHSL(Hi.h+e,Hi.s+t,Hi.l+n)}add(e){return this.r+=e.r,this.g+=e.g,this.b+=e.b,this}addColors(e,t){return this.r=e.r+t.r,this.g=e.g+t.g,this.b=e.b+t.b,this}addScalar(e){return this.r+=e,this.g+=e,this.b+=e,this}sub(e){return this.r=Math.max(0,this.r-e.r),this.g=Math.max(0,this.g-e.g),this.b=Math.max(0,this.b-e.b),this}multiply(e){return this.r*=e.r,this.g*=e.g,this.b*=e.b,this}multiplyScalar(e){return this.r*=e,this.g*=e,this.b*=e,this}lerp(e,t){return this.r+=(e.r-this.r)*t,this.g+=(e.g-this.g)*t,this.b+=(e.b-this.b)*t,this}lerpColors(e,t,n){return this.r=e.r+(t.r-e.r)*n,this.g=e.g+(t.g-e.g)*n,this.b=e.b+(t.b-e.b)*n,this}lerpHSL(e,t){this.getHSL(Hi),e.getHSL(zo);let n=ac(Hi.h,zo.h,t),i=ac(Hi.s,zo.s,t),s=ac(Hi.l,zo.l,t);return this.setHSL(n,i,s),this}setFromVector3(e){return this.r=e.x,this.g=e.y,this.b=e.z,this}applyMatrix3(e){let t=this.r,n=this.g,i=this.b,s=e.elements;return this.r=s[0]*t+s[3]*n+s[6]*i,this.g=s[1]*t+s[4]*n+s[7]*i,this.b=s[2]*t+s[5]*n+s[8]*i,this}equals(e){return e.r===this.r&&e.g===this.g&&e.b===this.b}fromArray(e,t=0){return this.r=e[t],this.g=e[t+1],this.b=e[t+2],this}toArray(e=[],t=0){return e[t]=this.r,e[t+1]=this.g,e[t+2]=this.b,e}fromBufferAttribute(e,t){return this.r=e.getX(t),this.g=e.getY(t),this.b=e.getZ(t),this}toJSON(){return this.getHex()}*[Symbol.iterator](){yield this.r,yield this.g,yield this.b}},Jt=new ot;ot.NAMES=Mf;var pp=0,Ei=class extends bi{constructor(){super(),this.isMaterial=!0,Object.defineProperty(this,"id",{value:pp++}),this.uuid=lo(),this.name="",this.type="Material",this.blending=ps,this.side=Si,this.vertexColors=!1,this.opacity=1,this.transparent=!1,this.alphaHash=!1,this.blendSrc=Qo,this.blendDst=ea,this.blendEquation=Xi,this.blendSrcAlpha=null,this.blendDstAlpha=null,this.blendEquationAlpha=null,this.blendColor=new ot(0,0,0),this.blendAlpha=0,this.depthFunc=ms,this.depthTest=!0,this.depthWrite=!0,this.stencilWriteMask=255,this.stencilFunc=Dc,this.stencilRef=0,this.stencilFuncMask=255,this.stencilFail=ds,this.stencilZFail=ds,this.stencilZPass=ds,this.stencilWrite=!1,this.clippingPlanes=null,this.clipIntersection=!1,this.clipShadows=!1,this.shadowSide=null,this.colorWrite=!0,this.precision=null,this.polygonOffset=!1,this.polygonOffsetFactor=0,this.polygonOffsetUnits=0,this.dithering=!1,this.alphaToCoverage=!1,this.premultipliedAlpha=!1,this.forceSinglePass=!1,this.allowOverride=!0,this.visible=!0,this.toneMapped=!0,this.userData={},this.version=0,this._alphaTest=0}get alphaTest(){return this._alphaTest}set alphaTest(e){this._alphaTest>0!=e>0&&this.version++,this._alphaTest=e}onBeforeRender(){}onBeforeCompile(){}customProgramCacheKey(){return this.onBeforeCompile.toString()}setValues(e){if(e!==void 0)for(let t in e){let n=e[t];if(n===void 0){console.warn(`THREE.Material: parameter '${t}' has value of undefined.`);continue}let i=this[t];if(i===void 0){console.warn(`THREE.Material: '${t}' is not a property of THREE.${this.type}.`);continue}i&&i.isColor?i.set(n):i&&i.isVector3&&n&&n.isVector3?i.copy(n):this[t]=n}}toJSON(e){let t=e===void 0||typeof e=="string";t&&(e={textures:{},images:{}});let n={metadata:{version:4.7,type:"Material",generator:"Material.toJSON"}};n.uuid=this.uuid,n.type=this.type,this.name!==""&&(n.name=this.name),this.color&&this.color.isColor&&(n.color=this.color.getHex()),this.roughness!==void 0&&(n.roughness=this.roughness),this.metalness!==void 0&&(n.metalness=this.metalness),this.sheen!==void 0&&(n.sheen=this.sheen),this.sheenColor&&this.sheenColor.isColor&&(n.sheenColor=this.sheenColor.getHex()),this.sheenRoughness!==void 0&&(n.sheenRoughness=this.sheenRoughness),this.emissive&&this.emissive.isColor&&(n.emissive=this.emissive.getHex()),this.emissiveIntensity!==void 0&&this.emissiveIntensity!==1&&(n.emissiveIntensity=this.emissiveIntensity),this.specular&&this.specular.isColor&&(n.specular=this.specular.getHex()),this.specularIntensity!==void 0&&(n.specularIntensity=this.specularIntensity),this.specularColor&&this.specularColor.isColor&&(n.specularColor=this.specularColor.getHex()),this.shininess!==void 0&&(n.shininess=this.shininess),this.clearcoat!==void 0&&(n.clearcoat=this.clearcoat),this.clearcoatRoughness!==void 0&&(n.clearcoatRoughness=this.clearcoatRoughness),this.clearcoatMap&&this.clearcoatMap.isTexture&&(n.clearcoatMap=this.clearcoatMap.toJSON(e).uuid),this.clearcoatRoughnessMap&&this.clearcoatRoughnessMap.isTexture&&(n.clearcoatRoughnessMap=this.clearcoatRoughnessMap.toJSON(e).uuid),this.clearcoatNormalMap&&this.clearcoatNormalMap.isTexture&&(n.clearcoatNormalMap=this.clearcoatNormalMap.toJSON(e).uuid,n.clearcoatNormalScale=this.clearcoatNormalScale.toArray()),this.sheenColorMap&&this.sheenColorMap.isTexture&&(n.sheenColorMap=this.sheenColorMap.toJSON(e).uuid),this.sheenRoughnessMap&&this.sheenRoughnessMap.isTexture&&(n.sheenRoughnessMap=this.sheenRoughnessMap.toJSON(e).uuid),this.dispersion!==void 0&&(n.dispersion=this.dispersion),this.iridescence!==void 0&&(n.iridescence=this.iridescence),this.iridescenceIOR!==void 0&&(n.iridescenceIOR=this.iridescenceIOR),this.iridescenceThicknessRange!==void 0&&(n.iridescenceThicknessRange=this.iridescenceThicknessRange),this.iridescenceMap&&this.iridescenceMap.isTexture&&(n.iridescenceMap=this.iridescenceMap.toJSON(e).uuid),this.iridescenceThicknessMap&&this.iridescenceThicknessMap.isTexture&&(n.iridescenceThicknessMap=this.iridescenceThicknessMap.toJSON(e).uuid),this.anisotropy!==void 0&&(n.anisotropy=this.anisotropy),this.anisotropyRotation!==void 0&&(n.anisotropyRotation=this.anisotropyRotation),this.anisotropyMap&&this.anisotropyMap.isTexture&&(n.anisotropyMap=this.anisotropyMap.toJSON(e).uuid),this.map&&this.map.isTexture&&(n.map=this.map.toJSON(e).uuid),this.matcap&&this.matcap.isTexture&&(n.matcap=this.matcap.toJSON(e).uuid),this.alphaMap&&this.alphaMap.isTexture&&(n.alphaMap=this.alphaMap.toJSON(e).uuid),this.lightMap&&this.lightMap.isTexture&&(n.lightMap=this.lightMap.toJSON(e).uuid,n.lightMapIntensity=this.lightMapIntensity),this.aoMap&&this.aoMap.isTexture&&(n.aoMap=this.aoMap.toJSON(e).uuid,n.aoMapIntensity=this.aoMapIntensity),this.bumpMap&&this.bumpMap.isTexture&&(n.bumpMap=this.bumpMap.toJSON(e).uuid,n.bumpScale=this.bumpScale),this.normalMap&&this.normalMap.isTexture&&(n.normalMap=this.normalMap.toJSON(e).uuid,n.normalMapType=this.normalMapType,n.normalScale=this.normalScale.toArray()),this.displacementMap&&this.displacementMap.isTexture&&(n.displacementMap=this.displacementMap.toJSON(e).uuid,n.displacementScale=this.displacementScale,n.displacementBias=this.displacementBias),this.roughnessMap&&this.roughnessMap.isTexture&&(n.roughnessMap=this.roughnessMap.toJSON(e).uuid),this.metalnessMap&&this.metalnessMap.isTexture&&(n.metalnessMap=this.metalnessMap.toJSON(e).uuid),this.emissiveMap&&this.emissiveMap.isTexture&&(n.emissiveMap=this.emissiveMap.toJSON(e).uuid),this.specularMap&&this.specularMap.isTexture&&(n.specularMap=this.specularMap.toJSON(e).uuid),this.specularIntensityMap&&this.specularIntensityMap.isTexture&&(n.specularIntensityMap=this.specularIntensityMap.toJSON(e).uuid),this.specularColorMap&&this.specularColorMap.isTexture&&(n.specularColorMap=this.specularColorMap.toJSON(e).uuid),this.envMap&&this.envMap.isTexture&&(n.envMap=this.envMap.toJSON(e).uuid,this.combine!==void 0&&(n.combine=this.combine)),this.envMapRotation!==void 0&&(n.envMapRotation=this.envMapRotation.toArray()),this.envMapIntensity!==void 0&&(n.envMapIntensity=this.envMapIntensity),this.reflectivity!==void 0&&(n.reflectivity=this.reflectivity),this.refractionRatio!==void 0&&(n.refractionRatio=this.refractionRatio),this.gradientMap&&this.gradientMap.isTexture&&(n.gradientMap=this.gradientMap.toJSON(e).uuid),this.transmission!==void 0&&(n.transmission=this.transmission),this.transmissionMap&&this.transmissionMap.isTexture&&(n.transmissionMap=this.transmissionMap.toJSON(e).uuid),this.thickness!==void 0&&(n.thickness=this.thickness),this.thicknessMap&&this.thicknessMap.isTexture&&(n.thicknessMap=this.thicknessMap.toJSON(e).uuid),this.attenuationDistance!==void 0&&this.attenuationDistance!==1/0&&(n.attenuationDistance=this.attenuationDistance),this.attenuationColor!==void 0&&(n.attenuationColor=this.attenuationColor.getHex()),this.size!==void 0&&(n.size=this.size),this.shadowSide!==null&&(n.shadowSide=this.shadowSide),this.sizeAttenuation!==void 0&&(n.sizeAttenuation=this.sizeAttenuation),this.blending!==ps&&(n.blending=this.blending),this.side!==Si&&(n.side=this.side),this.vertexColors===!0&&(n.vertexColors=!0),this.opacity<1&&(n.opacity=this.opacity),this.transparent===!0&&(n.transparent=!0),this.blendSrc!==Qo&&(n.blendSrc=this.blendSrc),this.blendDst!==ea&&(n.blendDst=this.blendDst),this.blendEquation!==Xi&&(n.blendEquation=this.blendEquation),this.blendSrcAlpha!==null&&(n.blendSrcAlpha=this.blendSrcAlpha),this.blendDstAlpha!==null&&(n.blendDstAlpha=this.blendDstAlpha),this.blendEquationAlpha!==null&&(n.blendEquationAlpha=this.blendEquationAlpha),this.blendColor&&this.blendColor.isColor&&(n.blendColor=this.blendColor.getHex()),this.blendAlpha!==0&&(n.blendAlpha=this.blendAlpha),this.depthFunc!==ms&&(n.depthFunc=this.depthFunc),this.depthTest===!1&&(n.depthTest=this.depthTest),this.depthWrite===!1&&(n.depthWrite=this.depthWrite),this.colorWrite===!1&&(n.colorWrite=this.colorWrite),this.stencilWriteMask!==255&&(n.stencilWriteMask=this.stencilWriteMask),this.stencilFunc!==Dc&&(n.stencilFunc=this.stencilFunc),this.stencilRef!==0&&(n.stencilRef=this.stencilRef),this.stencilFuncMask!==255&&(n.stencilFuncMask=this.stencilFuncMask),this.stencilFail!==ds&&(n.stencilFail=this.stencilFail),this.stencilZFail!==ds&&(n.stencilZFail=this.stencilZFail),this.stencilZPass!==ds&&(n.stencilZPass=this.stencilZPass),this.stencilWrite===!0&&(n.stencilWrite=this.stencilWrite),this.rotation!==void 0&&this.rotation!==0&&(n.rotation=this.rotation),this.polygonOffset===!0&&(n.polygonOffset=!0),this.polygonOffsetFactor!==0&&(n.polygonOffsetFactor=this.polygonOffsetFactor),this.polygonOffsetUnits!==0&&(n.polygonOffsetUnits=this.polygonOffsetUnits),this.linewidth!==void 0&&this.linewidth!==1&&(n.linewidth=this.linewidth),this.dashSize!==void 0&&(n.dashSize=this.dashSize),this.gapSize!==void 0&&(n.gapSize=this.gapSize),this.scale!==void 0&&(n.scale=this.scale),this.dithering===!0&&(n.dithering=!0),this.alphaTest>0&&(n.alphaTest=this.alphaTest),this.alphaHash===!0&&(n.alphaHash=!0),this.alphaToCoverage===!0&&(n.alphaToCoverage=!0),this.premultipliedAlpha===!0&&(n.premultipliedAlpha=!0),this.forceSinglePass===!0&&(n.forceSinglePass=!0),this.wireframe===!0&&(n.wireframe=!0),this.wireframeLinewidth>1&&(n.wireframeLinewidth=this.wireframeLinewidth),this.wireframeLinecap!=="round"&&(n.wireframeLinecap=this.wireframeLinecap),this.wireframeLinejoin!=="round"&&(n.wireframeLinejoin=this.wireframeLinejoin),this.flatShading===!0&&(n.flatShading=!0),this.visible===!1&&(n.visible=!1),this.toneMapped===!1&&(n.toneMapped=!1),this.fog===!1&&(n.fog=!1),Object.keys(this.userData).length>0&&(n.userData=this.userData);function i(s){let o=[];for(let a in s){let l=s[a];delete l.metadata,o.push(l)}return o}if(t){let s=i(e.textures),o=i(e.images);s.length>0&&(n.textures=s),o.length>0&&(n.images=o)}return n}clone(){return new this.constructor().copy(this)}copy(e){this.name=e.name,this.blending=e.blending,this.side=e.side,this.vertexColors=e.vertexColors,this.opacity=e.opacity,this.transparent=e.transparent,this.blendSrc=e.blendSrc,this.blendDst=e.blendDst,this.blendEquation=e.blendEquation,this.blendSrcAlpha=e.blendSrcAlpha,this.blendDstAlpha=e.blendDstAlpha,this.blendEquationAlpha=e.blendEquationAlpha,this.blendColor.copy(e.blendColor),this.blendAlpha=e.blendAlpha,this.depthFunc=e.depthFunc,this.depthTest=e.depthTest,this.depthWrite=e.depthWrite,this.stencilWriteMask=e.stencilWriteMask,this.stencilFunc=e.stencilFunc,this.stencilRef=e.stencilRef,this.stencilFuncMask=e.stencilFuncMask,this.stencilFail=e.stencilFail,this.stencilZFail=e.stencilZFail,this.stencilZPass=e.stencilZPass,this.stencilWrite=e.stencilWrite;let t=e.clippingPlanes,n=null;if(t!==null){let i=t.length;n=new Array(i);for(let s=0;s!==i;++s)n[s]=t[s].clone()}return this.clippingPlanes=n,this.clipIntersection=e.clipIntersection,this.clipShadows=e.clipShadows,this.shadowSide=e.shadowSide,this.colorWrite=e.colorWrite,this.precision=e.precision,this.polygonOffset=e.polygonOffset,this.polygonOffsetFactor=e.polygonOffsetFactor,this.polygonOffsetUnits=e.polygonOffsetUnits,this.dithering=e.dithering,this.alphaTest=e.alphaTest,this.alphaHash=e.alphaHash,this.alphaToCoverage=e.alphaToCoverage,this.premultipliedAlpha=e.premultipliedAlpha,this.forceSinglePass=e.forceSinglePass,this.visible=e.visible,this.toneMapped=e.toneMapped,this.userData=JSON.parse(JSON.stringify(e.userData)),this}dispose(){this.dispatchEvent({type:"dispose"})}set needsUpdate(e){e===!0&&this.version++}},xs=class extends Ei{constructor(e){super(),this.isMeshBasicMaterial=!0,this.type="MeshBasicMaterial",this.color=new ot(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Zn,this.combine=qc,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.lightMap=e.lightMap,this.lightMapIntensity=e.lightMapIntensity,this.aoMap=e.aoMap,this.aoMapIntensity=e.aoMapIntensity,this.specularMap=e.specularMap,this.alphaMap=e.alphaMap,this.envMap=e.envMap,this.envMapRotation.copy(e.envMapRotation),this.combine=e.combine,this.reflectivity=e.reflectivity,this.refractionRatio=e.refractionRatio,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.wireframeLinecap=e.wireframeLinecap,this.wireframeLinejoin=e.wireframeLinejoin,this.fog=e.fog,this}};var Rt=new G,ko=new et,mp=0,Mn=class{constructor(e,t,n=!1){if(Array.isArray(e))throw new TypeError("THREE.BufferAttribute: array should be a Typed Array.");this.isBufferAttribute=!0,Object.defineProperty(this,"id",{value:mp++}),this.name="",this.array=e,this.itemSize=t,this.count=e!==void 0?e.length/t:0,this.normalized=n,this.usage=Fc,this.updateRanges=[],this.gpuType=ci,this.version=0}onUploadCallback(){}set needsUpdate(e){e===!0&&this.version++}setUsage(e){return this.usage=e,this}addUpdateRange(e,t){this.updateRanges.push({start:e,count:t})}clearUpdateRanges(){this.updateRanges.length=0}copy(e){return this.name=e.name,this.array=new e.array.constructor(e.array),this.itemSize=e.itemSize,this.count=e.count,this.normalized=e.normalized,this.usage=e.usage,this.gpuType=e.gpuType,this}copyAt(e,t,n){e*=this.itemSize,n*=t.itemSize;for(let i=0,s=this.itemSize;i<s;i++)this.array[e+i]=t.array[n+i];return this}copyArray(e){return this.array.set(e),this}applyMatrix3(e){if(this.itemSize===2)for(let t=0,n=this.count;t<n;t++)ko.fromBufferAttribute(this,t),ko.applyMatrix3(e),this.setXY(t,ko.x,ko.y);else if(this.itemSize===3)for(let t=0,n=this.count;t<n;t++)Rt.fromBufferAttribute(this,t),Rt.applyMatrix3(e),this.setXYZ(t,Rt.x,Rt.y,Rt.z);return this}applyMatrix4(e){for(let t=0,n=this.count;t<n;t++)Rt.fromBufferAttribute(this,t),Rt.applyMatrix4(e),this.setXYZ(t,Rt.x,Rt.y,Rt.z);return this}applyNormalMatrix(e){for(let t=0,n=this.count;t<n;t++)Rt.fromBufferAttribute(this,t),Rt.applyNormalMatrix(e),this.setXYZ(t,Rt.x,Rt.y,Rt.z);return this}transformDirection(e){for(let t=0,n=this.count;t<n;t++)Rt.fromBufferAttribute(this,t),Rt.transformDirection(e),this.setXYZ(t,Rt.x,Rt.y,Rt.z);return this}set(e,t=0){return this.array.set(e,t),this}getComponent(e,t){let n=this.array[e*this.itemSize+t];return this.normalized&&(n=Ar(n,this.array)),n}setComponent(e,t,n){return this.normalized&&(n=hn(n,this.array)),this.array[e*this.itemSize+t]=n,this}getX(e){let t=this.array[e*this.itemSize];return this.normalized&&(t=Ar(t,this.array)),t}setX(e,t){return this.normalized&&(t=hn(t,this.array)),this.array[e*this.itemSize]=t,this}getY(e){let t=this.array[e*this.itemSize+1];return this.normalized&&(t=Ar(t,this.array)),t}setY(e,t){return this.normalized&&(t=hn(t,this.array)),this.array[e*this.itemSize+1]=t,this}getZ(e){let t=this.array[e*this.itemSize+2];return this.normalized&&(t=Ar(t,this.array)),t}setZ(e,t){return this.normalized&&(t=hn(t,this.array)),this.array[e*this.itemSize+2]=t,this}getW(e){let t=this.array[e*this.itemSize+3];return this.normalized&&(t=Ar(t,this.array)),t}setW(e,t){return this.normalized&&(t=hn(t,this.array)),this.array[e*this.itemSize+3]=t,this}setXY(e,t,n){return e*=this.itemSize,this.normalized&&(t=hn(t,this.array),n=hn(n,this.array)),this.array[e+0]=t,this.array[e+1]=n,this}setXYZ(e,t,n,i){return e*=this.itemSize,this.normalized&&(t=hn(t,this.array),n=hn(n,this.array),i=hn(i,this.array)),this.array[e+0]=t,this.array[e+1]=n,this.array[e+2]=i,this}setXYZW(e,t,n,i,s){return e*=this.itemSize,this.normalized&&(t=hn(t,this.array),n=hn(n,this.array),i=hn(i,this.array),s=hn(s,this.array)),this.array[e+0]=t,this.array[e+1]=n,this.array[e+2]=i,this.array[e+3]=s,this}onUpload(e){return this.onUploadCallback=e,this}clone(){return new this.constructor(this.array,this.itemSize).copy(this)}toJSON(){let e={itemSize:this.itemSize,type:this.array.constructor.name,array:Array.from(this.array),normalized:this.normalized};return this.name!==""&&(e.name=this.name),this.usage!==Fc&&(e.usage=this.usage),e}};var Ur=class extends Mn{constructor(e,t,n){super(new Uint16Array(e),t,n)}};var Or=class extends Mn{constructor(e,t,n){super(new Uint32Array(e),t,n)}};var pt=class extends Mn{constructor(e,t,n){super(new Float32Array(e),t,n)}},gp=0,Ln=new Mt,Ac=new Xt,Ws=new G,_n=new $i,Pr=new $i,zt=new G,Lt=class r extends bi{constructor(){super(),this.isBufferGeometry=!0,Object.defineProperty(this,"id",{value:gp++}),this.uuid=lo(),this.name="",this.type="BufferGeometry",this.index=null,this.indirect=null,this.attributes={},this.morphAttributes={},this.morphTargetsRelative=!1,this.groups=[],this.boundingBox=null,this.boundingSphere=null,this.drawRange={start:0,count:1/0},this.userData={}}getIndex(){return this.index}setIndex(e){return Array.isArray(e)?this.index=new(sh(e)?Or:Ur)(e,1):this.index=e,this}setIndirect(e){return this.indirect=e,this}getIndirect(){return this.indirect}getAttribute(e){return this.attributes[e]}setAttribute(e,t){return this.attributes[e]=t,this}deleteAttribute(e){return delete this.attributes[e],this}hasAttribute(e){return this.attributes[e]!==void 0}addGroup(e,t,n=0){this.groups.push({start:e,count:t,materialIndex:n})}clearGroups(){this.groups=[]}setDrawRange(e,t){this.drawRange.start=e,this.drawRange.count=t}applyMatrix4(e){let t=this.attributes.position;t!==void 0&&(t.applyMatrix4(e),t.needsUpdate=!0);let n=this.attributes.normal;if(n!==void 0){let s=new tt().getNormalMatrix(e);n.applyNormalMatrix(s),n.needsUpdate=!0}let i=this.attributes.tangent;return i!==void 0&&(i.transformDirection(e),i.needsUpdate=!0),this.boundingBox!==null&&this.computeBoundingBox(),this.boundingSphere!==null&&this.computeBoundingSphere(),this}applyQuaternion(e){return Ln.makeRotationFromQuaternion(e),this.applyMatrix4(Ln),this}rotateX(e){return Ln.makeRotationX(e),this.applyMatrix4(Ln),this}rotateY(e){return Ln.makeRotationY(e),this.applyMatrix4(Ln),this}rotateZ(e){return Ln.makeRotationZ(e),this.applyMatrix4(Ln),this}translate(e,t,n){return Ln.makeTranslation(e,t,n),this.applyMatrix4(Ln),this}scale(e,t,n){return Ln.makeScale(e,t,n),this.applyMatrix4(Ln),this}lookAt(e){return Ac.lookAt(e),Ac.updateMatrix(),this.applyMatrix4(Ac.matrix),this}center(){return this.computeBoundingBox(),this.boundingBox.getCenter(Ws).negate(),this.translate(Ws.x,Ws.y,Ws.z),this}setFromPoints(e){let t=this.getAttribute("position");if(t===void 0){let n=[];for(let i=0,s=e.length;i<s;i++){let o=e[i];n.push(o.x,o.y,o.z||0)}this.setAttribute("position",new pt(n,3))}else{let n=Math.min(e.length,t.count);for(let i=0;i<n;i++){let s=e[i];t.setXYZ(i,s.x,s.y,s.z||0)}e.length>t.count&&console.warn("THREE.BufferGeometry: Buffer size too small for points data. Use .dispose() and create a new geometry."),t.needsUpdate=!0}return this}computeBoundingBox(){this.boundingBox===null&&(this.boundingBox=new $i);let e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",this),this.boundingBox.set(new G(-1/0,-1/0,-1/0),new G(1/0,1/0,1/0));return}if(e!==void 0){if(this.boundingBox.setFromBufferAttribute(e),t)for(let n=0,i=t.length;n<i;n++){let s=t[n];_n.setFromBufferAttribute(s),this.morphTargetsRelative?(zt.addVectors(this.boundingBox.min,_n.min),this.boundingBox.expandByPoint(zt),zt.addVectors(this.boundingBox.max,_n.max),this.boundingBox.expandByPoint(zt)):(this.boundingBox.expandByPoint(_n.min),this.boundingBox.expandByPoint(_n.max))}}else this.boundingBox.makeEmpty();(isNaN(this.boundingBox.min.x)||isNaN(this.boundingBox.min.y)||isNaN(this.boundingBox.min.z))&&console.error('THREE.BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',this)}computeBoundingSphere(){this.boundingSphere===null&&(this.boundingSphere=new vs);let e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",this),this.boundingSphere.set(new G,1/0);return}if(e){let n=this.boundingSphere.center;if(_n.setFromBufferAttribute(e),t)for(let s=0,o=t.length;s<o;s++){let a=t[s];Pr.setFromBufferAttribute(a),this.morphTargetsRelative?(zt.addVectors(_n.min,Pr.min),_n.expandByPoint(zt),zt.addVectors(_n.max,Pr.max),_n.expandByPoint(zt)):(_n.expandByPoint(Pr.min),_n.expandByPoint(Pr.max))}_n.getCenter(n);let i=0;for(let s=0,o=e.count;s<o;s++)zt.fromBufferAttribute(e,s),i=Math.max(i,n.distanceToSquared(zt));if(t)for(let s=0,o=t.length;s<o;s++){let a=t[s],l=this.morphTargetsRelative;for(let h=0,f=a.count;h<f;h++)zt.fromBufferAttribute(a,h),l&&(Ws.fromBufferAttribute(e,h),zt.add(Ws)),i=Math.max(i,n.distanceToSquared(zt))}this.boundingSphere.radius=Math.sqrt(i),isNaN(this.boundingSphere.radius)&&console.error('THREE.BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',this)}}computeTangents(){let e=this.index,t=this.attributes;if(e===null||t.position===void 0||t.normal===void 0||t.uv===void 0){console.error("THREE.BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)");return}let n=t.position,i=t.normal,s=t.uv;this.hasAttribute("tangent")===!1&&this.setAttribute("tangent",new Mn(new Float32Array(4*n.count),4));let o=this.getAttribute("tangent"),a=[],l=[];for(let A=0;A<n.count;A++)a[A]=new G,l[A]=new G;let h=new G,f=new G,c=new G,u=new et,d=new et,p=new et,v=new G,g=new G;function m(A,b,w){h.fromBufferAttribute(n,A),f.fromBufferAttribute(n,b),c.fromBufferAttribute(n,w),u.fromBufferAttribute(s,A),d.fromBufferAttribute(s,b),p.fromBufferAttribute(s,w),f.sub(h),c.sub(h),d.sub(u),p.sub(u);let T=1/(d.x*p.y-p.x*d.y);isFinite(T)&&(v.copy(f).multiplyScalar(p.y).addScaledVector(c,-d.y).multiplyScalar(T),g.copy(c).multiplyScalar(d.x).addScaledVector(f,-p.x).multiplyScalar(T),a[A].add(v),a[b].add(v),a[w].add(v),l[A].add(g),l[b].add(g),l[w].add(g))}let _=this.groups;_.length===0&&(_=[{start:0,count:e.count}]);for(let A=0,b=_.length;A<b;++A){let w=_[A],T=w.start,F=w.count;for(let D=T,C=T+F;D<C;D+=3)m(e.getX(D+0),e.getX(D+1),e.getX(D+2))}let x=new G,y=new G,S=new G,M=new G;function E(A){S.fromBufferAttribute(i,A),M.copy(S);let b=a[A];x.copy(b),x.sub(S.multiplyScalar(S.dot(b))).normalize(),y.crossVectors(M,b);let T=y.dot(l[A])<0?-1:1;o.setXYZW(A,x.x,x.y,x.z,T)}for(let A=0,b=_.length;A<b;++A){let w=_[A],T=w.start,F=w.count;for(let D=T,C=T+F;D<C;D+=3)E(e.getX(D+0)),E(e.getX(D+1)),E(e.getX(D+2))}}computeVertexNormals(){let e=this.index,t=this.getAttribute("position");if(t!==void 0){let n=this.getAttribute("normal");if(n===void 0)n=new Mn(new Float32Array(t.count*3),3),this.setAttribute("normal",n);else for(let u=0,d=n.count;u<d;u++)n.setXYZ(u,0,0,0);let i=new G,s=new G,o=new G,a=new G,l=new G,h=new G,f=new G,c=new G;if(e)for(let u=0,d=e.count;u<d;u+=3){let p=e.getX(u+0),v=e.getX(u+1),g=e.getX(u+2);i.fromBufferAttribute(t,p),s.fromBufferAttribute(t,v),o.fromBufferAttribute(t,g),f.subVectors(o,s),c.subVectors(i,s),f.cross(c),a.fromBufferAttribute(n,p),l.fromBufferAttribute(n,v),h.fromBufferAttribute(n,g),a.add(f),l.add(f),h.add(f),n.setXYZ(p,a.x,a.y,a.z),n.setXYZ(v,l.x,l.y,l.z),n.setXYZ(g,h.x,h.y,h.z)}else for(let u=0,d=t.count;u<d;u+=3)i.fromBufferAttribute(t,u+0),s.fromBufferAttribute(t,u+1),o.fromBufferAttribute(t,u+2),f.subVectors(o,s),c.subVectors(i,s),f.cross(c),n.setXYZ(u+0,f.x,f.y,f.z),n.setXYZ(u+1,f.x,f.y,f.z),n.setXYZ(u+2,f.x,f.y,f.z);this.normalizeNormals(),n.needsUpdate=!0}}normalizeNormals(){let e=this.attributes.normal;for(let t=0,n=e.count;t<n;t++)zt.fromBufferAttribute(e,t),zt.normalize(),e.setXYZ(t,zt.x,zt.y,zt.z)}toNonIndexed(){function e(a,l){let h=a.array,f=a.itemSize,c=a.normalized,u=new h.constructor(l.length*f),d=0,p=0;for(let v=0,g=l.length;v<g;v++){a.isInterleavedBufferAttribute?d=l[v]*a.data.stride+a.offset:d=l[v]*f;for(let m=0;m<f;m++)u[p++]=h[d++]}return new Mn(u,f,c)}if(this.index===null)return console.warn("THREE.BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed."),this;let t=new r,n=this.index.array,i=this.attributes;for(let a in i){let l=i[a],h=e(l,n);t.setAttribute(a,h)}let s=this.morphAttributes;for(let a in s){let l=[],h=s[a];for(let f=0,c=h.length;f<c;f++){let u=h[f],d=e(u,n);l.push(d)}t.morphAttributes[a]=l}t.morphTargetsRelative=this.morphTargetsRelative;let o=this.groups;for(let a=0,l=o.length;a<l;a++){let h=o[a];t.addGroup(h.start,h.count,h.materialIndex)}return t}toJSON(){let e={metadata:{version:4.7,type:"BufferGeometry",generator:"BufferGeometry.toJSON"}};if(e.uuid=this.uuid,e.type=this.type,this.name!==""&&(e.name=this.name),Object.keys(this.userData).length>0&&(e.userData=this.userData),this.parameters!==void 0){let l=this.parameters;for(let h in l)l[h]!==void 0&&(e[h]=l[h]);return e}e.data={attributes:{}};let t=this.index;t!==null&&(e.data.index={type:t.array.constructor.name,array:Array.prototype.slice.call(t.array)});let n=this.attributes;for(let l in n){let h=n[l];e.data.attributes[l]=h.toJSON(e.data)}let i={},s=!1;for(let l in this.morphAttributes){let h=this.morphAttributes[l],f=[];for(let c=0,u=h.length;c<u;c++){let d=h[c];f.push(d.toJSON(e.data))}f.length>0&&(i[l]=f,s=!0)}s&&(e.data.morphAttributes=i,e.data.morphTargetsRelative=this.morphTargetsRelative);let o=this.groups;o.length>0&&(e.data.groups=JSON.parse(JSON.stringify(o)));let a=this.boundingSphere;return a!==null&&(e.data.boundingSphere=a.toJSON()),e}clone(){return new this.constructor().copy(this)}copy(e){this.index=null,this.attributes={},this.morphAttributes={},this.groups=[],this.boundingBox=null,this.boundingSphere=null;let t={};this.name=e.name;let n=e.index;n!==null&&this.setIndex(n.clone());let i=e.attributes;for(let h in i){let f=i[h];this.setAttribute(h,f.clone(t))}let s=e.morphAttributes;for(let h in s){let f=[],c=s[h];for(let u=0,d=c.length;u<d;u++)f.push(c[u].clone(t));this.morphAttributes[h]=f}this.morphTargetsRelative=e.morphTargetsRelative;let o=e.groups;for(let h=0,f=o.length;h<f;h++){let c=o[h];this.addGroup(c.start,c.count,c.materialIndex)}let a=e.boundingBox;a!==null&&(this.boundingBox=a.clone());let l=e.boundingSphere;return l!==null&&(this.boundingSphere=l.clone()),this.drawRange.start=e.drawRange.start,this.drawRange.count=e.drawRange.count,this.userData=e.userData,this}dispose(){this.dispatchEvent({type:"dispose"})}},Su=new Mt,us=new js,Vo=new vs,bu=new G,Ho=new G,Go=new G,Wo=new G,Tc=new G,qo=new G,wu=new G,Xo=new G,fn=class extends Xt{constructor(e=new Lt,t=new xs){super(),this.isMesh=!0,this.type="Mesh",this.geometry=e,this.material=t,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.count=1,this.updateMorphTargets()}copy(e,t){return super.copy(e,t),e.morphTargetInfluences!==void 0&&(this.morphTargetInfluences=e.morphTargetInfluences.slice()),e.morphTargetDictionary!==void 0&&(this.morphTargetDictionary=Object.assign({},e.morphTargetDictionary)),this.material=Array.isArray(e.material)?e.material.slice():e.material,this.geometry=e.geometry,this}updateMorphTargets(){let t=this.geometry.morphAttributes,n=Object.keys(t);if(n.length>0){let i=t[n[0]];if(i!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let s=0,o=i.length;s<o;s++){let a=i[s].name||String(s);this.morphTargetInfluences.push(0),this.morphTargetDictionary[a]=s}}}}getVertexPosition(e,t){let n=this.geometry,i=n.attributes.position,s=n.morphAttributes.position,o=n.morphTargetsRelative;t.fromBufferAttribute(i,e);let a=this.morphTargetInfluences;if(s&&a){qo.set(0,0,0);for(let l=0,h=s.length;l<h;l++){let f=a[l],c=s[l];f!==0&&(Tc.fromBufferAttribute(c,e),o?qo.addScaledVector(Tc,f):qo.addScaledVector(Tc.sub(t),f))}t.add(qo)}return t}raycast(e,t){let n=this.geometry,i=this.material,s=this.matrixWorld;i!==void 0&&(n.boundingSphere===null&&n.computeBoundingSphere(),Vo.copy(n.boundingSphere),Vo.applyMatrix4(s),us.copy(e.ray).recast(e.near),!(Vo.containsPoint(us.origin)===!1&&(us.intersectSphere(Vo,bu)===null||us.origin.distanceToSquared(bu)>(e.far-e.near)**2))&&(Su.copy(s).invert(),us.copy(e.ray).applyMatrix4(Su),!(n.boundingBox!==null&&us.intersectsBox(n.boundingBox)===!1)&&this._computeIntersections(e,t,us)))}_computeIntersections(e,t,n){let i,s=this.geometry,o=this.material,a=s.index,l=s.attributes.position,h=s.attributes.uv,f=s.attributes.uv1,c=s.attributes.normal,u=s.groups,d=s.drawRange;if(a!==null)if(Array.isArray(o))for(let p=0,v=u.length;p<v;p++){let g=u[p],m=o[g.materialIndex],_=Math.max(g.start,d.start),x=Math.min(a.count,Math.min(g.start+g.count,d.start+d.count));for(let y=_,S=x;y<S;y+=3){let M=a.getX(y),E=a.getX(y+1),A=a.getX(y+2);i=$o(this,m,e,n,h,f,c,M,E,A),i&&(i.faceIndex=Math.floor(y/3),i.face.materialIndex=g.materialIndex,t.push(i))}}else{let p=Math.max(0,d.start),v=Math.min(a.count,d.start+d.count);for(let g=p,m=v;g<m;g+=3){let _=a.getX(g),x=a.getX(g+1),y=a.getX(g+2);i=$o(this,o,e,n,h,f,c,_,x,y),i&&(i.faceIndex=Math.floor(g/3),t.push(i))}}else if(l!==void 0)if(Array.isArray(o))for(let p=0,v=u.length;p<v;p++){let g=u[p],m=o[g.materialIndex],_=Math.max(g.start,d.start),x=Math.min(l.count,Math.min(g.start+g.count,d.start+d.count));for(let y=_,S=x;y<S;y+=3){let M=y,E=y+1,A=y+2;i=$o(this,m,e,n,h,f,c,M,E,A),i&&(i.faceIndex=Math.floor(y/3),i.face.materialIndex=g.materialIndex,t.push(i))}}else{let p=Math.max(0,d.start),v=Math.min(l.count,d.start+d.count);for(let g=p,m=v;g<m;g+=3){let _=g,x=g+1,y=g+2;i=$o(this,o,e,n,h,f,c,_,x,y),i&&(i.faceIndex=Math.floor(g/3),t.push(i))}}}};function vp(r,e,t,n,i,s,o,a){let l;if(e.side===on?l=n.intersectTriangle(o,s,i,!0,a):l=n.intersectTriangle(i,s,o,e.side===Si,a),l===null)return null;Xo.copy(a),Xo.applyMatrix4(r.matrixWorld);let h=t.ray.origin.distanceTo(Xo);return h<t.near||h>t.far?null:{distance:h,point:Xo.clone(),object:r}}function $o(r,e,t,n,i,s,o,a,l,h){r.getVertexPosition(a,Ho),r.getVertexPosition(l,Go),r.getVertexPosition(h,Wo);let f=vp(r,e,t,n,Ho,Go,Wo,wu);if(f){let c=new G;Wi.getBarycoord(wu,Ho,Go,Wo,c),i&&(f.uv=Wi.getInterpolatedAttribute(i,a,l,h,c,new et)),s&&(f.uv1=Wi.getInterpolatedAttribute(s,a,l,h,c,new et)),o&&(f.normal=Wi.getInterpolatedAttribute(o,a,l,h,c,new G),f.normal.dot(n.direction)>0&&f.normal.multiplyScalar(-1));let u={a,b:l,c:h,normal:new G,materialIndex:0};Wi.getNormal(Ho,Go,Wo,u.normal),f.face=u,f.barycoord=c}return f}var Yi=class r extends Lt{constructor(e=1,t=1,n=1,i=1,s=1,o=1){super(),this.type="BoxGeometry",this.parameters={width:e,height:t,depth:n,widthSegments:i,heightSegments:s,depthSegments:o};let a=this;i=Math.floor(i),s=Math.floor(s),o=Math.floor(o);let l=[],h=[],f=[],c=[],u=0,d=0;p("z","y","x",-1,-1,n,t,e,o,s,0),p("z","y","x",1,-1,n,t,-e,o,s,1),p("x","z","y",1,1,e,n,t,i,o,2),p("x","z","y",1,-1,e,n,-t,i,o,3),p("x","y","z",1,-1,e,t,n,i,s,4),p("x","y","z",-1,-1,e,t,-n,i,s,5),this.setIndex(l),this.setAttribute("position",new pt(h,3)),this.setAttribute("normal",new pt(f,3)),this.setAttribute("uv",new pt(c,2));function p(v,g,m,_,x,y,S,M,E,A,b){let w=y/E,T=S/A,F=y/2,D=S/2,C=M/2,P=E+1,N=A+1,z=0,O=0,K=new G;for(let ee=0;ee<N;ee++){let oe=ee*T-D;for(let ae=0;ae<P;ae++){let Ge=ae*w-F;K[v]=Ge*_,K[g]=oe*x,K[m]=C,h.push(K.x,K.y,K.z),K[v]=0,K[g]=0,K[m]=M>0?1:-1,f.push(K.x,K.y,K.z),c.push(ae/E),c.push(1-ee/A),z+=1}}for(let ee=0;ee<A;ee++)for(let oe=0;oe<E;oe++){let ae=u+oe+P*ee,Ge=u+oe+P*(ee+1),Ce=u+(oe+1)+P*(ee+1),We=u+(oe+1)+P*ee;l.push(ae,Ge,We),l.push(Ge,Ce,We),O+=6}a.addGroup(d,O,b),d+=O,u+=z}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new r(e.width,e.height,e.depth,e.widthSegments,e.heightSegments,e.depthSegments)}};function bs(r){let e={};for(let t in r){e[t]={};for(let n in r[t]){let i=r[t][n];i&&(i.isColor||i.isMatrix3||i.isMatrix4||i.isVector2||i.isVector3||i.isVector4||i.isTexture||i.isQuaternion)?i.isRenderTargetTexture?(console.warn("UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms()."),e[t][n]=null):e[t][n]=i.clone():Array.isArray(i)?e[t][n]=i.slice():e[t][n]=i}}return e}function en(r){let e={};for(let t=0;t<r.length;t++){let n=bs(r[t]);for(let i in n)e[i]=n[i]}return e}function xp(r){let e=[];for(let t=0;t<r.length;t++)e.push(r[t].clone());return e}function rh(r){let e=r.getRenderTarget();return e===null?r.outputColorSpace:e.isXRRenderTarget===!0?e.texture.colorSpace:lt.workingColorSpace}var Sf={clone:bs,merge:en},yp=`void main() {
	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}`,_p=`void main() {
	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
}`,Kn=class extends Ei{constructor(e){super(),this.isShaderMaterial=!0,this.type="ShaderMaterial",this.defines={},this.uniforms={},this.uniformsGroups=[],this.vertexShader=yp,this.fragmentShader=_p,this.linewidth=1,this.wireframe=!1,this.wireframeLinewidth=1,this.fog=!1,this.lights=!1,this.clipping=!1,this.forceSinglePass=!0,this.extensions={clipCullDistance:!1,multiDraw:!1},this.defaultAttributeValues={color:[1,1,1],uv:[0,0],uv1:[0,0]},this.index0AttributeName=void 0,this.uniformsNeedUpdate=!1,this.glslVersion=null,e!==void 0&&this.setValues(e)}copy(e){return super.copy(e),this.fragmentShader=e.fragmentShader,this.vertexShader=e.vertexShader,this.uniforms=bs(e.uniforms),this.uniformsGroups=xp(e.uniformsGroups),this.defines=Object.assign({},e.defines),this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.fog=e.fog,this.lights=e.lights,this.clipping=e.clipping,this.extensions=Object.assign({},e.extensions),this.glslVersion=e.glslVersion,this}toJSON(e){let t=super.toJSON(e);t.glslVersion=this.glslVersion,t.uniforms={};for(let i in this.uniforms){let o=this.uniforms[i].value;o&&o.isTexture?t.uniforms[i]={type:"t",value:o.toJSON(e).uuid}:o&&o.isColor?t.uniforms[i]={type:"c",value:o.getHex()}:o&&o.isVector2?t.uniforms[i]={type:"v2",value:o.toArray()}:o&&o.isVector3?t.uniforms[i]={type:"v3",value:o.toArray()}:o&&o.isVector4?t.uniforms[i]={type:"v4",value:o.toArray()}:o&&o.isMatrix3?t.uniforms[i]={type:"m3",value:o.toArray()}:o&&o.isMatrix4?t.uniforms[i]={type:"m4",value:o.toArray()}:t.uniforms[i]={value:o}}Object.keys(this.defines).length>0&&(t.defines=this.defines),t.vertexShader=this.vertexShader,t.fragmentShader=this.fragmentShader,t.lights=this.lights,t.clipping=this.clipping;let n={};for(let i in this.extensions)this.extensions[i]===!0&&(n[i]=!0);return Object.keys(n).length>0&&(t.extensions=n),t}},zr=class extends Xt{constructor(){super(),this.isCamera=!0,this.type="Camera",this.matrixWorldInverse=new Mt,this.projectionMatrix=new Mt,this.projectionMatrixInverse=new Mt,this.coordinateSystem=Xn,this._reversedDepth=!1}get reversedDepth(){return this._reversedDepth}copy(e,t){return super.copy(e,t),this.matrixWorldInverse.copy(e.matrixWorldInverse),this.projectionMatrix.copy(e.projectionMatrix),this.projectionMatrixInverse.copy(e.projectionMatrixInverse),this.coordinateSystem=e.coordinateSystem,this}getWorldDirection(e){return super.getWorldDirection(e).negate()}updateMatrixWorld(e){super.updateMatrixWorld(e),this.matrixWorldInverse.copy(this.matrixWorld).invert()}updateWorldMatrix(e,t){super.updateWorldMatrix(e,t),this.matrixWorldInverse.copy(this.matrixWorld).invert()}clone(){return new this.constructor().copy(this)}},Gi=new G,Eu=new et,Au=new et,Qt=class extends zr{constructor(e=50,t=1,n=.1,i=2e3){super(),this.isPerspectiveCamera=!0,this.type="PerspectiveCamera",this.fov=e,this.zoom=1,this.near=n,this.far=i,this.focus=10,this.aspect=t,this.view=null,this.filmGauge=35,this.filmOffset=0,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.fov=e.fov,this.zoom=e.zoom,this.near=e.near,this.far=e.far,this.focus=e.focus,this.aspect=e.aspect,this.view=e.view===null?null:Object.assign({},e.view),this.filmGauge=e.filmGauge,this.filmOffset=e.filmOffset,this}setFocalLength(e){let t=.5*this.getFilmHeight()/e;this.fov=ia*2*Math.atan(t),this.updateProjectionMatrix()}getFocalLength(){let e=Math.tan(oc*.5*this.fov);return .5*this.getFilmHeight()/e}getEffectiveFOV(){return ia*2*Math.atan(Math.tan(oc*.5*this.fov)/this.zoom)}getFilmWidth(){return this.filmGauge*Math.min(this.aspect,1)}getFilmHeight(){return this.filmGauge/Math.max(this.aspect,1)}getViewBounds(e,t,n){Gi.set(-1,-1,.5).applyMatrix4(this.projectionMatrixInverse),t.set(Gi.x,Gi.y).multiplyScalar(-e/Gi.z),Gi.set(1,1,.5).applyMatrix4(this.projectionMatrixInverse),n.set(Gi.x,Gi.y).multiplyScalar(-e/Gi.z)}getViewSize(e,t){return this.getViewBounds(e,Eu,Au),t.subVectors(Au,Eu)}setViewOffset(e,t,n,i,s,o){this.aspect=e/t,this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=n,this.view.offsetY=i,this.view.width=s,this.view.height=o,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let e=this.near,t=e*Math.tan(oc*.5*this.fov)/this.zoom,n=2*t,i=this.aspect*n,s=-.5*i,o=this.view;if(this.view!==null&&this.view.enabled){let l=o.fullWidth,h=o.fullHeight;s+=o.offsetX*i/l,t-=o.offsetY*n/h,i*=o.width/l,n*=o.height/h}let a=this.filmOffset;a!==0&&(s+=e*a/this.getFilmWidth()),this.projectionMatrix.makePerspective(s,s+i,t,t-n,e,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){let t=super.toJSON(e);return t.object.fov=this.fov,t.object.zoom=this.zoom,t.object.near=this.near,t.object.far=this.far,t.object.focus=this.focus,t.object.aspect=this.aspect,this.view!==null&&(t.object.view=Object.assign({},this.view)),t.object.filmGauge=this.filmGauge,t.object.filmOffset=this.filmOffset,t}},qs=-90,Xs=1,aa=class extends Xt{constructor(e,t,n){super(),this.type="CubeCamera",this.renderTarget=n,this.coordinateSystem=null,this.activeMipmapLevel=0;let i=new Qt(qs,Xs,e,t);i.layers=this.layers,this.add(i);let s=new Qt(qs,Xs,e,t);s.layers=this.layers,this.add(s);let o=new Qt(qs,Xs,e,t);o.layers=this.layers,this.add(o);let a=new Qt(qs,Xs,e,t);a.layers=this.layers,this.add(a);let l=new Qt(qs,Xs,e,t);l.layers=this.layers,this.add(l);let h=new Qt(qs,Xs,e,t);h.layers=this.layers,this.add(h)}updateCoordinateSystem(){let e=this.coordinateSystem,t=this.children.concat(),[n,i,s,o,a,l]=t;for(let h of t)this.remove(h);if(e===Xn)n.up.set(0,1,0),n.lookAt(1,0,0),i.up.set(0,1,0),i.lookAt(-1,0,0),s.up.set(0,0,-1),s.lookAt(0,1,0),o.up.set(0,0,1),o.lookAt(0,-1,0),a.up.set(0,1,0),a.lookAt(0,0,1),l.up.set(0,1,0),l.lookAt(0,0,-1);else if(e===Dr)n.up.set(0,-1,0),n.lookAt(-1,0,0),i.up.set(0,-1,0),i.lookAt(1,0,0),s.up.set(0,0,1),s.lookAt(0,1,0),o.up.set(0,0,-1),o.lookAt(0,-1,0),a.up.set(0,-1,0),a.lookAt(0,0,1),l.up.set(0,-1,0),l.lookAt(0,0,-1);else throw new Error("THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: "+e);for(let h of t)this.add(h),h.updateMatrixWorld()}update(e,t){this.parent===null&&this.updateMatrixWorld();let{renderTarget:n,activeMipmapLevel:i}=this;this.coordinateSystem!==e.coordinateSystem&&(this.coordinateSystem=e.coordinateSystem,this.updateCoordinateSystem());let[s,o,a,l,h,f]=this.children,c=e.getRenderTarget(),u=e.getActiveCubeFace(),d=e.getActiveMipmapLevel(),p=e.xr.enabled;e.xr.enabled=!1;let v=n.texture.generateMipmaps;n.texture.generateMipmaps=!1,e.setRenderTarget(n,0,i),e.render(t,s),e.setRenderTarget(n,1,i),e.render(t,o),e.setRenderTarget(n,2,i),e.render(t,a),e.setRenderTarget(n,3,i),e.render(t,l),e.setRenderTarget(n,4,i),e.render(t,h),n.texture.generateMipmaps=v,e.setRenderTarget(n,5,i),e.render(t,f),e.setRenderTarget(c,u,d),e.xr.enabled=p,n.texture.needsPMREMUpdate=!0}},kr=class extends un{constructor(e=[],t=Ms,n,i,s,o,a,l,h,f){super(e,t,n,i,s,o,a,l,h,f),this.isCubeTexture=!0,this.flipY=!1}get images(){return this.image}set images(e){this.image=e}},la=class extends oi{constructor(e=1,t={}){super(e,e,t),this.isWebGLCubeRenderTarget=!0;let n={width:e,height:e,depth:1},i=[n,n,n,n,n,n];this.texture=new kr(i),this._setTextureOptions(t),this.texture.isRenderTargetTexture=!0}fromEquirectangularTexture(e,t){this.texture.type=t.type,this.texture.colorSpace=t.colorSpace,this.texture.generateMipmaps=t.generateMipmaps,this.texture.minFilter=t.minFilter,this.texture.magFilter=t.magFilter;let n={uniforms:{tEquirect:{value:null}},vertexShader:`

				varying vec3 vWorldDirection;

				vec3 transformDirection( in vec3 dir, in mat4 matrix ) {

					return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );

				}

				void main() {

					vWorldDirection = transformDirection( position, modelMatrix );

					#include <begin_vertex>
					#include <project_vertex>

				}
			`,fragmentShader:`

				uniform sampler2D tEquirect;

				varying vec3 vWorldDirection;

				#include <common>

				void main() {

					vec3 direction = normalize( vWorldDirection );

					vec2 sampleUV = equirectUv( direction );

					gl_FragColor = texture2D( tEquirect, sampleUV );

				}
			`},i=new Yi(5,5,5),s=new Kn({name:"CubemapFromEquirect",uniforms:bs(n.uniforms),vertexShader:n.vertexShader,fragmentShader:n.fragmentShader,side:on,blending:Ai});s.uniforms.tEquirect.value=t;let o=new fn(i,s),a=t.minFilter;return t.minFilter===ji&&(t.minFilter=Yn),new aa(1,10,this).update(e,o),t.minFilter=a,o.geometry.dispose(),o.material.dispose(),this}clear(e,t=!0,n=!0,i=!0){let s=e.getRenderTarget();for(let o=0;o<6;o++)e.setRenderTarget(this,o),e.clear(t,n,i);e.setRenderTarget(s)}},$n=class extends Xt{constructor(){super(),this.isGroup=!0,this.type="Group"}},Mp={type:"move"},er=class{constructor(){this._targetRay=null,this._grip=null,this._hand=null}getHandSpace(){return this._hand===null&&(this._hand=new $n,this._hand.matrixAutoUpdate=!1,this._hand.visible=!1,this._hand.joints={},this._hand.inputState={pinching:!1}),this._hand}getTargetRaySpace(){return this._targetRay===null&&(this._targetRay=new $n,this._targetRay.matrixAutoUpdate=!1,this._targetRay.visible=!1,this._targetRay.hasLinearVelocity=!1,this._targetRay.linearVelocity=new G,this._targetRay.hasAngularVelocity=!1,this._targetRay.angularVelocity=new G),this._targetRay}getGripSpace(){return this._grip===null&&(this._grip=new $n,this._grip.matrixAutoUpdate=!1,this._grip.visible=!1,this._grip.hasLinearVelocity=!1,this._grip.linearVelocity=new G,this._grip.hasAngularVelocity=!1,this._grip.angularVelocity=new G),this._grip}dispatchEvent(e){return this._targetRay!==null&&this._targetRay.dispatchEvent(e),this._grip!==null&&this._grip.dispatchEvent(e),this._hand!==null&&this._hand.dispatchEvent(e),this}connect(e){if(e&&e.hand){let t=this._hand;if(t)for(let n of e.hand.values())this._getHandJoint(t,n)}return this.dispatchEvent({type:"connected",data:e}),this}disconnect(e){return this.dispatchEvent({type:"disconnected",data:e}),this._targetRay!==null&&(this._targetRay.visible=!1),this._grip!==null&&(this._grip.visible=!1),this._hand!==null&&(this._hand.visible=!1),this}update(e,t,n){let i=null,s=null,o=null,a=this._targetRay,l=this._grip,h=this._hand;if(e&&t.session.visibilityState!=="visible-blurred"){if(h&&e.hand){o=!0;for(let v of e.hand.values()){let g=t.getJointPose(v,n),m=this._getHandJoint(h,v);g!==null&&(m.matrix.fromArray(g.transform.matrix),m.matrix.decompose(m.position,m.rotation,m.scale),m.matrixWorldNeedsUpdate=!0,m.jointRadius=g.radius),m.visible=g!==null}let f=h.joints["index-finger-tip"],c=h.joints["thumb-tip"],u=f.position.distanceTo(c.position),d=.02,p=.005;h.inputState.pinching&&u>d+p?(h.inputState.pinching=!1,this.dispatchEvent({type:"pinchend",handedness:e.handedness,target:this})):!h.inputState.pinching&&u<=d-p&&(h.inputState.pinching=!0,this.dispatchEvent({type:"pinchstart",handedness:e.handedness,target:this}))}else l!==null&&e.gripSpace&&(s=t.getPose(e.gripSpace,n),s!==null&&(l.matrix.fromArray(s.transform.matrix),l.matrix.decompose(l.position,l.rotation,l.scale),l.matrixWorldNeedsUpdate=!0,s.linearVelocity?(l.hasLinearVelocity=!0,l.linearVelocity.copy(s.linearVelocity)):l.hasLinearVelocity=!1,s.angularVelocity?(l.hasAngularVelocity=!0,l.angularVelocity.copy(s.angularVelocity)):l.hasAngularVelocity=!1));a!==null&&(i=t.getPose(e.targetRaySpace,n),i===null&&s!==null&&(i=s),i!==null&&(a.matrix.fromArray(i.transform.matrix),a.matrix.decompose(a.position,a.rotation,a.scale),a.matrixWorldNeedsUpdate=!0,i.linearVelocity?(a.hasLinearVelocity=!0,a.linearVelocity.copy(i.linearVelocity)):a.hasLinearVelocity=!1,i.angularVelocity?(a.hasAngularVelocity=!0,a.angularVelocity.copy(i.angularVelocity)):a.hasAngularVelocity=!1,this.dispatchEvent(Mp)))}return a!==null&&(a.visible=i!==null),l!==null&&(l.visible=s!==null),h!==null&&(h.visible=o!==null),this}_getHandJoint(e,t){if(e.joints[t.jointName]===void 0){let n=new $n;n.matrixAutoUpdate=!1,n.visible=!1,e.joints[t.jointName]=n,e.add(n)}return e.joints[t.jointName]}};var Vr=class extends Xt{constructor(){super(),this.isScene=!0,this.type="Scene",this.background=null,this.environment=null,this.fog=null,this.backgroundBlurriness=0,this.backgroundIntensity=1,this.backgroundRotation=new Zn,this.environmentIntensity=1,this.environmentRotation=new Zn,this.overrideMaterial=null,typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}copy(e,t){return super.copy(e,t),e.background!==null&&(this.background=e.background.clone()),e.environment!==null&&(this.environment=e.environment.clone()),e.fog!==null&&(this.fog=e.fog.clone()),this.backgroundBlurriness=e.backgroundBlurriness,this.backgroundIntensity=e.backgroundIntensity,this.backgroundRotation.copy(e.backgroundRotation),this.environmentIntensity=e.environmentIntensity,this.environmentRotation.copy(e.environmentRotation),e.overrideMaterial!==null&&(this.overrideMaterial=e.overrideMaterial.clone()),this.matrixAutoUpdate=e.matrixAutoUpdate,this}toJSON(e){let t=super.toJSON(e);return this.fog!==null&&(t.object.fog=this.fog.toJSON()),this.backgroundBlurriness>0&&(t.object.backgroundBlurriness=this.backgroundBlurriness),this.backgroundIntensity!==1&&(t.object.backgroundIntensity=this.backgroundIntensity),t.object.backgroundRotation=this.backgroundRotation.toArray(),this.environmentIntensity!==1&&(t.object.environmentIntensity=this.environmentIntensity),t.object.environmentRotation=this.environmentRotation.toArray(),t}};var Cc=new G,Sp=new G,bp=new tt,Dn=class{constructor(e=new G(1,0,0),t=0){this.isPlane=!0,this.normal=e,this.constant=t}set(e,t){return this.normal.copy(e),this.constant=t,this}setComponents(e,t,n,i){return this.normal.set(e,t,n),this.constant=i,this}setFromNormalAndCoplanarPoint(e,t){return this.normal.copy(e),this.constant=-t.dot(this.normal),this}setFromCoplanarPoints(e,t,n){let i=Cc.subVectors(n,t).cross(Sp.subVectors(e,t)).normalize();return this.setFromNormalAndCoplanarPoint(i,e),this}copy(e){return this.normal.copy(e.normal),this.constant=e.constant,this}normalize(){let e=1/this.normal.length();return this.normal.multiplyScalar(e),this.constant*=e,this}negate(){return this.constant*=-1,this.normal.negate(),this}distanceToPoint(e){return this.normal.dot(e)+this.constant}distanceToSphere(e){return this.distanceToPoint(e.center)-e.radius}projectPoint(e,t){return t.copy(e).addScaledVector(this.normal,-this.distanceToPoint(e))}intersectLine(e,t){let n=e.delta(Cc),i=this.normal.dot(n);if(i===0)return this.distanceToPoint(e.start)===0?t.copy(e.start):null;let s=-(e.start.dot(this.normal)+this.constant)/i;return s<0||s>1?null:t.copy(e.start).addScaledVector(n,s)}intersectsLine(e){let t=this.distanceToPoint(e.start),n=this.distanceToPoint(e.end);return t<0&&n>0||n<0&&t>0}intersectsBox(e){return e.intersectsPlane(this)}intersectsSphere(e){return e.intersectsPlane(this)}coplanarPoint(e){return e.copy(this.normal).multiplyScalar(-this.constant)}applyMatrix4(e,t){let n=t||bp.getNormalMatrix(e),i=this.coplanarPoint(Cc).applyMatrix4(e),s=this.normal.applyMatrix3(n).normalize();return this.constant=-i.dot(s),this}translate(e){return this.constant-=e.dot(this.normal),this}equals(e){return e.normal.equals(this.normal)&&e.constant===this.constant}clone(){return new this.constructor().copy(this)}},fs=new vs,wp=new et(.5,.5),Yo=new G,tr=class{constructor(e=new Dn,t=new Dn,n=new Dn,i=new Dn,s=new Dn,o=new Dn){this.planes=[e,t,n,i,s,o]}set(e,t,n,i,s,o){let a=this.planes;return a[0].copy(e),a[1].copy(t),a[2].copy(n),a[3].copy(i),a[4].copy(s),a[5].copy(o),this}copy(e){let t=this.planes;for(let n=0;n<6;n++)t[n].copy(e.planes[n]);return this}setFromProjectionMatrix(e,t=Xn,n=!1){let i=this.planes,s=e.elements,o=s[0],a=s[1],l=s[2],h=s[3],f=s[4],c=s[5],u=s[6],d=s[7],p=s[8],v=s[9],g=s[10],m=s[11],_=s[12],x=s[13],y=s[14],S=s[15];if(i[0].setComponents(h-o,d-f,m-p,S-_).normalize(),i[1].setComponents(h+o,d+f,m+p,S+_).normalize(),i[2].setComponents(h+a,d+c,m+v,S+x).normalize(),i[3].setComponents(h-a,d-c,m-v,S-x).normalize(),n)i[4].setComponents(l,u,g,y).normalize(),i[5].setComponents(h-l,d-u,m-g,S-y).normalize();else if(i[4].setComponents(h-l,d-u,m-g,S-y).normalize(),t===Xn)i[5].setComponents(h+l,d+u,m+g,S+y).normalize();else if(t===Dr)i[5].setComponents(l,u,g,y).normalize();else throw new Error("THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: "+t);return this}intersectsObject(e){if(e.boundingSphere!==void 0)e.boundingSphere===null&&e.computeBoundingSphere(),fs.copy(e.boundingSphere).applyMatrix4(e.matrixWorld);else{let t=e.geometry;t.boundingSphere===null&&t.computeBoundingSphere(),fs.copy(t.boundingSphere).applyMatrix4(e.matrixWorld)}return this.intersectsSphere(fs)}intersectsSprite(e){fs.center.set(0,0,0);let t=wp.distanceTo(e.center);return fs.radius=.7071067811865476+t,fs.applyMatrix4(e.matrixWorld),this.intersectsSphere(fs)}intersectsSphere(e){let t=this.planes,n=e.center,i=-e.radius;for(let s=0;s<6;s++)if(t[s].distanceToPoint(n)<i)return!1;return!0}intersectsBox(e){let t=this.planes;for(let n=0;n<6;n++){let i=t[n];if(Yo.x=i.normal.x>0?e.max.x:e.min.x,Yo.y=i.normal.y>0?e.max.y:e.min.y,Yo.z=i.normal.z>0?e.max.z:e.min.z,i.distanceToPoint(Yo)<0)return!1}return!0}containsPoint(e){let t=this.planes;for(let n=0;n<6;n++)if(t[n].distanceToPoint(e)<0)return!1;return!0}clone(){return new this.constructor().copy(this)}};var Hr=class extends Ei{constructor(e){super(),this.isLineBasicMaterial=!0,this.type="LineBasicMaterial",this.color=new ot(16777215),this.map=null,this.linewidth=1,this.linecap="round",this.linejoin="round",this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.linewidth=e.linewidth,this.linecap=e.linecap,this.linejoin=e.linejoin,this.fog=e.fog,this}},ca=new G,ha=new G,Tu=new Mt,Ir=new js,Zo=new vs,Rc=new G,Cu=new G,Gr=class extends Xt{constructor(e=new Lt,t=new Hr){super(),this.isLine=!0,this.type="Line",this.geometry=e,this.material=t,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.updateMorphTargets()}copy(e,t){return super.copy(e,t),this.material=Array.isArray(e.material)?e.material.slice():e.material,this.geometry=e.geometry,this}computeLineDistances(){let e=this.geometry;if(e.index===null){let t=e.attributes.position,n=[0];for(let i=1,s=t.count;i<s;i++)ca.fromBufferAttribute(t,i-1),ha.fromBufferAttribute(t,i),n[i]=n[i-1],n[i]+=ca.distanceTo(ha);e.setAttribute("lineDistance",new pt(n,1))}else console.warn("THREE.Line.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.");return this}raycast(e,t){let n=this.geometry,i=this.matrixWorld,s=e.params.Line.threshold,o=n.drawRange;if(n.boundingSphere===null&&n.computeBoundingSphere(),Zo.copy(n.boundingSphere),Zo.applyMatrix4(i),Zo.radius+=s,e.ray.intersectsSphere(Zo)===!1)return;Tu.copy(i).invert(),Ir.copy(e.ray).applyMatrix4(Tu);let a=s/((this.scale.x+this.scale.y+this.scale.z)/3),l=a*a,h=this.isLineSegments?2:1,f=n.index,u=n.attributes.position;if(f!==null){let d=Math.max(0,o.start),p=Math.min(f.count,o.start+o.count);for(let v=d,g=p-1;v<g;v+=h){let m=f.getX(v),_=f.getX(v+1),x=Ko(this,e,Ir,l,m,_,v);x&&t.push(x)}if(this.isLineLoop){let v=f.getX(p-1),g=f.getX(d),m=Ko(this,e,Ir,l,v,g,p-1);m&&t.push(m)}}else{let d=Math.max(0,o.start),p=Math.min(u.count,o.start+o.count);for(let v=d,g=p-1;v<g;v+=h){let m=Ko(this,e,Ir,l,v,v+1,v);m&&t.push(m)}if(this.isLineLoop){let v=Ko(this,e,Ir,l,p-1,d,p-1);v&&t.push(v)}}}updateMorphTargets(){let t=this.geometry.morphAttributes,n=Object.keys(t);if(n.length>0){let i=t[n[0]];if(i!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let s=0,o=i.length;s<o;s++){let a=i[s].name||String(s);this.morphTargetInfluences.push(0),this.morphTargetDictionary[a]=s}}}}};function Ko(r,e,t,n,i,s,o){let a=r.geometry.attributes.position;if(ca.fromBufferAttribute(a,i),ha.fromBufferAttribute(a,s),t.distanceSqToSegment(ca,ha,Rc,Cu)>n)return;Rc.applyMatrix4(r.matrixWorld);let h=e.ray.origin.distanceTo(Rc);if(!(h<e.near||h>e.far))return{distance:h,point:Cu.clone().applyMatrix4(r.matrixWorld),index:o,face:null,faceIndex:null,barycoord:null,object:r}}var Wr=class extends un{constructor(e,t,n,i,s,o,a,l,h){super(e,t,n,i,s,o,a,l,h),this.isCanvasTexture=!0,this.needsUpdate=!0}},qr=class extends un{constructor(e,t,n=Qi,i,s,o,a=Fn,l=Fn,h,f=Zs,c=1){if(f!==Zs&&f!==cr)throw new Error("DepthTexture format must be either THREE.DepthFormat or THREE.DepthStencilFormat");let u={width:e,height:t,depth:c};super(u,i,s,o,a,l,f,n,h),this.isDepthTexture=!0,this.flipY=!1,this.generateMipmaps=!1,this.compareFunction=null}copy(e){return super.copy(e),this.source=new Js(Object.assign({},e.image)),this.compareFunction=e.compareFunction,this}toJSON(e){let t=super.toJSON(e);return this.compareFunction!==null&&(t.compareFunction=this.compareFunction),t}},Xr=class extends un{constructor(e=null){super(),this.sourceTexture=e,this.isExternalTexture=!0}copy(e){return super.copy(e),this.sourceTexture=e.sourceTexture,this}};var $r=class r extends Lt{constructor(e=1,t=32,n=0,i=Math.PI*2){super(),this.type="CircleGeometry",this.parameters={radius:e,segments:t,thetaStart:n,thetaLength:i},t=Math.max(3,t);let s=[],o=[],a=[],l=[],h=new G,f=new et;o.push(0,0,0),a.push(0,0,1),l.push(.5,.5);for(let c=0,u=3;c<=t;c++,u+=3){let d=n+c/t*i;h.x=e*Math.cos(d),h.y=e*Math.sin(d),o.push(h.x,h.y,h.z),a.push(0,0,1),f.x=(o[u]/e+1)/2,f.y=(o[u+1]/e+1)/2,l.push(f.x,f.y)}for(let c=1;c<=t;c++)s.push(c,c+1,0);this.setIndex(s),this.setAttribute("position",new pt(o,3)),this.setAttribute("normal",new pt(a,3)),this.setAttribute("uv",new pt(l,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new r(e.radius,e.segments,e.thetaStart,e.thetaLength)}},ai=class r extends Lt{constructor(e=1,t=1,n=1,i=32,s=1,o=!1,a=0,l=Math.PI*2){super(),this.type="CylinderGeometry",this.parameters={radiusTop:e,radiusBottom:t,height:n,radialSegments:i,heightSegments:s,openEnded:o,thetaStart:a,thetaLength:l};let h=this;i=Math.floor(i),s=Math.floor(s);let f=[],c=[],u=[],d=[],p=0,v=[],g=n/2,m=0;_(),o===!1&&(e>0&&x(!0),t>0&&x(!1)),this.setIndex(f),this.setAttribute("position",new pt(c,3)),this.setAttribute("normal",new pt(u,3)),this.setAttribute("uv",new pt(d,2));function _(){let y=new G,S=new G,M=0,E=(t-e)/n;for(let A=0;A<=s;A++){let b=[],w=A/s,T=w*(t-e)+e;for(let F=0;F<=i;F++){let D=F/i,C=D*l+a,P=Math.sin(C),N=Math.cos(C);S.x=T*P,S.y=-w*n+g,S.z=T*N,c.push(S.x,S.y,S.z),y.set(P,E,N).normalize(),u.push(y.x,y.y,y.z),d.push(D,1-w),b.push(p++)}v.push(b)}for(let A=0;A<i;A++)for(let b=0;b<s;b++){let w=v[b][A],T=v[b+1][A],F=v[b+1][A+1],D=v[b][A+1];(e>0||b!==0)&&(f.push(w,T,D),M+=3),(t>0||b!==s-1)&&(f.push(T,F,D),M+=3)}h.addGroup(m,M,0),m+=M}function x(y){let S=p,M=new et,E=new G,A=0,b=y===!0?e:t,w=y===!0?1:-1;for(let F=1;F<=i;F++)c.push(0,g*w,0),u.push(0,w,0),d.push(.5,.5),p++;let T=p;for(let F=0;F<=i;F++){let C=F/i*l+a,P=Math.cos(C),N=Math.sin(C);E.x=b*N,E.y=g*w,E.z=b*P,c.push(E.x,E.y,E.z),u.push(0,w,0),M.x=P*.5+.5,M.y=N*.5*w+.5,d.push(M.x,M.y),p++}for(let F=0;F<i;F++){let D=S+F,C=T+F;y===!0?f.push(C,C+1,D):f.push(C+1,C,D),A+=3}h.addGroup(m,A,y===!0?1:2),m+=A}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new r(e.radiusTop,e.radiusBottom,e.height,e.radialSegments,e.heightSegments,e.openEnded,e.thetaStart,e.thetaLength)}},Yr=class r extends ai{constructor(e=1,t=1,n=32,i=1,s=!1,o=0,a=Math.PI*2){super(0,e,t,n,i,s,o,a),this.type="ConeGeometry",this.parameters={radius:e,height:t,radialSegments:n,heightSegments:i,openEnded:s,thetaStart:o,thetaLength:a}}static fromJSON(e){return new r(e.radius,e.height,e.radialSegments,e.heightSegments,e.openEnded,e.thetaStart,e.thetaLength)}};var nr=class r extends Lt{constructor(e=[new et(0,-.5),new et(.5,0),new et(0,.5)],t=12,n=0,i=Math.PI*2){super(),this.type="LatheGeometry",this.parameters={points:e,segments:t,phiStart:n,phiLength:i},t=Math.floor(t),i=at(i,0,Math.PI*2);let s=[],o=[],a=[],l=[],h=[],f=1/t,c=new G,u=new et,d=new G,p=new G,v=new G,g=0,m=0;for(let _=0;_<=e.length-1;_++)switch(_){case 0:g=e[_+1].x-e[_].x,m=e[_+1].y-e[_].y,d.x=m*1,d.y=-g,d.z=m*0,v.copy(d),d.normalize(),l.push(d.x,d.y,d.z);break;case e.length-1:l.push(v.x,v.y,v.z);break;default:g=e[_+1].x-e[_].x,m=e[_+1].y-e[_].y,d.x=m*1,d.y=-g,d.z=m*0,p.copy(d),d.x+=v.x,d.y+=v.y,d.z+=v.z,d.normalize(),l.push(d.x,d.y,d.z),v.copy(p)}for(let _=0;_<=t;_++){let x=n+_*f*i,y=Math.sin(x),S=Math.cos(x);for(let M=0;M<=e.length-1;M++){c.x=e[M].x*y,c.y=e[M].y,c.z=e[M].x*S,o.push(c.x,c.y,c.z),u.x=_/t,u.y=M/(e.length-1),a.push(u.x,u.y);let E=l[3*M+0]*y,A=l[3*M+1],b=l[3*M+0]*S;h.push(E,A,b)}}for(let _=0;_<t;_++)for(let x=0;x<e.length-1;x++){let y=x+_*e.length,S=y,M=y+e.length,E=y+e.length+1,A=y+1;s.push(S,M,A),s.push(E,A,M)}this.setIndex(s),this.setAttribute("position",new pt(o,3)),this.setAttribute("uv",new pt(a,2)),this.setAttribute("normal",new pt(h,3))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new r(e.points,e.segments,e.phiStart,e.phiLength)}};var ys=class r extends Lt{constructor(e=1,t=1,n=1,i=1){super(),this.type="PlaneGeometry",this.parameters={width:e,height:t,widthSegments:n,heightSegments:i};let s=e/2,o=t/2,a=Math.floor(n),l=Math.floor(i),h=a+1,f=l+1,c=e/a,u=t/l,d=[],p=[],v=[],g=[];for(let m=0;m<f;m++){let _=m*u-o;for(let x=0;x<h;x++){let y=x*c-s;p.push(y,-_,0),v.push(0,0,1),g.push(x/a),g.push(1-m/l)}}for(let m=0;m<l;m++)for(let _=0;_<a;_++){let x=_+h*m,y=_+h*(m+1),S=_+1+h*(m+1),M=_+1+h*m;d.push(x,y,M),d.push(y,S,M)}this.setIndex(d),this.setAttribute("position",new pt(p,3)),this.setAttribute("normal",new pt(v,3)),this.setAttribute("uv",new pt(g,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new r(e.width,e.height,e.widthSegments,e.heightSegments)}},Zr=class r extends Lt{constructor(e=.5,t=1,n=32,i=1,s=0,o=Math.PI*2){super(),this.type="RingGeometry",this.parameters={innerRadius:e,outerRadius:t,thetaSegments:n,phiSegments:i,thetaStart:s,thetaLength:o},n=Math.max(3,n),i=Math.max(1,i);let a=[],l=[],h=[],f=[],c=e,u=(t-e)/i,d=new G,p=new et;for(let v=0;v<=i;v++){for(let g=0;g<=n;g++){let m=s+g/n*o;d.x=c*Math.cos(m),d.y=c*Math.sin(m),l.push(d.x,d.y,d.z),h.push(0,0,1),p.x=(d.x/t+1)/2,p.y=(d.y/t+1)/2,f.push(p.x,p.y)}c+=u}for(let v=0;v<i;v++){let g=v*(n+1);for(let m=0;m<n;m++){let _=m+g,x=_,y=_+n+1,S=_+n+2,M=_+1;a.push(x,y,M),a.push(y,S,M)}}this.setIndex(a),this.setAttribute("position",new pt(l,3)),this.setAttribute("normal",new pt(h,3)),this.setAttribute("uv",new pt(f,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new r(e.innerRadius,e.outerRadius,e.thetaSegments,e.phiSegments,e.thetaStart,e.thetaLength)}};var Zi=class r extends Lt{constructor(e=1,t=32,n=16,i=0,s=Math.PI*2,o=0,a=Math.PI){super(),this.type="SphereGeometry",this.parameters={radius:e,widthSegments:t,heightSegments:n,phiStart:i,phiLength:s,thetaStart:o,thetaLength:a},t=Math.max(3,Math.floor(t)),n=Math.max(2,Math.floor(n));let l=Math.min(o+a,Math.PI),h=0,f=[],c=new G,u=new G,d=[],p=[],v=[],g=[];for(let m=0;m<=n;m++){let _=[],x=m/n,y=0;m===0&&o===0?y=.5/t:m===n&&l===Math.PI&&(y=-.5/t);for(let S=0;S<=t;S++){let M=S/t;c.x=-e*Math.cos(i+M*s)*Math.sin(o+x*a),c.y=e*Math.cos(o+x*a),c.z=e*Math.sin(i+M*s)*Math.sin(o+x*a),p.push(c.x,c.y,c.z),u.copy(c).normalize(),v.push(u.x,u.y,u.z),g.push(M+y,1-x),_.push(h++)}f.push(_)}for(let m=0;m<n;m++)for(let _=0;_<t;_++){let x=f[m][_+1],y=f[m][_],S=f[m+1][_],M=f[m+1][_+1];(m!==0||o>0)&&d.push(x,y,M),(m!==n-1||l<Math.PI)&&d.push(y,S,M)}this.setIndex(d),this.setAttribute("position",new pt(p,3)),this.setAttribute("normal",new pt(v,3)),this.setAttribute("uv",new pt(g,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new r(e.radius,e.widthSegments,e.heightSegments,e.phiStart,e.phiLength,e.thetaStart,e.thetaLength)}};var ir=class r extends Lt{constructor(e=1,t=.4,n=12,i=48,s=Math.PI*2){super(),this.type="TorusGeometry",this.parameters={radius:e,tube:t,radialSegments:n,tubularSegments:i,arc:s},n=Math.floor(n),i=Math.floor(i);let o=[],a=[],l=[],h=[],f=new G,c=new G,u=new G;for(let d=0;d<=n;d++)for(let p=0;p<=i;p++){let v=p/i*s,g=d/n*Math.PI*2;c.x=(e+t*Math.cos(g))*Math.cos(v),c.y=(e+t*Math.cos(g))*Math.sin(v),c.z=t*Math.sin(g),a.push(c.x,c.y,c.z),f.x=e*Math.cos(v),f.y=e*Math.sin(v),u.subVectors(c,f).normalize(),l.push(u.x,u.y,u.z),h.push(p/i),h.push(d/n)}for(let d=1;d<=n;d++)for(let p=1;p<=i;p++){let v=(i+1)*d+p-1,g=(i+1)*(d-1)+p-1,m=(i+1)*(d-1)+p,_=(i+1)*d+p;o.push(v,g,_),o.push(g,m,_)}this.setIndex(o),this.setAttribute("position",new pt(a,3)),this.setAttribute("normal",new pt(l,3)),this.setAttribute("uv",new pt(h,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new r(e.radius,e.tube,e.radialSegments,e.tubularSegments,e.arc)}};var sr=class extends Ei{constructor(e){super(),this.isMeshStandardMaterial=!0,this.type="MeshStandardMaterial",this.defines={STANDARD:""},this.color=new ot(16777215),this.roughness=1,this.metalness=0,this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.emissive=new ot(0),this.emissiveIntensity=1,this.emissiveMap=null,this.bumpMap=null,this.bumpScale=1,this.normalMap=null,this.normalMapType=th,this.normalScale=new et(1,1),this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.roughnessMap=null,this.metalnessMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Zn,this.envMapIntensity=1,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.flatShading=!1,this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.defines={STANDARD:""},this.color.copy(e.color),this.roughness=e.roughness,this.metalness=e.metalness,this.map=e.map,this.lightMap=e.lightMap,this.lightMapIntensity=e.lightMapIntensity,this.aoMap=e.aoMap,this.aoMapIntensity=e.aoMapIntensity,this.emissive.copy(e.emissive),this.emissiveMap=e.emissiveMap,this.emissiveIntensity=e.emissiveIntensity,this.bumpMap=e.bumpMap,this.bumpScale=e.bumpScale,this.normalMap=e.normalMap,this.normalMapType=e.normalMapType,this.normalScale.copy(e.normalScale),this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this.roughnessMap=e.roughnessMap,this.metalnessMap=e.metalnessMap,this.alphaMap=e.alphaMap,this.envMap=e.envMap,this.envMapRotation.copy(e.envMapRotation),this.envMapIntensity=e.envMapIntensity,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.wireframeLinecap=e.wireframeLinecap,this.wireframeLinejoin=e.wireframeLinejoin,this.flatShading=e.flatShading,this.fog=e.fog,this}};var ua=class extends Ei{constructor(e){super(),this.isMeshDepthMaterial=!0,this.type="MeshDepthMaterial",this.depthPacking=cf,this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.wireframe=!1,this.wireframeLinewidth=1,this.setValues(e)}copy(e){return super.copy(e),this.depthPacking=e.depthPacking,this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this}},fa=class extends Ei{constructor(e){super(),this.isMeshDistanceMaterial=!0,this.type="MeshDistanceMaterial",this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.setValues(e)}copy(e){return super.copy(e),this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this}};var Kr=class extends Hr{constructor(e){super(),this.isLineDashedMaterial=!0,this.type="LineDashedMaterial",this.scale=1,this.dashSize=3,this.gapSize=1,this.setValues(e)}copy(e){return super.copy(e),this.scale=e.scale,this.dashSize=e.dashSize,this.gapSize=e.gapSize,this}};function Jo(r,e){return!r||r.constructor===e?r:typeof e.BYTES_PER_ELEMENT=="number"?new e(r):Array.prototype.slice.call(r)}function Ep(r){return ArrayBuffer.isView(r)&&!(r instanceof DataView)}var _s=class{constructor(e,t,n,i){this.parameterPositions=e,this._cachedIndex=0,this.resultBuffer=i!==void 0?i:new t.constructor(n),this.sampleValues=t,this.valueSize=n,this.settings=null,this.DefaultSettings_={}}evaluate(e){let t=this.parameterPositions,n=this._cachedIndex,i=t[n],s=t[n-1];n:{e:{let o;t:{i:if(!(e<i)){for(let a=n+2;;){if(i===void 0){if(e<s)break i;return n=t.length,this._cachedIndex=n,this.copySampleValue_(n-1)}if(n===a)break;if(s=i,i=t[++n],e<i)break e}o=t.length;break t}if(!(e>=s)){let a=t[1];e<a&&(n=2,s=a);for(let l=n-2;;){if(s===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(n===l)break;if(i=s,s=t[--n-1],e>=s)break e}o=n,n=0;break t}break n}for(;n<o;){let a=n+o>>>1;e<t[a]?o=a:n=a+1}if(i=t[n],s=t[n-1],s===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(i===void 0)return n=t.length,this._cachedIndex=n,this.copySampleValue_(n-1)}this._cachedIndex=n,this.intervalChanged_(n,s,i)}return this.interpolate_(n,s,e,i)}getSettings_(){return this.settings||this.DefaultSettings_}copySampleValue_(e){let t=this.resultBuffer,n=this.sampleValues,i=this.valueSize,s=e*i;for(let o=0;o!==i;++o)t[o]=n[s+o];return t}interpolate_(){throw new Error("call to abstract method")}intervalChanged_(){}},da=class extends _s{constructor(e,t,n,i){super(e,t,n,i),this._weightPrev=-0,this._offsetPrev=-0,this._weightNext=-0,this._offsetNext=-0,this.DefaultSettings_={endingStart:Ic,endingEnd:Ic}}intervalChanged_(e,t,n){let i=this.parameterPositions,s=e-2,o=e+1,a=i[s],l=i[o];if(a===void 0)switch(this.getSettings_().endingStart){case Nc:s=e,a=2*t-n;break;case Lc:s=i.length-2,a=t+i[s]-i[s+1];break;default:s=e,a=n}if(l===void 0)switch(this.getSettings_().endingEnd){case Nc:o=e,l=2*n-t;break;case Lc:o=1,l=n+i[1]-i[0];break;default:o=e-1,l=t}let h=(n-t)*.5,f=this.valueSize;this._weightPrev=h/(t-a),this._weightNext=h/(l-n),this._offsetPrev=s*f,this._offsetNext=o*f}interpolate_(e,t,n,i){let s=this.resultBuffer,o=this.sampleValues,a=this.valueSize,l=e*a,h=l-a,f=this._offsetPrev,c=this._offsetNext,u=this._weightPrev,d=this._weightNext,p=(n-t)/(i-t),v=p*p,g=v*p,m=-u*g+2*u*v-u*p,_=(1+u)*g+(-1.5-2*u)*v+(-.5+u)*p+1,x=(-1-d)*g+(1.5+d)*v+.5*p,y=d*g-d*v;for(let S=0;S!==a;++S)s[S]=m*o[f+S]+_*o[h+S]+x*o[l+S]+y*o[c+S];return s}},pa=class extends _s{constructor(e,t,n,i){super(e,t,n,i)}interpolate_(e,t,n,i){let s=this.resultBuffer,o=this.sampleValues,a=this.valueSize,l=e*a,h=l-a,f=(n-t)/(i-t),c=1-f;for(let u=0;u!==a;++u)s[u]=o[h+u]*c+o[l+u]*f;return s}},ma=class extends _s{constructor(e,t,n,i){super(e,t,n,i)}interpolate_(e){return this.copySampleValue_(e-1)}},Sn=class{constructor(e,t,n,i){if(e===void 0)throw new Error("THREE.KeyframeTrack: track name is undefined");if(t===void 0||t.length===0)throw new Error("THREE.KeyframeTrack: no keyframes in track named "+e);this.name=e,this.times=Jo(t,this.TimeBufferType),this.values=Jo(n,this.ValueBufferType),this.setInterpolation(i||this.DefaultInterpolation)}static toJSON(e){let t=e.constructor,n;if(t.toJSON!==this.toJSON)n=t.toJSON(e);else{n={name:e.name,times:Jo(e.times,Array),values:Jo(e.values,Array)};let i=e.getInterpolation();i!==e.DefaultInterpolation&&(n.interpolation=i)}return n.type=e.ValueTypeName,n}InterpolantFactoryMethodDiscrete(e){return new ma(this.times,this.values,this.getValueSize(),e)}InterpolantFactoryMethodLinear(e){return new pa(this.times,this.values,this.getValueSize(),e)}InterpolantFactoryMethodSmooth(e){return new da(this.times,this.values,this.getValueSize(),e)}setInterpolation(e){let t;switch(e){case Nr:t=this.InterpolantFactoryMethodDiscrete;break;case na:t=this.InterpolantFactoryMethodLinear;break;case jo:t=this.InterpolantFactoryMethodSmooth;break}if(t===void 0){let n="unsupported interpolation for "+this.ValueTypeName+" keyframe track named "+this.name;if(this.createInterpolant===void 0)if(e!==this.DefaultInterpolation)this.setInterpolation(this.DefaultInterpolation);else throw new Error(n);return console.warn("THREE.KeyframeTrack:",n),this}return this.createInterpolant=t,this}getInterpolation(){switch(this.createInterpolant){case this.InterpolantFactoryMethodDiscrete:return Nr;case this.InterpolantFactoryMethodLinear:return na;case this.InterpolantFactoryMethodSmooth:return jo}}getValueSize(){return this.values.length/this.times.length}shift(e){if(e!==0){let t=this.times;for(let n=0,i=t.length;n!==i;++n)t[n]+=e}return this}scale(e){if(e!==1){let t=this.times;for(let n=0,i=t.length;n!==i;++n)t[n]*=e}return this}trim(e,t){let n=this.times,i=n.length,s=0,o=i-1;for(;s!==i&&n[s]<e;)++s;for(;o!==-1&&n[o]>t;)--o;if(++o,s!==0||o!==i){s>=o&&(o=Math.max(o,1),s=o-1);let a=this.getValueSize();this.times=n.slice(s,o),this.values=this.values.slice(s*a,o*a)}return this}validate(){let e=!0,t=this.getValueSize();t-Math.floor(t)!==0&&(console.error("THREE.KeyframeTrack: Invalid value size in track.",this),e=!1);let n=this.times,i=this.values,s=n.length;s===0&&(console.error("THREE.KeyframeTrack: Track is empty.",this),e=!1);let o=null;for(let a=0;a!==s;a++){let l=n[a];if(typeof l=="number"&&isNaN(l)){console.error("THREE.KeyframeTrack: Time is not a valid number.",this,a,l),e=!1;break}if(o!==null&&o>l){console.error("THREE.KeyframeTrack: Out of order keys.",this,a,l,o),e=!1;break}o=l}if(i!==void 0&&Ep(i))for(let a=0,l=i.length;a!==l;++a){let h=i[a];if(isNaN(h)){console.error("THREE.KeyframeTrack: Value is not a valid number.",this,a,h),e=!1;break}}return e}optimize(){let e=this.times.slice(),t=this.values.slice(),n=this.getValueSize(),i=this.getInterpolation()===jo,s=e.length-1,o=1;for(let a=1;a<s;++a){let l=!1,h=e[a],f=e[a+1];if(h!==f&&(a!==1||h!==e[0]))if(i)l=!0;else{let c=a*n,u=c-n,d=c+n;for(let p=0;p!==n;++p){let v=t[c+p];if(v!==t[u+p]||v!==t[d+p]){l=!0;break}}}if(l){if(a!==o){e[o]=e[a];let c=a*n,u=o*n;for(let d=0;d!==n;++d)t[u+d]=t[c+d]}++o}}if(s>0){e[o]=e[s];for(let a=s*n,l=o*n,h=0;h!==n;++h)t[l+h]=t[a+h];++o}return o!==e.length?(this.times=e.slice(0,o),this.values=t.slice(0,o*n)):(this.times=e,this.values=t),this}clone(){let e=this.times.slice(),t=this.values.slice(),n=this.constructor,i=new n(this.name,e,t);return i.createInterpolant=this.createInterpolant,i}};Sn.prototype.ValueTypeName="";Sn.prototype.TimeBufferType=Float32Array;Sn.prototype.ValueBufferType=Float32Array;Sn.prototype.DefaultInterpolation=na;var Ki=class extends Sn{constructor(e,t,n){super(e,t,n)}};Ki.prototype.ValueTypeName="bool";Ki.prototype.ValueBufferType=Array;Ki.prototype.DefaultInterpolation=Nr;Ki.prototype.InterpolantFactoryMethodLinear=void 0;Ki.prototype.InterpolantFactoryMethodSmooth=void 0;var ga=class extends Sn{constructor(e,t,n,i){super(e,t,n,i)}};ga.prototype.ValueTypeName="color";var va=class extends Sn{constructor(e,t,n,i){super(e,t,n,i)}};va.prototype.ValueTypeName="number";var xa=class extends _s{constructor(e,t,n,i){super(e,t,n,i)}interpolate_(e,t,n,i){let s=this.resultBuffer,o=this.sampleValues,a=this.valueSize,l=(n-t)/(i-t),h=e*a;for(let f=h+a;h!==f;h+=4)wi.slerpFlat(s,0,o,h-a,o,h,l);return s}},Jr=class extends Sn{constructor(e,t,n,i){super(e,t,n,i)}InterpolantFactoryMethodLinear(e){return new xa(this.times,this.values,this.getValueSize(),e)}};Jr.prototype.ValueTypeName="quaternion";Jr.prototype.InterpolantFactoryMethodSmooth=void 0;var Ji=class extends Sn{constructor(e,t,n){super(e,t,n)}};Ji.prototype.ValueTypeName="string";Ji.prototype.ValueBufferType=Array;Ji.prototype.DefaultInterpolation=Nr;Ji.prototype.InterpolantFactoryMethodLinear=void 0;Ji.prototype.InterpolantFactoryMethodSmooth=void 0;var ya=class extends Sn{constructor(e,t,n,i){super(e,t,n,i)}};ya.prototype.ValueTypeName="vector";var _a=class{constructor(e,t,n){let i=this,s=!1,o=0,a=0,l,h=[];this.onStart=void 0,this.onLoad=e,this.onProgress=t,this.onError=n,this.abortController=new AbortController,this.itemStart=function(f){a++,s===!1&&i.onStart!==void 0&&i.onStart(f,o,a),s=!0},this.itemEnd=function(f){o++,i.onProgress!==void 0&&i.onProgress(f,o,a),o===a&&(s=!1,i.onLoad!==void 0&&i.onLoad())},this.itemError=function(f){i.onError!==void 0&&i.onError(f)},this.resolveURL=function(f){return l?l(f):f},this.setURLModifier=function(f){return l=f,this},this.addHandler=function(f,c){return h.push(f,c),this},this.removeHandler=function(f){let c=h.indexOf(f);return c!==-1&&h.splice(c,2),this},this.getHandler=function(f){for(let c=0,u=h.length;c<u;c+=2){let d=h[c],p=h[c+1];if(d.global&&(d.lastIndex=0),d.test(f))return p}return null},this.abort=function(){return this.abortController.abort(),this.abortController=new AbortController,this}}},bf=new _a,Ma=class{constructor(e){this.manager=e!==void 0?e:bf,this.crossOrigin="anonymous",this.withCredentials=!1,this.path="",this.resourcePath="",this.requestHeader={}}load(){}loadAsync(e,t){let n=this;return new Promise(function(i,s){n.load(e,i,t,s)})}parse(){}setCrossOrigin(e){return this.crossOrigin=e,this}setWithCredentials(e){return this.withCredentials=e,this}setPath(e){return this.path=e,this}setResourcePath(e){return this.resourcePath=e,this}setRequestHeader(e){return this.requestHeader=e,this}abort(){return this}};Ma.DEFAULT_MATERIAL_NAME="__DEFAULT";var jr=class extends Xt{constructor(e,t=1){super(),this.isLight=!0,this.type="Light",this.color=new ot(e),this.intensity=t}dispose(){}copy(e,t){return super.copy(e,t),this.color.copy(e.color),this.intensity=e.intensity,this}toJSON(e){let t=super.toJSON(e);return t.object.color=this.color.getHex(),t.object.intensity=this.intensity,this.groundColor!==void 0&&(t.object.groundColor=this.groundColor.getHex()),this.distance!==void 0&&(t.object.distance=this.distance),this.angle!==void 0&&(t.object.angle=this.angle),this.decay!==void 0&&(t.object.decay=this.decay),this.penumbra!==void 0&&(t.object.penumbra=this.penumbra),this.shadow!==void 0&&(t.object.shadow=this.shadow.toJSON()),this.target!==void 0&&(t.object.target=this.target.uuid),t}},Qr=class extends jr{constructor(e,t,n){super(e,n),this.isHemisphereLight=!0,this.type="HemisphereLight",this.position.copy(Xt.DEFAULT_UP),this.updateMatrix(),this.groundColor=new ot(t)}copy(e,t){return super.copy(e,t),this.groundColor.copy(e.groundColor),this}},Pc=new Mt,Ru=new G,Pu=new G,Bc=class{constructor(e){this.camera=e,this.intensity=1,this.bias=0,this.normalBias=0,this.radius=1,this.blurSamples=8,this.mapSize=new et(512,512),this.mapType=Jn,this.map=null,this.mapPass=null,this.matrix=new Mt,this.autoUpdate=!0,this.needsUpdate=!1,this._frustum=new tr,this._frameExtents=new et(1,1),this._viewportCount=1,this._viewports=[new St(0,0,1,1)]}getViewportCount(){return this._viewportCount}getFrustum(){return this._frustum}updateMatrices(e){let t=this.camera,n=this.matrix;Ru.setFromMatrixPosition(e.matrixWorld),t.position.copy(Ru),Pu.setFromMatrixPosition(e.target.matrixWorld),t.lookAt(Pu),t.updateMatrixWorld(),Pc.multiplyMatrices(t.projectionMatrix,t.matrixWorldInverse),this._frustum.setFromProjectionMatrix(Pc,t.coordinateSystem,t.reversedDepth),t.reversedDepth?n.set(.5,0,0,.5,0,.5,0,.5,0,0,1,0,0,0,0,1):n.set(.5,0,0,.5,0,.5,0,.5,0,0,.5,.5,0,0,0,1),n.multiply(Pc)}getViewport(e){return this._viewports[e]}getFrameExtents(){return this._frameExtents}dispose(){this.map&&this.map.dispose(),this.mapPass&&this.mapPass.dispose()}copy(e){return this.camera=e.camera.clone(),this.intensity=e.intensity,this.bias=e.bias,this.radius=e.radius,this.autoUpdate=e.autoUpdate,this.needsUpdate=e.needsUpdate,this.normalBias=e.normalBias,this.blurSamples=e.blurSamples,this.mapSize.copy(e.mapSize),this}clone(){return new this.constructor().copy(this)}toJSON(){let e={};return this.intensity!==1&&(e.intensity=this.intensity),this.bias!==0&&(e.bias=this.bias),this.normalBias!==0&&(e.normalBias=this.normalBias),this.radius!==1&&(e.radius=this.radius),(this.mapSize.x!==512||this.mapSize.y!==512)&&(e.mapSize=this.mapSize.toArray()),e.camera=this.camera.toJSON(!1).object,delete e.camera.matrix,e}};var eo=class extends zr{constructor(e=-1,t=1,n=1,i=-1,s=.1,o=2e3){super(),this.isOrthographicCamera=!0,this.type="OrthographicCamera",this.zoom=1,this.view=null,this.left=e,this.right=t,this.top=n,this.bottom=i,this.near=s,this.far=o,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.left=e.left,this.right=e.right,this.top=e.top,this.bottom=e.bottom,this.near=e.near,this.far=e.far,this.zoom=e.zoom,this.view=e.view===null?null:Object.assign({},e.view),this}setViewOffset(e,t,n,i,s,o){this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=n,this.view.offsetY=i,this.view.width=s,this.view.height=o,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let e=(this.right-this.left)/(2*this.zoom),t=(this.top-this.bottom)/(2*this.zoom),n=(this.right+this.left)/2,i=(this.top+this.bottom)/2,s=n-e,o=n+e,a=i+t,l=i-t;if(this.view!==null&&this.view.enabled){let h=(this.right-this.left)/this.view.fullWidth/this.zoom,f=(this.top-this.bottom)/this.view.fullHeight/this.zoom;s+=h*this.view.offsetX,o=s+h*this.view.width,a-=f*this.view.offsetY,l=a-f*this.view.height}this.projectionMatrix.makeOrthographic(s,o,a,l,this.near,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){let t=super.toJSON(e);return t.object.zoom=this.zoom,t.object.left=this.left,t.object.right=this.right,t.object.top=this.top,t.object.bottom=this.bottom,t.object.near=this.near,t.object.far=this.far,this.view!==null&&(t.object.view=Object.assign({},this.view)),t}},Uc=class extends Bc{constructor(){super(new eo(-5,5,5,-5,.5,500)),this.isDirectionalLightShadow=!0}},rr=class extends jr{constructor(e,t){super(e,t),this.isDirectionalLight=!0,this.type="DirectionalLight",this.position.copy(Xt.DEFAULT_UP),this.updateMatrix(),this.target=new Xt,this.shadow=new Uc}dispose(){this.shadow.dispose()}copy(e){return super.copy(e),this.target=e.target.clone(),this.shadow=e.shadow.clone(),this}};var Sa=class extends Qt{constructor(e=[]){super(),this.isArrayCamera=!0,this.isMultiViewCamera=!1,this.cameras=e}};var oh="\\[\\]\\.:\\/",Ap=new RegExp("["+oh+"]","g"),ah="[^"+oh+"]",Tp="[^"+oh.replace("\\.","")+"]",Cp=/((?:WC+[\/:])*)/.source.replace("WC",ah),Rp=/(WCOD+)?/.source.replace("WCOD",Tp),Pp=/(?:\.(WC+)(?:\[(.+)\])?)?/.source.replace("WC",ah),Ip=/\.(WC+)(?:\[(.+)\])?/.source.replace("WC",ah),Np=new RegExp("^"+Cp+Rp+Pp+Ip+"$"),Lp=["material","materials","bones","map"],Oc=class{constructor(e,t,n){let i=n||vt.parseTrackName(t);this._targetGroup=e,this._bindings=e.subscribe_(t,i)}getValue(e,t){this.bind();let n=this._targetGroup.nCachedObjects_,i=this._bindings[n];i!==void 0&&i.getValue(e,t)}setValue(e,t){let n=this._bindings;for(let i=this._targetGroup.nCachedObjects_,s=n.length;i!==s;++i)n[i].setValue(e,t)}bind(){let e=this._bindings;for(let t=this._targetGroup.nCachedObjects_,n=e.length;t!==n;++t)e[t].bind()}unbind(){let e=this._bindings;for(let t=this._targetGroup.nCachedObjects_,n=e.length;t!==n;++t)e[t].unbind()}},vt=class r{constructor(e,t,n){this.path=t,this.parsedPath=n||r.parseTrackName(t),this.node=r.findNode(e,this.parsedPath.nodeName),this.rootNode=e,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}static create(e,t,n){return e&&e.isAnimationObjectGroup?new r.Composite(e,t,n):new r(e,t,n)}static sanitizeNodeName(e){return e.replace(/\s/g,"_").replace(Ap,"")}static parseTrackName(e){let t=Np.exec(e);if(t===null)throw new Error("PropertyBinding: Cannot parse trackName: "+e);let n={nodeName:t[2],objectName:t[3],objectIndex:t[4],propertyName:t[5],propertyIndex:t[6]},i=n.nodeName&&n.nodeName.lastIndexOf(".");if(i!==void 0&&i!==-1){let s=n.nodeName.substring(i+1);Lp.indexOf(s)!==-1&&(n.nodeName=n.nodeName.substring(0,i),n.objectName=s)}if(n.propertyName===null||n.propertyName.length===0)throw new Error("PropertyBinding: can not parse propertyName from trackName: "+e);return n}static findNode(e,t){if(t===void 0||t===""||t==="."||t===-1||t===e.name||t===e.uuid)return e;if(e.skeleton){let n=e.skeleton.getBoneByName(t);if(n!==void 0)return n}if(e.children){let n=function(s){for(let o=0;o<s.length;o++){let a=s[o];if(a.name===t||a.uuid===t)return a;let l=n(a.children);if(l)return l}return null},i=n(e.children);if(i)return i}return null}_getValue_unavailable(){}_setValue_unavailable(){}_getValue_direct(e,t){e[t]=this.targetObject[this.propertyName]}_getValue_array(e,t){let n=this.resolvedProperty;for(let i=0,s=n.length;i!==s;++i)e[t++]=n[i]}_getValue_arrayElement(e,t){e[t]=this.resolvedProperty[this.propertyIndex]}_getValue_toArray(e,t){this.resolvedProperty.toArray(e,t)}_setValue_direct(e,t){this.targetObject[this.propertyName]=e[t]}_setValue_direct_setNeedsUpdate(e,t){this.targetObject[this.propertyName]=e[t],this.targetObject.needsUpdate=!0}_setValue_direct_setMatrixWorldNeedsUpdate(e,t){this.targetObject[this.propertyName]=e[t],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_array(e,t){let n=this.resolvedProperty;for(let i=0,s=n.length;i!==s;++i)n[i]=e[t++]}_setValue_array_setNeedsUpdate(e,t){let n=this.resolvedProperty;for(let i=0,s=n.length;i!==s;++i)n[i]=e[t++];this.targetObject.needsUpdate=!0}_setValue_array_setMatrixWorldNeedsUpdate(e,t){let n=this.resolvedProperty;for(let i=0,s=n.length;i!==s;++i)n[i]=e[t++];this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_arrayElement(e,t){this.resolvedProperty[this.propertyIndex]=e[t]}_setValue_arrayElement_setNeedsUpdate(e,t){this.resolvedProperty[this.propertyIndex]=e[t],this.targetObject.needsUpdate=!0}_setValue_arrayElement_setMatrixWorldNeedsUpdate(e,t){this.resolvedProperty[this.propertyIndex]=e[t],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_fromArray(e,t){this.resolvedProperty.fromArray(e,t)}_setValue_fromArray_setNeedsUpdate(e,t){this.resolvedProperty.fromArray(e,t),this.targetObject.needsUpdate=!0}_setValue_fromArray_setMatrixWorldNeedsUpdate(e,t){this.resolvedProperty.fromArray(e,t),this.targetObject.matrixWorldNeedsUpdate=!0}_getValue_unbound(e,t){this.bind(),this.getValue(e,t)}_setValue_unbound(e,t){this.bind(),this.setValue(e,t)}bind(){let e=this.node,t=this.parsedPath,n=t.objectName,i=t.propertyName,s=t.propertyIndex;if(e||(e=r.findNode(this.rootNode,t.nodeName),this.node=e),this.getValue=this._getValue_unavailable,this.setValue=this._setValue_unavailable,!e){console.warn("THREE.PropertyBinding: No target node found for track: "+this.path+".");return}if(n){let h=t.objectIndex;switch(n){case"materials":if(!e.material){console.error("THREE.PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!e.material.materials){console.error("THREE.PropertyBinding: Can not bind to material.materials as node.material does not have a materials array.",this);return}e=e.material.materials;break;case"bones":if(!e.skeleton){console.error("THREE.PropertyBinding: Can not bind to bones as node does not have a skeleton.",this);return}e=e.skeleton.bones;for(let f=0;f<e.length;f++)if(e[f].name===h){h=f;break}break;case"map":if("map"in e){e=e.map;break}if(!e.material){console.error("THREE.PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!e.material.map){console.error("THREE.PropertyBinding: Can not bind to material.map as node.material does not have a map.",this);return}e=e.material.map;break;default:if(e[n]===void 0){console.error("THREE.PropertyBinding: Can not bind to objectName of node undefined.",this);return}e=e[n]}if(h!==void 0){if(e[h]===void 0){console.error("THREE.PropertyBinding: Trying to bind to objectIndex of objectName, but is undefined.",this,e);return}e=e[h]}}let o=e[i];if(o===void 0){let h=t.nodeName;console.error("THREE.PropertyBinding: Trying to update property for track: "+h+"."+i+" but it wasn't found.",e);return}let a=this.Versioning.None;this.targetObject=e,e.isMaterial===!0?a=this.Versioning.NeedsUpdate:e.isObject3D===!0&&(a=this.Versioning.MatrixWorldNeedsUpdate);let l=this.BindingType.Direct;if(s!==void 0){if(i==="morphTargetInfluences"){if(!e.geometry){console.error("THREE.PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.",this);return}if(!e.geometry.morphAttributes){console.error("THREE.PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.morphAttributes.",this);return}e.morphTargetDictionary[s]!==void 0&&(s=e.morphTargetDictionary[s])}l=this.BindingType.ArrayElement,this.resolvedProperty=o,this.propertyIndex=s}else o.fromArray!==void 0&&o.toArray!==void 0?(l=this.BindingType.HasFromToArray,this.resolvedProperty=o):Array.isArray(o)?(l=this.BindingType.EntireArray,this.resolvedProperty=o):this.propertyName=i;this.getValue=this.GetterByBindingType[l],this.setValue=this.SetterByBindingTypeAndVersioning[l][a]}unbind(){this.node=null,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}};vt.Composite=Oc;vt.prototype.BindingType={Direct:0,EntireArray:1,ArrayElement:2,HasFromToArray:3};vt.prototype.Versioning={None:0,NeedsUpdate:1,MatrixWorldNeedsUpdate:2};vt.prototype.GetterByBindingType=[vt.prototype._getValue_direct,vt.prototype._getValue_array,vt.prototype._getValue_arrayElement,vt.prototype._getValue_toArray];vt.prototype.SetterByBindingTypeAndVersioning=[[vt.prototype._setValue_direct,vt.prototype._setValue_direct_setNeedsUpdate,vt.prototype._setValue_direct_setMatrixWorldNeedsUpdate],[vt.prototype._setValue_array,vt.prototype._setValue_array_setNeedsUpdate,vt.prototype._setValue_array_setMatrixWorldNeedsUpdate],[vt.prototype._setValue_arrayElement,vt.prototype._setValue_arrayElement_setNeedsUpdate,vt.prototype._setValue_arrayElement_setMatrixWorldNeedsUpdate],[vt.prototype._setValue_fromArray,vt.prototype._setValue_fromArray_setNeedsUpdate,vt.prototype._setValue_fromArray_setMatrixWorldNeedsUpdate]];var vM=new Float32Array(1);var Iu=new Mt,to=class{constructor(e,t,n=0,i=1/0){this.ray=new js(e,t),this.near=n,this.far=i,this.camera=null,this.layers=new Qs,this.params={Mesh:{},Line:{threshold:1},LOD:{},Points:{threshold:1},Sprite:{}}}set(e,t){this.ray.set(e,t)}setFromCamera(e,t){t.isPerspectiveCamera?(this.ray.origin.setFromMatrixPosition(t.matrixWorld),this.ray.direction.set(e.x,e.y,.5).unproject(t).sub(this.ray.origin).normalize(),this.camera=t):t.isOrthographicCamera?(this.ray.origin.set(e.x,e.y,(t.near+t.far)/(t.near-t.far)).unproject(t),this.ray.direction.set(0,0,-1).transformDirection(t.matrixWorld),this.camera=t):console.error("THREE.Raycaster: Unsupported camera type: "+t.type)}setFromXRController(e){return Iu.identity().extractRotation(e.matrixWorld),this.ray.origin.setFromMatrixPosition(e.matrixWorld),this.ray.direction.set(0,0,-1).applyMatrix4(Iu),this}intersectObject(e,t=!0,n=[]){return zc(e,this,n,t),n.sort(Nu),n}intersectObjects(e,t=!0,n=[]){for(let i=0,s=e.length;i<s;i++)zc(e[i],this,n,t);return n.sort(Nu),n}};function Nu(r,e){return r.distance-e.distance}function zc(r,e,t,n){let i=!0;if(r.layers.test(e.layers)&&r.raycast(e,t)===!1&&(i=!1),i===!0&&n===!0){let s=r.children;for(let o=0,a=s.length;o<a;o++)zc(s[o],e,t,!0)}}function lh(r,e,t,n){let i=Dp(n);switch(t){case Jc:return r*e;case Qc:return r*e/i.components*i.byteLength;case Oa:return r*e/i.components*i.byteLength;case eh:return r*e*2/i.components*i.byteLength;case za:return r*e*2/i.components*i.byteLength;case jc:return r*e*3/i.components*i.byteLength;case Bn:return r*e*4/i.components*i.byteLength;case ka:return r*e*4/i.components*i.byteLength;case so:case ro:return Math.floor((r+3)/4)*Math.floor((e+3)/4)*8;case oo:case ao:return Math.floor((r+3)/4)*Math.floor((e+3)/4)*16;case Ha:case Wa:return Math.max(r,16)*Math.max(e,8)/4;case Va:case Ga:return Math.max(r,8)*Math.max(e,8)/2;case qa:case Xa:return Math.floor((r+3)/4)*Math.floor((e+3)/4)*8;case $a:return Math.floor((r+3)/4)*Math.floor((e+3)/4)*16;case Ya:return Math.floor((r+3)/4)*Math.floor((e+3)/4)*16;case Za:return Math.floor((r+4)/5)*Math.floor((e+3)/4)*16;case Ka:return Math.floor((r+4)/5)*Math.floor((e+4)/5)*16;case Ja:return Math.floor((r+5)/6)*Math.floor((e+4)/5)*16;case ja:return Math.floor((r+5)/6)*Math.floor((e+5)/6)*16;case Qa:return Math.floor((r+7)/8)*Math.floor((e+4)/5)*16;case el:return Math.floor((r+7)/8)*Math.floor((e+5)/6)*16;case tl:return Math.floor((r+7)/8)*Math.floor((e+7)/8)*16;case nl:return Math.floor((r+9)/10)*Math.floor((e+4)/5)*16;case il:return Math.floor((r+9)/10)*Math.floor((e+5)/6)*16;case sl:return Math.floor((r+9)/10)*Math.floor((e+7)/8)*16;case rl:return Math.floor((r+9)/10)*Math.floor((e+9)/10)*16;case ol:return Math.floor((r+11)/12)*Math.floor((e+9)/10)*16;case al:return Math.floor((r+11)/12)*Math.floor((e+11)/12)*16;case ll:case cl:case hl:return Math.ceil(r/4)*Math.ceil(e/4)*16;case ul:case fl:return Math.ceil(r/4)*Math.ceil(e/4)*8;case dl:case pl:return Math.ceil(r/4)*Math.ceil(e/4)*16}throw new Error(`Unable to determine texture byte length for ${t} format.`)}function Dp(r){switch(r){case Jn:case $c:return{byteLength:1,components:1};case or:case Yc:case ar:return{byteLength:2,components:1};case Ba:case Ua:return{byteLength:2,components:4};case Qi:case Fa:case ci:return{byteLength:4,components:1};case Zc:case Kc:return{byteLength:4,components:3}}throw new Error(`Unknown texture type ${r}.`)}typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("register",{detail:{revision:"180"}}));typeof window<"u"&&(window.__THREE__?console.warn("WARNING: Multiple instances of Three.js being imported."):window.__THREE__="180");function $f(){let r=null,e=!1,t=null,n=null;function i(s,o){t(s,o),n=r.requestAnimationFrame(i)}return{start:function(){e!==!0&&t!==null&&(n=r.requestAnimationFrame(i),e=!0)},stop:function(){r.cancelAnimationFrame(n),e=!1},setAnimationLoop:function(s){t=s},setContext:function(s){r=s}}}function Bp(r){let e=new WeakMap;function t(a,l){let h=a.array,f=a.usage,c=h.byteLength,u=r.createBuffer();r.bindBuffer(l,u),r.bufferData(l,h,f),a.onUploadCallback();let d;if(h instanceof Float32Array)d=r.FLOAT;else if(typeof Float16Array<"u"&&h instanceof Float16Array)d=r.HALF_FLOAT;else if(h instanceof Uint16Array)a.isFloat16BufferAttribute?d=r.HALF_FLOAT:d=r.UNSIGNED_SHORT;else if(h instanceof Int16Array)d=r.SHORT;else if(h instanceof Uint32Array)d=r.UNSIGNED_INT;else if(h instanceof Int32Array)d=r.INT;else if(h instanceof Int8Array)d=r.BYTE;else if(h instanceof Uint8Array)d=r.UNSIGNED_BYTE;else if(h instanceof Uint8ClampedArray)d=r.UNSIGNED_BYTE;else throw new Error("THREE.WebGLAttributes: Unsupported buffer data format: "+h);return{buffer:u,type:d,bytesPerElement:h.BYTES_PER_ELEMENT,version:a.version,size:c}}function n(a,l,h){let f=l.array,c=l.updateRanges;if(r.bindBuffer(h,a),c.length===0)r.bufferSubData(h,0,f);else{c.sort((d,p)=>d.start-p.start);let u=0;for(let d=1;d<c.length;d++){let p=c[u],v=c[d];v.start<=p.start+p.count+1?p.count=Math.max(p.count,v.start+v.count-p.start):(++u,c[u]=v)}c.length=u+1;for(let d=0,p=c.length;d<p;d++){let v=c[d];r.bufferSubData(h,v.start*f.BYTES_PER_ELEMENT,f,v.start,v.count)}l.clearUpdateRanges()}l.onUploadCallback()}function i(a){return a.isInterleavedBufferAttribute&&(a=a.data),e.get(a)}function s(a){a.isInterleavedBufferAttribute&&(a=a.data);let l=e.get(a);l&&(r.deleteBuffer(l.buffer),e.delete(a))}function o(a,l){if(a.isInterleavedBufferAttribute&&(a=a.data),a.isGLBufferAttribute){let f=e.get(a);(!f||f.version<a.version)&&e.set(a,{buffer:a.buffer,type:a.type,bytesPerElement:a.elementSize,version:a.version});return}let h=e.get(a);if(h===void 0)e.set(a,t(a,l));else if(h.version<a.version){if(h.size!==a.array.byteLength)throw new Error("THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.");n(h.buffer,a,l),h.version=a.version}}return{get:i,remove:s,update:o}}var Up=`#ifdef USE_ALPHAHASH
	if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;
#endif`,Op=`#ifdef USE_ALPHAHASH
	const float ALPHA_HASH_SCALE = 0.05;
	float hash2D( vec2 value ) {
		return fract( 1.0e4 * sin( 17.0 * value.x + 0.1 * value.y ) * ( 0.1 + abs( sin( 13.0 * value.y + value.x ) ) ) );
	}
	float hash3D( vec3 value ) {
		return hash2D( vec2( hash2D( value.xy ), value.z ) );
	}
	float getAlphaHashThreshold( vec3 position ) {
		float maxDeriv = max(
			length( dFdx( position.xyz ) ),
			length( dFdy( position.xyz ) )
		);
		float pixScale = 1.0 / ( ALPHA_HASH_SCALE * maxDeriv );
		vec2 pixScales = vec2(
			exp2( floor( log2( pixScale ) ) ),
			exp2( ceil( log2( pixScale ) ) )
		);
		vec2 alpha = vec2(
			hash3D( floor( pixScales.x * position.xyz ) ),
			hash3D( floor( pixScales.y * position.xyz ) )
		);
		float lerpFactor = fract( log2( pixScale ) );
		float x = ( 1.0 - lerpFactor ) * alpha.x + lerpFactor * alpha.y;
		float a = min( lerpFactor, 1.0 - lerpFactor );
		vec3 cases = vec3(
			x * x / ( 2.0 * a * ( 1.0 - a ) ),
			( x - 0.5 * a ) / ( 1.0 - a ),
			1.0 - ( ( 1.0 - x ) * ( 1.0 - x ) / ( 2.0 * a * ( 1.0 - a ) ) )
		);
		float threshold = ( x < ( 1.0 - a ) )
			? ( ( x < a ) ? cases.x : cases.y )
			: cases.z;
		return clamp( threshold , 1.0e-6, 1.0 );
	}
#endif`,zp=`#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, vAlphaMapUv ).g;
#endif`,kp=`#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,Vp=`#ifdef USE_ALPHATEST
	#ifdef ALPHA_TO_COVERAGE
	diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
	if ( diffuseColor.a == 0.0 ) discard;
	#else
	if ( diffuseColor.a < alphaTest ) discard;
	#endif
#endif`,Hp=`#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif`,Gp=`#ifdef USE_AOMAP
	float ambientOcclusion = ( texture2D( aoMap, vAoMapUv ).r - 1.0 ) * aoMapIntensity + 1.0;
	reflectedLight.indirectDiffuse *= ambientOcclusion;
	#if defined( USE_CLEARCOAT ) 
		clearcoatSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_SHEEN ) 
		sheenSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD )
		float dotNV = saturate( dot( geometryNormal, geometryViewDir ) );
		reflectedLight.indirectSpecular *= computeSpecularOcclusion( dotNV, ambientOcclusion, material.roughness );
	#endif
#endif`,Wp=`#ifdef USE_AOMAP
	uniform sampler2D aoMap;
	uniform float aoMapIntensity;
#endif`,qp=`#ifdef USE_BATCHING
	#if ! defined( GL_ANGLE_multi_draw )
	#define gl_DrawID _gl_DrawID
	uniform int _gl_DrawID;
	#endif
	uniform highp sampler2D batchingTexture;
	uniform highp usampler2D batchingIdTexture;
	mat4 getBatchingMatrix( const in float i ) {
		int size = textureSize( batchingTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( batchingTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( batchingTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( batchingTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( batchingTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
	float getIndirectIndex( const in int i ) {
		int size = textureSize( batchingIdTexture, 0 ).x;
		int x = i % size;
		int y = i / size;
		return float( texelFetch( batchingIdTexture, ivec2( x, y ), 0 ).r );
	}
#endif
#ifdef USE_BATCHING_COLOR
	uniform sampler2D batchingColorTexture;
	vec3 getBatchingColor( const in float i ) {
		int size = textureSize( batchingColorTexture, 0 ).x;
		int j = int( i );
		int x = j % size;
		int y = j / size;
		return texelFetch( batchingColorTexture, ivec2( x, y ), 0 ).rgb;
	}
#endif`,Xp=`#ifdef USE_BATCHING
	mat4 batchingMatrix = getBatchingMatrix( getIndirectIndex( gl_DrawID ) );
#endif`,$p=`vec3 transformed = vec3( position );
#ifdef USE_ALPHAHASH
	vPosition = vec3( position );
#endif`,Yp=`vec3 objectNormal = vec3( normal );
#ifdef USE_TANGENT
	vec3 objectTangent = vec3( tangent.xyz );
#endif`,Zp=`float G_BlinnPhong_Implicit( ) {
	return 0.25;
}
float D_BlinnPhong( const in float shininess, const in float dotNH ) {
	return RECIPROCAL_PI * ( shininess * 0.5 + 1.0 ) * pow( dotNH, shininess );
}
vec3 BRDF_BlinnPhong( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in vec3 specularColor, const in float shininess ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( specularColor, 1.0, dotVH );
	float G = G_BlinnPhong_Implicit( );
	float D = D_BlinnPhong( shininess, dotNH );
	return F * ( G * D );
} // validated`,Kp=`#ifdef USE_IRIDESCENCE
	const mat3 XYZ_TO_REC709 = mat3(
		 3.2404542, -0.9692660,  0.0556434,
		-1.5371385,  1.8760108, -0.2040259,
		-0.4985314,  0.0415560,  1.0572252
	);
	vec3 Fresnel0ToIor( vec3 fresnel0 ) {
		vec3 sqrtF0 = sqrt( fresnel0 );
		return ( vec3( 1.0 ) + sqrtF0 ) / ( vec3( 1.0 ) - sqrtF0 );
	}
	vec3 IorToFresnel0( vec3 transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - vec3( incidentIor ) ) / ( transmittedIor + vec3( incidentIor ) ) );
	}
	float IorToFresnel0( float transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - incidentIor ) / ( transmittedIor + incidentIor ));
	}
	vec3 evalSensitivity( float OPD, vec3 shift ) {
		float phase = 2.0 * PI * OPD * 1.0e-9;
		vec3 val = vec3( 5.4856e-13, 4.4201e-13, 5.2481e-13 );
		vec3 pos = vec3( 1.6810e+06, 1.7953e+06, 2.2084e+06 );
		vec3 var = vec3( 4.3278e+09, 9.3046e+09, 6.6121e+09 );
		vec3 xyz = val * sqrt( 2.0 * PI * var ) * cos( pos * phase + shift ) * exp( - pow2( phase ) * var );
		xyz.x += 9.7470e-14 * sqrt( 2.0 * PI * 4.5282e+09 ) * cos( 2.2399e+06 * phase + shift[ 0 ] ) * exp( - 4.5282e+09 * pow2( phase ) );
		xyz /= 1.0685e-7;
		vec3 rgb = XYZ_TO_REC709 * xyz;
		return rgb;
	}
	vec3 evalIridescence( float outsideIOR, float eta2, float cosTheta1, float thinFilmThickness, vec3 baseF0 ) {
		vec3 I;
		float iridescenceIOR = mix( outsideIOR, eta2, smoothstep( 0.0, 0.03, thinFilmThickness ) );
		float sinTheta2Sq = pow2( outsideIOR / iridescenceIOR ) * ( 1.0 - pow2( cosTheta1 ) );
		float cosTheta2Sq = 1.0 - sinTheta2Sq;
		if ( cosTheta2Sq < 0.0 ) {
			return vec3( 1.0 );
		}
		float cosTheta2 = sqrt( cosTheta2Sq );
		float R0 = IorToFresnel0( iridescenceIOR, outsideIOR );
		float R12 = F_Schlick( R0, 1.0, cosTheta1 );
		float T121 = 1.0 - R12;
		float phi12 = 0.0;
		if ( iridescenceIOR < outsideIOR ) phi12 = PI;
		float phi21 = PI - phi12;
		vec3 baseIOR = Fresnel0ToIor( clamp( baseF0, 0.0, 0.9999 ) );		vec3 R1 = IorToFresnel0( baseIOR, iridescenceIOR );
		vec3 R23 = F_Schlick( R1, 1.0, cosTheta2 );
		vec3 phi23 = vec3( 0.0 );
		if ( baseIOR[ 0 ] < iridescenceIOR ) phi23[ 0 ] = PI;
		if ( baseIOR[ 1 ] < iridescenceIOR ) phi23[ 1 ] = PI;
		if ( baseIOR[ 2 ] < iridescenceIOR ) phi23[ 2 ] = PI;
		float OPD = 2.0 * iridescenceIOR * thinFilmThickness * cosTheta2;
		vec3 phi = vec3( phi21 ) + phi23;
		vec3 R123 = clamp( R12 * R23, 1e-5, 0.9999 );
		vec3 r123 = sqrt( R123 );
		vec3 Rs = pow2( T121 ) * R23 / ( vec3( 1.0 ) - R123 );
		vec3 C0 = R12 + Rs;
		I = C0;
		vec3 Cm = Rs - T121;
		for ( int m = 1; m <= 2; ++ m ) {
			Cm *= r123;
			vec3 Sm = 2.0 * evalSensitivity( float( m ) * OPD, float( m ) * phi );
			I += Cm * Sm;
		}
		return max( I, vec3( 0.0 ) );
	}
#endif`,Jp=`#ifdef USE_BUMPMAP
	uniform sampler2D bumpMap;
	uniform float bumpScale;
	vec2 dHdxy_fwd() {
		vec2 dSTdx = dFdx( vBumpMapUv );
		vec2 dSTdy = dFdy( vBumpMapUv );
		float Hll = bumpScale * texture2D( bumpMap, vBumpMapUv ).x;
		float dBx = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdx ).x - Hll;
		float dBy = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdy ).x - Hll;
		return vec2( dBx, dBy );
	}
	vec3 perturbNormalArb( vec3 surf_pos, vec3 surf_norm, vec2 dHdxy, float faceDirection ) {
		vec3 vSigmaX = normalize( dFdx( surf_pos.xyz ) );
		vec3 vSigmaY = normalize( dFdy( surf_pos.xyz ) );
		vec3 vN = surf_norm;
		vec3 R1 = cross( vSigmaY, vN );
		vec3 R2 = cross( vN, vSigmaX );
		float fDet = dot( vSigmaX, R1 ) * faceDirection;
		vec3 vGrad = sign( fDet ) * ( dHdxy.x * R1 + dHdxy.y * R2 );
		return normalize( abs( fDet ) * surf_norm - vGrad );
	}
#endif`,jp=`#if NUM_CLIPPING_PLANES > 0
	vec4 plane;
	#ifdef ALPHA_TO_COVERAGE
		float distanceToPlane, distanceGradient;
		float clipOpacity = 1.0;
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
			distanceGradient = fwidth( distanceToPlane ) / 2.0;
			clipOpacity *= smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			if ( clipOpacity == 0.0 ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			float unionClipOpacity = 1.0;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
				distanceGradient = fwidth( distanceToPlane ) / 2.0;
				unionClipOpacity *= 1.0 - smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			}
			#pragma unroll_loop_end
			clipOpacity *= 1.0 - unionClipOpacity;
		#endif
		diffuseColor.a *= clipOpacity;
		if ( diffuseColor.a == 0.0 ) discard;
	#else
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			if ( dot( vClipPosition, plane.xyz ) > plane.w ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			bool clipped = true;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				clipped = ( dot( vClipPosition, plane.xyz ) > plane.w ) && clipped;
			}
			#pragma unroll_loop_end
			if ( clipped ) discard;
		#endif
	#endif
#endif`,Qp=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];
#endif`,em=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
#endif`,tm=`#if NUM_CLIPPING_PLANES > 0
	vClipPosition = - mvPosition.xyz;
#endif`,nm=`#if defined( USE_COLOR_ALPHA )
	diffuseColor *= vColor;
#elif defined( USE_COLOR )
	diffuseColor.rgb *= vColor;
#endif`,im=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR )
	varying vec3 vColor;
#endif`,sm=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	varying vec3 vColor;
#endif`,rm=`#if defined( USE_COLOR_ALPHA )
	vColor = vec4( 1.0 );
#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	vColor = vec3( 1.0 );
#endif
#ifdef USE_COLOR
	vColor *= color;
#endif
#ifdef USE_INSTANCING_COLOR
	vColor.xyz *= instanceColor.xyz;
#endif
#ifdef USE_BATCHING_COLOR
	vec3 batchingColor = getBatchingColor( getIndirectIndex( gl_DrawID ) );
	vColor.xyz *= batchingColor.xyz;
#endif`,om=`#define PI 3.141592653589793
#define PI2 6.283185307179586
#define PI_HALF 1.5707963267948966
#define RECIPROCAL_PI 0.3183098861837907
#define RECIPROCAL_PI2 0.15915494309189535
#define EPSILON 1e-6
#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
#define whiteComplement( a ) ( 1.0 - saturate( a ) )
float pow2( const in float x ) { return x*x; }
vec3 pow2( const in vec3 x ) { return x*x; }
float pow3( const in float x ) { return x*x*x; }
float pow4( const in float x ) { float x2 = x*x; return x2*x2; }
float max3( const in vec3 v ) { return max( max( v.x, v.y ), v.z ); }
float average( const in vec3 v ) { return dot( v, vec3( 0.3333333 ) ); }
highp float rand( const in vec2 uv ) {
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract( sin( sn ) * c );
}
#ifdef HIGH_PRECISION
	float precisionSafeLength( vec3 v ) { return length( v ); }
#else
	float precisionSafeLength( vec3 v ) {
		float maxComponent = max3( abs( v ) );
		return length( v / maxComponent ) * maxComponent;
	}
#endif
struct IncidentLight {
	vec3 color;
	vec3 direction;
	bool visible;
};
struct ReflectedLight {
	vec3 directDiffuse;
	vec3 directSpecular;
	vec3 indirectDiffuse;
	vec3 indirectSpecular;
};
#ifdef USE_ALPHAHASH
	varying vec3 vPosition;
#endif
vec3 transformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );
}
vec3 inverseTransformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( vec4( dir, 0.0 ) * matrix ).xyz );
}
mat3 transposeMat3( const in mat3 m ) {
	mat3 tmp;
	tmp[ 0 ] = vec3( m[ 0 ].x, m[ 1 ].x, m[ 2 ].x );
	tmp[ 1 ] = vec3( m[ 0 ].y, m[ 1 ].y, m[ 2 ].y );
	tmp[ 2 ] = vec3( m[ 0 ].z, m[ 1 ].z, m[ 2 ].z );
	return tmp;
}
bool isPerspectiveMatrix( mat4 m ) {
	return m[ 2 ][ 3 ] == - 1.0;
}
vec2 equirectUv( in vec3 dir ) {
	float u = atan( dir.z, dir.x ) * RECIPROCAL_PI2 + 0.5;
	float v = asin( clamp( dir.y, - 1.0, 1.0 ) ) * RECIPROCAL_PI + 0.5;
	return vec2( u, v );
}
vec3 BRDF_Lambert( const in vec3 diffuseColor ) {
	return RECIPROCAL_PI * diffuseColor;
}
vec3 F_Schlick( const in vec3 f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
}
float F_Schlick( const in float f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
} // validated`,am=`#ifdef ENVMAP_TYPE_CUBE_UV
	#define cubeUV_minMipLevel 4.0
	#define cubeUV_minTileSize 16.0
	float getFace( vec3 direction ) {
		vec3 absDirection = abs( direction );
		float face = - 1.0;
		if ( absDirection.x > absDirection.z ) {
			if ( absDirection.x > absDirection.y )
				face = direction.x > 0.0 ? 0.0 : 3.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		} else {
			if ( absDirection.z > absDirection.y )
				face = direction.z > 0.0 ? 2.0 : 5.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		}
		return face;
	}
	vec2 getUV( vec3 direction, float face ) {
		vec2 uv;
		if ( face == 0.0 ) {
			uv = vec2( direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 1.0 ) {
			uv = vec2( - direction.x, - direction.z ) / abs( direction.y );
		} else if ( face == 2.0 ) {
			uv = vec2( - direction.x, direction.y ) / abs( direction.z );
		} else if ( face == 3.0 ) {
			uv = vec2( - direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 4.0 ) {
			uv = vec2( - direction.x, direction.z ) / abs( direction.y );
		} else {
			uv = vec2( direction.x, direction.y ) / abs( direction.z );
		}
		return 0.5 * ( uv + 1.0 );
	}
	vec3 bilinearCubeUV( sampler2D envMap, vec3 direction, float mipInt ) {
		float face = getFace( direction );
		float filterInt = max( cubeUV_minMipLevel - mipInt, 0.0 );
		mipInt = max( mipInt, cubeUV_minMipLevel );
		float faceSize = exp2( mipInt );
		highp vec2 uv = getUV( direction, face ) * ( faceSize - 2.0 ) + 1.0;
		if ( face > 2.0 ) {
			uv.y += faceSize;
			face -= 3.0;
		}
		uv.x += face * faceSize;
		uv.x += filterInt * 3.0 * cubeUV_minTileSize;
		uv.y += 4.0 * ( exp2( CUBEUV_MAX_MIP ) - faceSize );
		uv.x *= CUBEUV_TEXEL_WIDTH;
		uv.y *= CUBEUV_TEXEL_HEIGHT;
		#ifdef texture2DGradEXT
			return texture2DGradEXT( envMap, uv, vec2( 0.0 ), vec2( 0.0 ) ).rgb;
		#else
			return texture2D( envMap, uv ).rgb;
		#endif
	}
	#define cubeUV_r0 1.0
	#define cubeUV_m0 - 2.0
	#define cubeUV_r1 0.8
	#define cubeUV_m1 - 1.0
	#define cubeUV_r4 0.4
	#define cubeUV_m4 2.0
	#define cubeUV_r5 0.305
	#define cubeUV_m5 3.0
	#define cubeUV_r6 0.21
	#define cubeUV_m6 4.0
	float roughnessToMip( float roughness ) {
		float mip = 0.0;
		if ( roughness >= cubeUV_r1 ) {
			mip = ( cubeUV_r0 - roughness ) * ( cubeUV_m1 - cubeUV_m0 ) / ( cubeUV_r0 - cubeUV_r1 ) + cubeUV_m0;
		} else if ( roughness >= cubeUV_r4 ) {
			mip = ( cubeUV_r1 - roughness ) * ( cubeUV_m4 - cubeUV_m1 ) / ( cubeUV_r1 - cubeUV_r4 ) + cubeUV_m1;
		} else if ( roughness >= cubeUV_r5 ) {
			mip = ( cubeUV_r4 - roughness ) * ( cubeUV_m5 - cubeUV_m4 ) / ( cubeUV_r4 - cubeUV_r5 ) + cubeUV_m4;
		} else if ( roughness >= cubeUV_r6 ) {
			mip = ( cubeUV_r5 - roughness ) * ( cubeUV_m6 - cubeUV_m5 ) / ( cubeUV_r5 - cubeUV_r6 ) + cubeUV_m5;
		} else {
			mip = - 2.0 * log2( 1.16 * roughness );		}
		return mip;
	}
	vec4 textureCubeUV( sampler2D envMap, vec3 sampleDir, float roughness ) {
		float mip = clamp( roughnessToMip( roughness ), cubeUV_m0, CUBEUV_MAX_MIP );
		float mipF = fract( mip );
		float mipInt = floor( mip );
		vec3 color0 = bilinearCubeUV( envMap, sampleDir, mipInt );
		if ( mipF == 0.0 ) {
			return vec4( color0, 1.0 );
		} else {
			vec3 color1 = bilinearCubeUV( envMap, sampleDir, mipInt + 1.0 );
			return vec4( mix( color0, color1, mipF ), 1.0 );
		}
	}
#endif`,lm=`vec3 transformedNormal = objectNormal;
#ifdef USE_TANGENT
	vec3 transformedTangent = objectTangent;
#endif
#ifdef USE_BATCHING
	mat3 bm = mat3( batchingMatrix );
	transformedNormal /= vec3( dot( bm[ 0 ], bm[ 0 ] ), dot( bm[ 1 ], bm[ 1 ] ), dot( bm[ 2 ], bm[ 2 ] ) );
	transformedNormal = bm * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = bm * transformedTangent;
	#endif
#endif
#ifdef USE_INSTANCING
	mat3 im = mat3( instanceMatrix );
	transformedNormal /= vec3( dot( im[ 0 ], im[ 0 ] ), dot( im[ 1 ], im[ 1 ] ), dot( im[ 2 ], im[ 2 ] ) );
	transformedNormal = im * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = im * transformedTangent;
	#endif
#endif
transformedNormal = normalMatrix * transformedNormal;
#ifdef FLIP_SIDED
	transformedNormal = - transformedNormal;
#endif
#ifdef USE_TANGENT
	transformedTangent = ( modelViewMatrix * vec4( transformedTangent, 0.0 ) ).xyz;
	#ifdef FLIP_SIDED
		transformedTangent = - transformedTangent;
	#endif
#endif`,cm=`#ifdef USE_DISPLACEMENTMAP
	uniform sampler2D displacementMap;
	uniform float displacementScale;
	uniform float displacementBias;
#endif`,hm=`#ifdef USE_DISPLACEMENTMAP
	transformed += normalize( objectNormal ) * ( texture2D( displacementMap, vDisplacementMapUv ).x * displacementScale + displacementBias );
#endif`,um=`#ifdef USE_EMISSIVEMAP
	vec4 emissiveColor = texture2D( emissiveMap, vEmissiveMapUv );
	#ifdef DECODE_VIDEO_TEXTURE_EMISSIVE
		emissiveColor = sRGBTransferEOTF( emissiveColor );
	#endif
	totalEmissiveRadiance *= emissiveColor.rgb;
#endif`,fm=`#ifdef USE_EMISSIVEMAP
	uniform sampler2D emissiveMap;
#endif`,dm="gl_FragColor = linearToOutputTexel( gl_FragColor );",pm=`vec4 LinearTransferOETF( in vec4 value ) {
	return value;
}
vec4 sRGBTransferEOTF( in vec4 value ) {
	return vec4( mix( pow( value.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), value.rgb * 0.0773993808, vec3( lessThanEqual( value.rgb, vec3( 0.04045 ) ) ) ), value.a );
}
vec4 sRGBTransferOETF( in vec4 value ) {
	return vec4( mix( pow( value.rgb, vec3( 0.41666 ) ) * 1.055 - vec3( 0.055 ), value.rgb * 12.92, vec3( lessThanEqual( value.rgb, vec3( 0.0031308 ) ) ) ), value.a );
}`,mm=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vec3 cameraToFrag;
		if ( isOrthographic ) {
			cameraToFrag = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToFrag = normalize( vWorldPosition - cameraPosition );
		}
		vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vec3 reflectVec = reflect( cameraToFrag, worldNormal );
		#else
			vec3 reflectVec = refract( cameraToFrag, worldNormal, refractionRatio );
		#endif
	#else
		vec3 reflectVec = vReflect;
	#endif
	#ifdef ENVMAP_TYPE_CUBE
		vec4 envColor = textureCube( envMap, envMapRotation * vec3( flipEnvMap * reflectVec.x, reflectVec.yz ) );
	#else
		vec4 envColor = vec4( 0.0 );
	#endif
	#ifdef ENVMAP_BLENDING_MULTIPLY
		outgoingLight = mix( outgoingLight, outgoingLight * envColor.xyz, specularStrength * reflectivity );
	#elif defined( ENVMAP_BLENDING_MIX )
		outgoingLight = mix( outgoingLight, envColor.xyz, specularStrength * reflectivity );
	#elif defined( ENVMAP_BLENDING_ADD )
		outgoingLight += envColor.xyz * specularStrength * reflectivity;
	#endif
#endif`,gm=`#ifdef USE_ENVMAP
	uniform float envMapIntensity;
	uniform float flipEnvMap;
	uniform mat3 envMapRotation;
	#ifdef ENVMAP_TYPE_CUBE
		uniform samplerCube envMap;
	#else
		uniform sampler2D envMap;
	#endif
	
#endif`,vm=`#ifdef USE_ENVMAP
	uniform float reflectivity;
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		varying vec3 vWorldPosition;
		uniform float refractionRatio;
	#else
		varying vec3 vReflect;
	#endif
#endif`,xm=`#ifdef USE_ENVMAP
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		
		varying vec3 vWorldPosition;
	#else
		varying vec3 vReflect;
		uniform float refractionRatio;
	#endif
#endif`,ym=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vWorldPosition = worldPosition.xyz;
	#else
		vec3 cameraToVertex;
		if ( isOrthographic ) {
			cameraToVertex = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToVertex = normalize( worldPosition.xyz - cameraPosition );
		}
		vec3 worldNormal = inverseTransformDirection( transformedNormal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vReflect = reflect( cameraToVertex, worldNormal );
		#else
			vReflect = refract( cameraToVertex, worldNormal, refractionRatio );
		#endif
	#endif
#endif`,_m=`#ifdef USE_FOG
	vFogDepth = - mvPosition.z;
#endif`,Mm=`#ifdef USE_FOG
	varying float vFogDepth;
#endif`,Sm=`#ifdef USE_FOG
	#ifdef FOG_EXP2
		float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
	#else
		float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
	#endif
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`,bm=`#ifdef USE_FOG
	uniform vec3 fogColor;
	varying float vFogDepth;
	#ifdef FOG_EXP2
		uniform float fogDensity;
	#else
		uniform float fogNear;
		uniform float fogFar;
	#endif
#endif`,wm=`#ifdef USE_GRADIENTMAP
	uniform sampler2D gradientMap;
#endif
vec3 getGradientIrradiance( vec3 normal, vec3 lightDirection ) {
	float dotNL = dot( normal, lightDirection );
	vec2 coord = vec2( dotNL * 0.5 + 0.5, 0.0 );
	#ifdef USE_GRADIENTMAP
		return vec3( texture2D( gradientMap, coord ).r );
	#else
		vec2 fw = fwidth( coord ) * 0.5;
		return mix( vec3( 0.7 ), vec3( 1.0 ), smoothstep( 0.7 - fw.x, 0.7 + fw.x, coord.x ) );
	#endif
}`,Em=`#ifdef USE_LIGHTMAP
	uniform sampler2D lightMap;
	uniform float lightMapIntensity;
#endif`,Am=`LambertMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularStrength = specularStrength;`,Tm=`varying vec3 vViewPosition;
struct LambertMaterial {
	vec3 diffuseColor;
	float specularStrength;
};
void RE_Direct_Lambert( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Lambert( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Lambert
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Lambert`,Cm=`uniform bool receiveShadow;
uniform vec3 ambientLightColor;
#if defined( USE_LIGHT_PROBES )
	uniform vec3 lightProbe[ 9 ];
#endif
vec3 shGetIrradianceAt( in vec3 normal, in vec3 shCoefficients[ 9 ] ) {
	float x = normal.x, y = normal.y, z = normal.z;
	vec3 result = shCoefficients[ 0 ] * 0.886227;
	result += shCoefficients[ 1 ] * 2.0 * 0.511664 * y;
	result += shCoefficients[ 2 ] * 2.0 * 0.511664 * z;
	result += shCoefficients[ 3 ] * 2.0 * 0.511664 * x;
	result += shCoefficients[ 4 ] * 2.0 * 0.429043 * x * y;
	result += shCoefficients[ 5 ] * 2.0 * 0.429043 * y * z;
	result += shCoefficients[ 6 ] * ( 0.743125 * z * z - 0.247708 );
	result += shCoefficients[ 7 ] * 2.0 * 0.429043 * x * z;
	result += shCoefficients[ 8 ] * 0.429043 * ( x * x - y * y );
	return result;
}
vec3 getLightProbeIrradiance( const in vec3 lightProbe[ 9 ], const in vec3 normal ) {
	vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
	vec3 irradiance = shGetIrradianceAt( worldNormal, lightProbe );
	return irradiance;
}
vec3 getAmbientLightIrradiance( const in vec3 ambientLightColor ) {
	vec3 irradiance = ambientLightColor;
	return irradiance;
}
float getDistanceAttenuation( const in float lightDistance, const in float cutoffDistance, const in float decayExponent ) {
	float distanceFalloff = 1.0 / max( pow( lightDistance, decayExponent ), 0.01 );
	if ( cutoffDistance > 0.0 ) {
		distanceFalloff *= pow2( saturate( 1.0 - pow4( lightDistance / cutoffDistance ) ) );
	}
	return distanceFalloff;
}
float getSpotAttenuation( const in float coneCosine, const in float penumbraCosine, const in float angleCosine ) {
	return smoothstep( coneCosine, penumbraCosine, angleCosine );
}
#if NUM_DIR_LIGHTS > 0
	struct DirectionalLight {
		vec3 direction;
		vec3 color;
	};
	uniform DirectionalLight directionalLights[ NUM_DIR_LIGHTS ];
	void getDirectionalLightInfo( const in DirectionalLight directionalLight, out IncidentLight light ) {
		light.color = directionalLight.color;
		light.direction = directionalLight.direction;
		light.visible = true;
	}
#endif
#if NUM_POINT_LIGHTS > 0
	struct PointLight {
		vec3 position;
		vec3 color;
		float distance;
		float decay;
	};
	uniform PointLight pointLights[ NUM_POINT_LIGHTS ];
	void getPointLightInfo( const in PointLight pointLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = pointLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float lightDistance = length( lVector );
		light.color = pointLight.color;
		light.color *= getDistanceAttenuation( lightDistance, pointLight.distance, pointLight.decay );
		light.visible = ( light.color != vec3( 0.0 ) );
	}
#endif
#if NUM_SPOT_LIGHTS > 0
	struct SpotLight {
		vec3 position;
		vec3 direction;
		vec3 color;
		float distance;
		float decay;
		float coneCos;
		float penumbraCos;
	};
	uniform SpotLight spotLights[ NUM_SPOT_LIGHTS ];
	void getSpotLightInfo( const in SpotLight spotLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = spotLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float angleCos = dot( light.direction, spotLight.direction );
		float spotAttenuation = getSpotAttenuation( spotLight.coneCos, spotLight.penumbraCos, angleCos );
		if ( spotAttenuation > 0.0 ) {
			float lightDistance = length( lVector );
			light.color = spotLight.color * spotAttenuation;
			light.color *= getDistanceAttenuation( lightDistance, spotLight.distance, spotLight.decay );
			light.visible = ( light.color != vec3( 0.0 ) );
		} else {
			light.color = vec3( 0.0 );
			light.visible = false;
		}
	}
#endif
#if NUM_RECT_AREA_LIGHTS > 0
	struct RectAreaLight {
		vec3 color;
		vec3 position;
		vec3 halfWidth;
		vec3 halfHeight;
	};
	uniform sampler2D ltc_1;	uniform sampler2D ltc_2;
	uniform RectAreaLight rectAreaLights[ NUM_RECT_AREA_LIGHTS ];
#endif
#if NUM_HEMI_LIGHTS > 0
	struct HemisphereLight {
		vec3 direction;
		vec3 skyColor;
		vec3 groundColor;
	};
	uniform HemisphereLight hemisphereLights[ NUM_HEMI_LIGHTS ];
	vec3 getHemisphereLightIrradiance( const in HemisphereLight hemiLight, const in vec3 normal ) {
		float dotNL = dot( normal, hemiLight.direction );
		float hemiDiffuseWeight = 0.5 * dotNL + 0.5;
		vec3 irradiance = mix( hemiLight.groundColor, hemiLight.skyColor, hemiDiffuseWeight );
		return irradiance;
	}
#endif`,Rm=`#ifdef USE_ENVMAP
	vec3 getIBLIrradiance( const in vec3 normal ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * worldNormal, 1.0 );
			return PI * envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	vec3 getIBLRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 reflectVec = reflect( - viewDir, normal );
			reflectVec = normalize( mix( reflectVec, normal, roughness * roughness) );
			reflectVec = inverseTransformDirection( reflectVec, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * reflectVec, roughness );
			return envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	#ifdef USE_ANISOTROPY
		vec3 getIBLAnisotropyRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness, const in vec3 bitangent, const in float anisotropy ) {
			#ifdef ENVMAP_TYPE_CUBE_UV
				vec3 bentNormal = cross( bitangent, viewDir );
				bentNormal = normalize( cross( bentNormal, bitangent ) );
				bentNormal = normalize( mix( bentNormal, normal, pow2( pow2( 1.0 - anisotropy * ( 1.0 - roughness ) ) ) ) );
				return getIBLRadiance( viewDir, bentNormal, roughness );
			#else
				return vec3( 0.0 );
			#endif
		}
	#endif
#endif`,Pm=`ToonMaterial material;
material.diffuseColor = diffuseColor.rgb;`,Im=`varying vec3 vViewPosition;
struct ToonMaterial {
	vec3 diffuseColor;
};
void RE_Direct_Toon( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	vec3 irradiance = getGradientIrradiance( geometryNormal, directLight.direction ) * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Toon( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Toon
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Toon`,Nm=`BlinnPhongMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularColor = specular;
material.specularShininess = shininess;
material.specularStrength = specularStrength;`,Lm=`varying vec3 vViewPosition;
struct BlinnPhongMaterial {
	vec3 diffuseColor;
	vec3 specularColor;
	float specularShininess;
	float specularStrength;
};
void RE_Direct_BlinnPhong( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
	reflectedLight.directSpecular += irradiance * BRDF_BlinnPhong( directLight.direction, geometryViewDir, geometryNormal, material.specularColor, material.specularShininess ) * material.specularStrength;
}
void RE_IndirectDiffuse_BlinnPhong( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_BlinnPhong
#define RE_IndirectDiffuse		RE_IndirectDiffuse_BlinnPhong`,Dm=`PhysicalMaterial material;
material.diffuseColor = diffuseColor.rgb * ( 1.0 - metalnessFactor );
vec3 dxy = max( abs( dFdx( nonPerturbedNormal ) ), abs( dFdy( nonPerturbedNormal ) ) );
float geometryRoughness = max( max( dxy.x, dxy.y ), dxy.z );
material.roughness = max( roughnessFactor, 0.0525 );material.roughness += geometryRoughness;
material.roughness = min( material.roughness, 1.0 );
#ifdef IOR
	material.ior = ior;
	#ifdef USE_SPECULAR
		float specularIntensityFactor = specularIntensity;
		vec3 specularColorFactor = specularColor;
		#ifdef USE_SPECULAR_COLORMAP
			specularColorFactor *= texture2D( specularColorMap, vSpecularColorMapUv ).rgb;
		#endif
		#ifdef USE_SPECULAR_INTENSITYMAP
			specularIntensityFactor *= texture2D( specularIntensityMap, vSpecularIntensityMapUv ).a;
		#endif
		material.specularF90 = mix( specularIntensityFactor, 1.0, metalnessFactor );
	#else
		float specularIntensityFactor = 1.0;
		vec3 specularColorFactor = vec3( 1.0 );
		material.specularF90 = 1.0;
	#endif
	material.specularColor = mix( min( pow2( ( material.ior - 1.0 ) / ( material.ior + 1.0 ) ) * specularColorFactor, vec3( 1.0 ) ) * specularIntensityFactor, diffuseColor.rgb, metalnessFactor );
#else
	material.specularColor = mix( vec3( 0.04 ), diffuseColor.rgb, metalnessFactor );
	material.specularF90 = 1.0;
#endif
#ifdef USE_CLEARCOAT
	material.clearcoat = clearcoat;
	material.clearcoatRoughness = clearcoatRoughness;
	material.clearcoatF0 = vec3( 0.04 );
	material.clearcoatF90 = 1.0;
	#ifdef USE_CLEARCOATMAP
		material.clearcoat *= texture2D( clearcoatMap, vClearcoatMapUv ).x;
	#endif
	#ifdef USE_CLEARCOAT_ROUGHNESSMAP
		material.clearcoatRoughness *= texture2D( clearcoatRoughnessMap, vClearcoatRoughnessMapUv ).y;
	#endif
	material.clearcoat = saturate( material.clearcoat );	material.clearcoatRoughness = max( material.clearcoatRoughness, 0.0525 );
	material.clearcoatRoughness += geometryRoughness;
	material.clearcoatRoughness = min( material.clearcoatRoughness, 1.0 );
#endif
#ifdef USE_DISPERSION
	material.dispersion = dispersion;
#endif
#ifdef USE_IRIDESCENCE
	material.iridescence = iridescence;
	material.iridescenceIOR = iridescenceIOR;
	#ifdef USE_IRIDESCENCEMAP
		material.iridescence *= texture2D( iridescenceMap, vIridescenceMapUv ).r;
	#endif
	#ifdef USE_IRIDESCENCE_THICKNESSMAP
		material.iridescenceThickness = (iridescenceThicknessMaximum - iridescenceThicknessMinimum) * texture2D( iridescenceThicknessMap, vIridescenceThicknessMapUv ).g + iridescenceThicknessMinimum;
	#else
		material.iridescenceThickness = iridescenceThicknessMaximum;
	#endif
#endif
#ifdef USE_SHEEN
	material.sheenColor = sheenColor;
	#ifdef USE_SHEEN_COLORMAP
		material.sheenColor *= texture2D( sheenColorMap, vSheenColorMapUv ).rgb;
	#endif
	material.sheenRoughness = clamp( sheenRoughness, 0.07, 1.0 );
	#ifdef USE_SHEEN_ROUGHNESSMAP
		material.sheenRoughness *= texture2D( sheenRoughnessMap, vSheenRoughnessMapUv ).a;
	#endif
#endif
#ifdef USE_ANISOTROPY
	#ifdef USE_ANISOTROPYMAP
		mat2 anisotropyMat = mat2( anisotropyVector.x, anisotropyVector.y, - anisotropyVector.y, anisotropyVector.x );
		vec3 anisotropyPolar = texture2D( anisotropyMap, vAnisotropyMapUv ).rgb;
		vec2 anisotropyV = anisotropyMat * normalize( 2.0 * anisotropyPolar.rg - vec2( 1.0 ) ) * anisotropyPolar.b;
	#else
		vec2 anisotropyV = anisotropyVector;
	#endif
	material.anisotropy = length( anisotropyV );
	if( material.anisotropy == 0.0 ) {
		anisotropyV = vec2( 1.0, 0.0 );
	} else {
		anisotropyV /= material.anisotropy;
		material.anisotropy = saturate( material.anisotropy );
	}
	material.alphaT = mix( pow2( material.roughness ), 1.0, pow2( material.anisotropy ) );
	material.anisotropyT = tbn[ 0 ] * anisotropyV.x + tbn[ 1 ] * anisotropyV.y;
	material.anisotropyB = tbn[ 1 ] * anisotropyV.x - tbn[ 0 ] * anisotropyV.y;
#endif`,Fm=`struct PhysicalMaterial {
	vec3 diffuseColor;
	float roughness;
	vec3 specularColor;
	float specularF90;
	float dispersion;
	#ifdef USE_CLEARCOAT
		float clearcoat;
		float clearcoatRoughness;
		vec3 clearcoatF0;
		float clearcoatF90;
	#endif
	#ifdef USE_IRIDESCENCE
		float iridescence;
		float iridescenceIOR;
		float iridescenceThickness;
		vec3 iridescenceFresnel;
		vec3 iridescenceF0;
	#endif
	#ifdef USE_SHEEN
		vec3 sheenColor;
		float sheenRoughness;
	#endif
	#ifdef IOR
		float ior;
	#endif
	#ifdef USE_TRANSMISSION
		float transmission;
		float transmissionAlpha;
		float thickness;
		float attenuationDistance;
		vec3 attenuationColor;
	#endif
	#ifdef USE_ANISOTROPY
		float anisotropy;
		float alphaT;
		vec3 anisotropyT;
		vec3 anisotropyB;
	#endif
};
vec3 clearcoatSpecularDirect = vec3( 0.0 );
vec3 clearcoatSpecularIndirect = vec3( 0.0 );
vec3 sheenSpecularDirect = vec3( 0.0 );
vec3 sheenSpecularIndirect = vec3(0.0 );
vec3 Schlick_to_F0( const in vec3 f, const in float f90, const in float dotVH ) {
    float x = clamp( 1.0 - dotVH, 0.0, 1.0 );
    float x2 = x * x;
    float x5 = clamp( x * x2 * x2, 0.0, 0.9999 );
    return ( f - vec3( f90 ) * x5 ) / ( 1.0 - x5 );
}
float V_GGX_SmithCorrelated( const in float alpha, const in float dotNL, const in float dotNV ) {
	float a2 = pow2( alpha );
	float gv = dotNL * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNV ) );
	float gl = dotNV * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNL ) );
	return 0.5 / max( gv + gl, EPSILON );
}
float D_GGX( const in float alpha, const in float dotNH ) {
	float a2 = pow2( alpha );
	float denom = pow2( dotNH ) * ( a2 - 1.0 ) + 1.0;
	return RECIPROCAL_PI * a2 / pow2( denom );
}
#ifdef USE_ANISOTROPY
	float V_GGX_SmithCorrelated_Anisotropic( const in float alphaT, const in float alphaB, const in float dotTV, const in float dotBV, const in float dotTL, const in float dotBL, const in float dotNV, const in float dotNL ) {
		float gv = dotNL * length( vec3( alphaT * dotTV, alphaB * dotBV, dotNV ) );
		float gl = dotNV * length( vec3( alphaT * dotTL, alphaB * dotBL, dotNL ) );
		float v = 0.5 / ( gv + gl );
		return saturate(v);
	}
	float D_GGX_Anisotropic( const in float alphaT, const in float alphaB, const in float dotNH, const in float dotTH, const in float dotBH ) {
		float a2 = alphaT * alphaB;
		highp vec3 v = vec3( alphaB * dotTH, alphaT * dotBH, a2 * dotNH );
		highp float v2 = dot( v, v );
		float w2 = a2 / v2;
		return RECIPROCAL_PI * a2 * pow2 ( w2 );
	}
#endif
#ifdef USE_CLEARCOAT
	vec3 BRDF_GGX_Clearcoat( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material) {
		vec3 f0 = material.clearcoatF0;
		float f90 = material.clearcoatF90;
		float roughness = material.clearcoatRoughness;
		float alpha = pow2( roughness );
		vec3 halfDir = normalize( lightDir + viewDir );
		float dotNL = saturate( dot( normal, lightDir ) );
		float dotNV = saturate( dot( normal, viewDir ) );
		float dotNH = saturate( dot( normal, halfDir ) );
		float dotVH = saturate( dot( viewDir, halfDir ) );
		vec3 F = F_Schlick( f0, f90, dotVH );
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
		return F * ( V * D );
	}
#endif
vec3 BRDF_GGX( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material ) {
	vec3 f0 = material.specularColor;
	float f90 = material.specularF90;
	float roughness = material.roughness;
	float alpha = pow2( roughness );
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( f0, f90, dotVH );
	#ifdef USE_IRIDESCENCE
		F = mix( F, material.iridescenceFresnel, material.iridescence );
	#endif
	#ifdef USE_ANISOTROPY
		float dotTL = dot( material.anisotropyT, lightDir );
		float dotTV = dot( material.anisotropyT, viewDir );
		float dotTH = dot( material.anisotropyT, halfDir );
		float dotBL = dot( material.anisotropyB, lightDir );
		float dotBV = dot( material.anisotropyB, viewDir );
		float dotBH = dot( material.anisotropyB, halfDir );
		float V = V_GGX_SmithCorrelated_Anisotropic( material.alphaT, alpha, dotTV, dotBV, dotTL, dotBL, dotNV, dotNL );
		float D = D_GGX_Anisotropic( material.alphaT, alpha, dotNH, dotTH, dotBH );
	#else
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
	#endif
	return F * ( V * D );
}
vec2 LTC_Uv( const in vec3 N, const in vec3 V, const in float roughness ) {
	const float LUT_SIZE = 64.0;
	const float LUT_SCALE = ( LUT_SIZE - 1.0 ) / LUT_SIZE;
	const float LUT_BIAS = 0.5 / LUT_SIZE;
	float dotNV = saturate( dot( N, V ) );
	vec2 uv = vec2( roughness, sqrt( 1.0 - dotNV ) );
	uv = uv * LUT_SCALE + LUT_BIAS;
	return uv;
}
float LTC_ClippedSphereFormFactor( const in vec3 f ) {
	float l = length( f );
	return max( ( l * l + f.z ) / ( l + 1.0 ), 0.0 );
}
vec3 LTC_EdgeVectorFormFactor( const in vec3 v1, const in vec3 v2 ) {
	float x = dot( v1, v2 );
	float y = abs( x );
	float a = 0.8543985 + ( 0.4965155 + 0.0145206 * y ) * y;
	float b = 3.4175940 + ( 4.1616724 + y ) * y;
	float v = a / b;
	float theta_sintheta = ( x > 0.0 ) ? v : 0.5 * inversesqrt( max( 1.0 - x * x, 1e-7 ) ) - v;
	return cross( v1, v2 ) * theta_sintheta;
}
vec3 LTC_Evaluate( const in vec3 N, const in vec3 V, const in vec3 P, const in mat3 mInv, const in vec3 rectCoords[ 4 ] ) {
	vec3 v1 = rectCoords[ 1 ] - rectCoords[ 0 ];
	vec3 v2 = rectCoords[ 3 ] - rectCoords[ 0 ];
	vec3 lightNormal = cross( v1, v2 );
	if( dot( lightNormal, P - rectCoords[ 0 ] ) < 0.0 ) return vec3( 0.0 );
	vec3 T1, T2;
	T1 = normalize( V - N * dot( V, N ) );
	T2 = - cross( N, T1 );
	mat3 mat = mInv * transposeMat3( mat3( T1, T2, N ) );
	vec3 coords[ 4 ];
	coords[ 0 ] = mat * ( rectCoords[ 0 ] - P );
	coords[ 1 ] = mat * ( rectCoords[ 1 ] - P );
	coords[ 2 ] = mat * ( rectCoords[ 2 ] - P );
	coords[ 3 ] = mat * ( rectCoords[ 3 ] - P );
	coords[ 0 ] = normalize( coords[ 0 ] );
	coords[ 1 ] = normalize( coords[ 1 ] );
	coords[ 2 ] = normalize( coords[ 2 ] );
	coords[ 3 ] = normalize( coords[ 3 ] );
	vec3 vectorFormFactor = vec3( 0.0 );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 0 ], coords[ 1 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 1 ], coords[ 2 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 2 ], coords[ 3 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 3 ], coords[ 0 ] );
	float result = LTC_ClippedSphereFormFactor( vectorFormFactor );
	return vec3( result );
}
#if defined( USE_SHEEN )
float D_Charlie( float roughness, float dotNH ) {
	float alpha = pow2( roughness );
	float invAlpha = 1.0 / alpha;
	float cos2h = dotNH * dotNH;
	float sin2h = max( 1.0 - cos2h, 0.0078125 );
	return ( 2.0 + invAlpha ) * pow( sin2h, invAlpha * 0.5 ) / ( 2.0 * PI );
}
float V_Neubelt( float dotNV, float dotNL ) {
	return saturate( 1.0 / ( 4.0 * ( dotNL + dotNV - dotNL * dotNV ) ) );
}
vec3 BRDF_Sheen( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, vec3 sheenColor, const in float sheenRoughness ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float D = D_Charlie( sheenRoughness, dotNH );
	float V = V_Neubelt( dotNV, dotNL );
	return sheenColor * ( D * V );
}
#endif
float IBLSheenBRDF( const in vec3 normal, const in vec3 viewDir, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	float r2 = roughness * roughness;
	float a = roughness < 0.25 ? -339.2 * r2 + 161.4 * roughness - 25.9 : -8.48 * r2 + 14.3 * roughness - 9.95;
	float b = roughness < 0.25 ? 44.0 * r2 - 23.7 * roughness + 3.26 : 1.97 * r2 - 3.27 * roughness + 0.72;
	float DG = exp( a * dotNV + b ) + ( roughness < 0.25 ? 0.0 : 0.1 * ( roughness - 0.25 ) );
	return saturate( DG * RECIPROCAL_PI );
}
vec2 DFGApprox( const in vec3 normal, const in vec3 viewDir, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	const vec4 c0 = vec4( - 1, - 0.0275, - 0.572, 0.022 );
	const vec4 c1 = vec4( 1, 0.0425, 1.04, - 0.04 );
	vec4 r = roughness * c0 + c1;
	float a004 = min( r.x * r.x, exp2( - 9.28 * dotNV ) ) * r.x + r.y;
	vec2 fab = vec2( - 1.04, 1.04 ) * a004 + r.zw;
	return fab;
}
vec3 EnvironmentBRDF( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float roughness ) {
	vec2 fab = DFGApprox( normal, viewDir, roughness );
	return specularColor * fab.x + specularF90 * fab.y;
}
#ifdef USE_IRIDESCENCE
void computeMultiscatteringIridescence( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float iridescence, const in vec3 iridescenceF0, const in float roughness, inout vec3 singleScatter, inout vec3 multiScatter ) {
#else
void computeMultiscattering( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float roughness, inout vec3 singleScatter, inout vec3 multiScatter ) {
#endif
	vec2 fab = DFGApprox( normal, viewDir, roughness );
	#ifdef USE_IRIDESCENCE
		vec3 Fr = mix( specularColor, iridescenceF0, iridescence );
	#else
		vec3 Fr = specularColor;
	#endif
	vec3 FssEss = Fr * fab.x + specularF90 * fab.y;
	float Ess = fab.x + fab.y;
	float Ems = 1.0 - Ess;
	vec3 Favg = Fr + ( 1.0 - Fr ) * 0.047619;	vec3 Fms = FssEss * Favg / ( 1.0 - Ems * Favg );
	singleScatter += FssEss;
	multiScatter += Fms * Ems;
}
#if NUM_RECT_AREA_LIGHTS > 0
	void RE_Direct_RectArea_Physical( const in RectAreaLight rectAreaLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
		vec3 normal = geometryNormal;
		vec3 viewDir = geometryViewDir;
		vec3 position = geometryPosition;
		vec3 lightPos = rectAreaLight.position;
		vec3 halfWidth = rectAreaLight.halfWidth;
		vec3 halfHeight = rectAreaLight.halfHeight;
		vec3 lightColor = rectAreaLight.color;
		float roughness = material.roughness;
		vec3 rectCoords[ 4 ];
		rectCoords[ 0 ] = lightPos + halfWidth - halfHeight;		rectCoords[ 1 ] = lightPos - halfWidth - halfHeight;
		rectCoords[ 2 ] = lightPos - halfWidth + halfHeight;
		rectCoords[ 3 ] = lightPos + halfWidth + halfHeight;
		vec2 uv = LTC_Uv( normal, viewDir, roughness );
		vec4 t1 = texture2D( ltc_1, uv );
		vec4 t2 = texture2D( ltc_2, uv );
		mat3 mInv = mat3(
			vec3( t1.x, 0, t1.y ),
			vec3(    0, 1,    0 ),
			vec3( t1.z, 0, t1.w )
		);
		vec3 fresnel = ( material.specularColor * t2.x + ( vec3( 1.0 ) - material.specularColor ) * t2.y );
		reflectedLight.directSpecular += lightColor * fresnel * LTC_Evaluate( normal, viewDir, position, mInv, rectCoords );
		reflectedLight.directDiffuse += lightColor * material.diffuseColor * LTC_Evaluate( normal, viewDir, position, mat3( 1.0 ), rectCoords );
	}
#endif
void RE_Direct_Physical( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	#ifdef USE_CLEARCOAT
		float dotNLcc = saturate( dot( geometryClearcoatNormal, directLight.direction ) );
		vec3 ccIrradiance = dotNLcc * directLight.color;
		clearcoatSpecularDirect += ccIrradiance * BRDF_GGX_Clearcoat( directLight.direction, geometryViewDir, geometryClearcoatNormal, material );
	#endif
	#ifdef USE_SHEEN
		sheenSpecularDirect += irradiance * BRDF_Sheen( directLight.direction, geometryViewDir, geometryNormal, material.sheenColor, material.sheenRoughness );
	#endif
	reflectedLight.directSpecular += irradiance * BRDF_GGX( directLight.direction, geometryViewDir, geometryNormal, material );
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Physical( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectSpecular_Physical( const in vec3 radiance, const in vec3 irradiance, const in vec3 clearcoatRadiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight) {
	#ifdef USE_CLEARCOAT
		clearcoatSpecularIndirect += clearcoatRadiance * EnvironmentBRDF( geometryClearcoatNormal, geometryViewDir, material.clearcoatF0, material.clearcoatF90, material.clearcoatRoughness );
	#endif
	#ifdef USE_SHEEN
		sheenSpecularIndirect += irradiance * material.sheenColor * IBLSheenBRDF( geometryNormal, geometryViewDir, material.sheenRoughness );
	#endif
	vec3 singleScattering = vec3( 0.0 );
	vec3 multiScattering = vec3( 0.0 );
	vec3 cosineWeightedIrradiance = irradiance * RECIPROCAL_PI;
	#ifdef USE_IRIDESCENCE
		computeMultiscatteringIridescence( geometryNormal, geometryViewDir, material.specularColor, material.specularF90, material.iridescence, material.iridescenceFresnel, material.roughness, singleScattering, multiScattering );
	#else
		computeMultiscattering( geometryNormal, geometryViewDir, material.specularColor, material.specularF90, material.roughness, singleScattering, multiScattering );
	#endif
	vec3 totalScattering = singleScattering + multiScattering;
	vec3 diffuse = material.diffuseColor * ( 1.0 - max( max( totalScattering.r, totalScattering.g ), totalScattering.b ) );
	reflectedLight.indirectSpecular += radiance * singleScattering;
	reflectedLight.indirectSpecular += multiScattering * cosineWeightedIrradiance;
	reflectedLight.indirectDiffuse += diffuse * cosineWeightedIrradiance;
}
#define RE_Direct				RE_Direct_Physical
#define RE_Direct_RectArea		RE_Direct_RectArea_Physical
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Physical
#define RE_IndirectSpecular		RE_IndirectSpecular_Physical
float computeSpecularOcclusion( const in float dotNV, const in float ambientOcclusion, const in float roughness ) {
	return saturate( pow( dotNV + ambientOcclusion, exp2( - 16.0 * roughness - 1.0 ) ) - 1.0 + ambientOcclusion );
}`,Bm=`
vec3 geometryPosition = - vViewPosition;
vec3 geometryNormal = normal;
vec3 geometryViewDir = ( isOrthographic ) ? vec3( 0, 0, 1 ) : normalize( vViewPosition );
vec3 geometryClearcoatNormal = vec3( 0.0 );
#ifdef USE_CLEARCOAT
	geometryClearcoatNormal = clearcoatNormal;
#endif
#ifdef USE_IRIDESCENCE
	float dotNVi = saturate( dot( normal, geometryViewDir ) );
	if ( material.iridescenceThickness == 0.0 ) {
		material.iridescence = 0.0;
	} else {
		material.iridescence = saturate( material.iridescence );
	}
	if ( material.iridescence > 0.0 ) {
		material.iridescenceFresnel = evalIridescence( 1.0, material.iridescenceIOR, dotNVi, material.iridescenceThickness, material.specularColor );
		material.iridescenceF0 = Schlick_to_F0( material.iridescenceFresnel, 1.0, dotNVi );
	}
#endif
IncidentLight directLight;
#if ( NUM_POINT_LIGHTS > 0 ) && defined( RE_Direct )
	PointLight pointLight;
	#if defined( USE_SHADOWMAP ) && NUM_POINT_LIGHT_SHADOWS > 0
	PointLightShadow pointLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHTS; i ++ ) {
		pointLight = pointLights[ i ];
		getPointLightInfo( pointLight, geometryPosition, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_POINT_LIGHT_SHADOWS )
		pointLightShadow = pointLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getPointShadow( pointShadowMap[ i ], pointLightShadow.shadowMapSize, pointLightShadow.shadowIntensity, pointLightShadow.shadowBias, pointLightShadow.shadowRadius, vPointShadowCoord[ i ], pointLightShadow.shadowCameraNear, pointLightShadow.shadowCameraFar ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_SPOT_LIGHTS > 0 ) && defined( RE_Direct )
	SpotLight spotLight;
	vec4 spotColor;
	vec3 spotLightCoord;
	bool inSpotLightMap;
	#if defined( USE_SHADOWMAP ) && NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHTS; i ++ ) {
		spotLight = spotLights[ i ];
		getSpotLightInfo( spotLight, geometryPosition, directLight );
		#if ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#define SPOT_LIGHT_MAP_INDEX UNROLLED_LOOP_INDEX
		#elif ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		#define SPOT_LIGHT_MAP_INDEX NUM_SPOT_LIGHT_MAPS
		#else
		#define SPOT_LIGHT_MAP_INDEX ( UNROLLED_LOOP_INDEX - NUM_SPOT_LIGHT_SHADOWS + NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#endif
		#if ( SPOT_LIGHT_MAP_INDEX < NUM_SPOT_LIGHT_MAPS )
			spotLightCoord = vSpotLightCoord[ i ].xyz / vSpotLightCoord[ i ].w;
			inSpotLightMap = all( lessThan( abs( spotLightCoord * 2. - 1. ), vec3( 1.0 ) ) );
			spotColor = texture2D( spotLightMap[ SPOT_LIGHT_MAP_INDEX ], spotLightCoord.xy );
			directLight.color = inSpotLightMap ? directLight.color * spotColor.rgb : directLight.color;
		#endif
		#undef SPOT_LIGHT_MAP_INDEX
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		spotLightShadow = spotLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( spotShadowMap[ i ], spotLightShadow.shadowMapSize, spotLightShadow.shadowIntensity, spotLightShadow.shadowBias, spotLightShadow.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_DIR_LIGHTS > 0 ) && defined( RE_Direct )
	DirectionalLight directionalLight;
	#if defined( USE_SHADOWMAP ) && NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHTS; i ++ ) {
		directionalLight = directionalLights[ i ];
		getDirectionalLightInfo( directionalLight, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_DIR_LIGHT_SHADOWS )
		directionalLightShadow = directionalLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( directionalShadowMap[ i ], directionalLightShadow.shadowMapSize, directionalLightShadow.shadowIntensity, directionalLightShadow.shadowBias, directionalLightShadow.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_RECT_AREA_LIGHTS > 0 ) && defined( RE_Direct_RectArea )
	RectAreaLight rectAreaLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_RECT_AREA_LIGHTS; i ++ ) {
		rectAreaLight = rectAreaLights[ i ];
		RE_Direct_RectArea( rectAreaLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if defined( RE_IndirectDiffuse )
	vec3 iblIrradiance = vec3( 0.0 );
	vec3 irradiance = getAmbientLightIrradiance( ambientLightColor );
	#if defined( USE_LIGHT_PROBES )
		irradiance += getLightProbeIrradiance( lightProbe, geometryNormal );
	#endif
	#if ( NUM_HEMI_LIGHTS > 0 )
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_HEMI_LIGHTS; i ++ ) {
			irradiance += getHemisphereLightIrradiance( hemisphereLights[ i ], geometryNormal );
		}
		#pragma unroll_loop_end
	#endif
#endif
#if defined( RE_IndirectSpecular )
	vec3 radiance = vec3( 0.0 );
	vec3 clearcoatRadiance = vec3( 0.0 );
#endif`,Um=`#if defined( RE_IndirectDiffuse )
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		vec3 lightMapIrradiance = lightMapTexel.rgb * lightMapIntensity;
		irradiance += lightMapIrradiance;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD ) && defined( ENVMAP_TYPE_CUBE_UV )
		iblIrradiance += getIBLIrradiance( geometryNormal );
	#endif
#endif
#if defined( USE_ENVMAP ) && defined( RE_IndirectSpecular )
	#ifdef USE_ANISOTROPY
		radiance += getIBLAnisotropyRadiance( geometryViewDir, geometryNormal, material.roughness, material.anisotropyB, material.anisotropy );
	#else
		radiance += getIBLRadiance( geometryViewDir, geometryNormal, material.roughness );
	#endif
	#ifdef USE_CLEARCOAT
		clearcoatRadiance += getIBLRadiance( geometryViewDir, geometryClearcoatNormal, material.clearcoatRoughness );
	#endif
#endif`,Om=`#if defined( RE_IndirectDiffuse )
	RE_IndirectDiffuse( irradiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif
#if defined( RE_IndirectSpecular )
	RE_IndirectSpecular( radiance, iblIrradiance, clearcoatRadiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif`,zm=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;
#endif`,km=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,Vm=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,Hm=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	vFragDepth = 1.0 + gl_Position.w;
	vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );
#endif`,Gm=`#ifdef USE_MAP
	vec4 sampledDiffuseColor = texture2D( map, vMapUv );
	#ifdef DECODE_VIDEO_TEXTURE
		sampledDiffuseColor = sRGBTransferEOTF( sampledDiffuseColor );
	#endif
	diffuseColor *= sampledDiffuseColor;
#endif`,Wm=`#ifdef USE_MAP
	uniform sampler2D map;
#endif`,qm=`#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
	#if defined( USE_POINTS_UV )
		vec2 uv = vUv;
	#else
		vec2 uv = ( uvTransform * vec3( gl_PointCoord.x, 1.0 - gl_PointCoord.y, 1 ) ).xy;
	#endif
#endif
#ifdef USE_MAP
	diffuseColor *= texture2D( map, uv );
#endif
#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, uv ).g;
#endif`,Xm=`#if defined( USE_POINTS_UV )
	varying vec2 vUv;
#else
	#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
		uniform mat3 uvTransform;
	#endif
#endif
#ifdef USE_MAP
	uniform sampler2D map;
#endif
#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,$m=`float metalnessFactor = metalness;
#ifdef USE_METALNESSMAP
	vec4 texelMetalness = texture2D( metalnessMap, vMetalnessMapUv );
	metalnessFactor *= texelMetalness.b;
#endif`,Ym=`#ifdef USE_METALNESSMAP
	uniform sampler2D metalnessMap;
#endif`,Zm=`#ifdef USE_INSTANCING_MORPH
	float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;
	}
#endif`,Km=`#if defined( USE_MORPHCOLORS )
	vColor *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		#if defined( USE_COLOR_ALPHA )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];
		#elif defined( USE_COLOR )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];
		#endif
	}
#endif`,Jm=`#ifdef USE_MORPHNORMALS
	objectNormal *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) objectNormal += getMorph( gl_VertexID, i, 1 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,jm=`#ifdef USE_MORPHTARGETS
	#ifndef USE_INSTANCING_MORPH
		uniform float morphTargetBaseInfluence;
		uniform float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	#endif
	uniform sampler2DArray morphTargetsTexture;
	uniform ivec2 morphTargetsTextureSize;
	vec4 getMorph( const in int vertexIndex, const in int morphTargetIndex, const in int offset ) {
		int texelIndex = vertexIndex * MORPHTARGETS_TEXTURE_STRIDE + offset;
		int y = texelIndex / morphTargetsTextureSize.x;
		int x = texelIndex - y * morphTargetsTextureSize.x;
		ivec3 morphUV = ivec3( x, y, morphTargetIndex );
		return texelFetch( morphTargetsTexture, morphUV, 0 );
	}
#endif`,Qm=`#ifdef USE_MORPHTARGETS
	transformed *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,eg=`float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
#ifdef FLAT_SHADED
	vec3 fdx = dFdx( vViewPosition );
	vec3 fdy = dFdy( vViewPosition );
	vec3 normal = normalize( cross( fdx, fdy ) );
#else
	vec3 normal = normalize( vNormal );
	#ifdef DOUBLE_SIDED
		normal *= faceDirection;
	#endif
#endif
#if defined( USE_NORMALMAP_TANGENTSPACE ) || defined( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY )
	#ifdef USE_TANGENT
		mat3 tbn = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn = getTangentFrame( - vViewPosition, normal,
		#if defined( USE_NORMALMAP )
			vNormalMapUv
		#elif defined( USE_CLEARCOAT_NORMALMAP )
			vClearcoatNormalMapUv
		#else
			vUv
		#endif
		);
	#endif
	#if defined( DOUBLE_SIDED ) && ! defined( FLAT_SHADED )
		tbn[0] *= faceDirection;
		tbn[1] *= faceDirection;
	#endif
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	#ifdef USE_TANGENT
		mat3 tbn2 = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn2 = getTangentFrame( - vViewPosition, normal, vClearcoatNormalMapUv );
	#endif
	#if defined( DOUBLE_SIDED ) && ! defined( FLAT_SHADED )
		tbn2[0] *= faceDirection;
		tbn2[1] *= faceDirection;
	#endif
#endif
vec3 nonPerturbedNormal = normal;`,tg=`#ifdef USE_NORMALMAP_OBJECTSPACE
	normal = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	#ifdef FLIP_SIDED
		normal = - normal;
	#endif
	#ifdef DOUBLE_SIDED
		normal = normal * faceDirection;
	#endif
	normal = normalize( normalMatrix * normal );
#elif defined( USE_NORMALMAP_TANGENTSPACE )
	vec3 mapN = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	mapN.xy *= normalScale;
	normal = normalize( tbn * mapN );
#elif defined( USE_BUMPMAP )
	normal = perturbNormalArb( - vViewPosition, normal, dHdxy_fwd(), faceDirection );
#endif`,ng=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,ig=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,sg=`#ifndef FLAT_SHADED
	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
	#endif
#endif`,rg=`#ifdef USE_NORMALMAP
	uniform sampler2D normalMap;
	uniform vec2 normalScale;
#endif
#ifdef USE_NORMALMAP_OBJECTSPACE
	uniform mat3 normalMatrix;
#endif
#if ! defined ( USE_TANGENT ) && ( defined ( USE_NORMALMAP_TANGENTSPACE ) || defined ( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY ) )
	mat3 getTangentFrame( vec3 eye_pos, vec3 surf_norm, vec2 uv ) {
		vec3 q0 = dFdx( eye_pos.xyz );
		vec3 q1 = dFdy( eye_pos.xyz );
		vec2 st0 = dFdx( uv.st );
		vec2 st1 = dFdy( uv.st );
		vec3 N = surf_norm;
		vec3 q1perp = cross( q1, N );
		vec3 q0perp = cross( N, q0 );
		vec3 T = q1perp * st0.x + q0perp * st1.x;
		vec3 B = q1perp * st0.y + q0perp * st1.y;
		float det = max( dot( T, T ), dot( B, B ) );
		float scale = ( det == 0.0 ) ? 0.0 : inversesqrt( det );
		return mat3( T * scale, B * scale, N );
	}
#endif`,og=`#ifdef USE_CLEARCOAT
	vec3 clearcoatNormal = nonPerturbedNormal;
#endif`,ag=`#ifdef USE_CLEARCOAT_NORMALMAP
	vec3 clearcoatMapN = texture2D( clearcoatNormalMap, vClearcoatNormalMapUv ).xyz * 2.0 - 1.0;
	clearcoatMapN.xy *= clearcoatNormalScale;
	clearcoatNormal = normalize( tbn2 * clearcoatMapN );
#endif`,lg=`#ifdef USE_CLEARCOATMAP
	uniform sampler2D clearcoatMap;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform sampler2D clearcoatNormalMap;
	uniform vec2 clearcoatNormalScale;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform sampler2D clearcoatRoughnessMap;
#endif`,cg=`#ifdef USE_IRIDESCENCEMAP
	uniform sampler2D iridescenceMap;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform sampler2D iridescenceThicknessMap;
#endif`,hg=`#ifdef OPAQUE
diffuseColor.a = 1.0;
#endif
#ifdef USE_TRANSMISSION
diffuseColor.a *= material.transmissionAlpha;
#endif
gl_FragColor = vec4( outgoingLight, diffuseColor.a );`,ug=`vec3 packNormalToRGB( const in vec3 normal ) {
	return normalize( normal ) * 0.5 + 0.5;
}
vec3 unpackRGBToNormal( const in vec3 rgb ) {
	return 2.0 * rgb.xyz - 1.0;
}
const float PackUpscale = 256. / 255.;const float UnpackDownscale = 255. / 256.;const float ShiftRight8 = 1. / 256.;
const float Inv255 = 1. / 255.;
const vec4 PackFactors = vec4( 1.0, 256.0, 256.0 * 256.0, 256.0 * 256.0 * 256.0 );
const vec2 UnpackFactors2 = vec2( UnpackDownscale, 1.0 / PackFactors.g );
const vec3 UnpackFactors3 = vec3( UnpackDownscale / PackFactors.rg, 1.0 / PackFactors.b );
const vec4 UnpackFactors4 = vec4( UnpackDownscale / PackFactors.rgb, 1.0 / PackFactors.a );
vec4 packDepthToRGBA( const in float v ) {
	if( v <= 0.0 )
		return vec4( 0., 0., 0., 0. );
	if( v >= 1.0 )
		return vec4( 1., 1., 1., 1. );
	float vuf;
	float af = modf( v * PackFactors.a, vuf );
	float bf = modf( vuf * ShiftRight8, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec4( vuf * Inv255, gf * PackUpscale, bf * PackUpscale, af );
}
vec3 packDepthToRGB( const in float v ) {
	if( v <= 0.0 )
		return vec3( 0., 0., 0. );
	if( v >= 1.0 )
		return vec3( 1., 1., 1. );
	float vuf;
	float bf = modf( v * PackFactors.b, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec3( vuf * Inv255, gf * PackUpscale, bf );
}
vec2 packDepthToRG( const in float v ) {
	if( v <= 0.0 )
		return vec2( 0., 0. );
	if( v >= 1.0 )
		return vec2( 1., 1. );
	float vuf;
	float gf = modf( v * 256., vuf );
	return vec2( vuf * Inv255, gf );
}
float unpackRGBAToDepth( const in vec4 v ) {
	return dot( v, UnpackFactors4 );
}
float unpackRGBToDepth( const in vec3 v ) {
	return dot( v, UnpackFactors3 );
}
float unpackRGToDepth( const in vec2 v ) {
	return v.r * UnpackFactors2.r + v.g * UnpackFactors2.g;
}
vec4 pack2HalfToRGBA( const in vec2 v ) {
	vec4 r = vec4( v.x, fract( v.x * 255.0 ), v.y, fract( v.y * 255.0 ) );
	return vec4( r.x - r.y / 255.0, r.y, r.z - r.w / 255.0, r.w );
}
vec2 unpackRGBATo2Half( const in vec4 v ) {
	return vec2( v.x + ( v.y / 255.0 ), v.z + ( v.w / 255.0 ) );
}
float viewZToOrthographicDepth( const in float viewZ, const in float near, const in float far ) {
	return ( viewZ + near ) / ( near - far );
}
float orthographicDepthToViewZ( const in float depth, const in float near, const in float far ) {
	return depth * ( near - far ) - near;
}
float viewZToPerspectiveDepth( const in float viewZ, const in float near, const in float far ) {
	return ( ( near + viewZ ) * far ) / ( ( far - near ) * viewZ );
}
float perspectiveDepthToViewZ( const in float depth, const in float near, const in float far ) {
	return ( near * far ) / ( ( far - near ) * depth - far );
}`,fg=`#ifdef PREMULTIPLIED_ALPHA
	gl_FragColor.rgb *= gl_FragColor.a;
#endif`,dg=`vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
	mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
	mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
gl_Position = projectionMatrix * mvPosition;`,pg=`#ifdef DITHERING
	gl_FragColor.rgb = dithering( gl_FragColor.rgb );
#endif`,mg=`#ifdef DITHERING
	vec3 dithering( vec3 color ) {
		float grid_position = rand( gl_FragCoord.xy );
		vec3 dither_shift_RGB = vec3( 0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0 );
		dither_shift_RGB = mix( 2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position );
		return color + dither_shift_RGB;
	}
#endif`,gg=`float roughnessFactor = roughness;
#ifdef USE_ROUGHNESSMAP
	vec4 texelRoughness = texture2D( roughnessMap, vRoughnessMapUv );
	roughnessFactor *= texelRoughness.g;
#endif`,vg=`#ifdef USE_ROUGHNESSMAP
	uniform sampler2D roughnessMap;
#endif`,xg=`#if NUM_SPOT_LIGHT_COORDS > 0
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#if NUM_SPOT_LIGHT_MAPS > 0
	uniform sampler2D spotLightMap[ NUM_SPOT_LIGHT_MAPS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform sampler2D directionalShadowMap[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		uniform sampler2D spotShadowMap[ NUM_SPOT_LIGHT_SHADOWS ];
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		uniform sampler2D pointShadowMap[ NUM_POINT_LIGHT_SHADOWS ];
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
	float texture2DCompare( sampler2D depths, vec2 uv, float compare ) {
		float depth = unpackRGBAToDepth( texture2D( depths, uv ) );
		#ifdef USE_REVERSED_DEPTH_BUFFER
			return step( depth, compare );
		#else
			return step( compare, depth );
		#endif
	}
	vec2 texture2DDistribution( sampler2D shadow, vec2 uv ) {
		return unpackRGBATo2Half( texture2D( shadow, uv ) );
	}
	float VSMShadow( sampler2D shadow, vec2 uv, float compare ) {
		float occlusion = 1.0;
		vec2 distribution = texture2DDistribution( shadow, uv );
		#ifdef USE_REVERSED_DEPTH_BUFFER
			float hard_shadow = step( distribution.x, compare );
		#else
			float hard_shadow = step( compare, distribution.x );
		#endif
		if ( hard_shadow != 1.0 ) {
			float distance = compare - distribution.x;
			float variance = max( 0.00000, distribution.y * distribution.y );
			float softness_probability = variance / (variance + distance * distance );			softness_probability = clamp( ( softness_probability - 0.3 ) / ( 0.95 - 0.3 ), 0.0, 1.0 );			occlusion = clamp( max( hard_shadow, softness_probability ), 0.0, 1.0 );
		}
		return occlusion;
	}
	float getShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord ) {
		float shadow = 1.0;
		shadowCoord.xyz /= shadowCoord.w;
		shadowCoord.z += shadowBias;
		bool inFrustum = shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0;
		bool frustumTest = inFrustum && shadowCoord.z <= 1.0;
		if ( frustumTest ) {
		#if defined( SHADOWMAP_TYPE_PCF )
			vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
			float dx0 = - texelSize.x * shadowRadius;
			float dy0 = - texelSize.y * shadowRadius;
			float dx1 = + texelSize.x * shadowRadius;
			float dy1 = + texelSize.y * shadowRadius;
			float dx2 = dx0 / 2.0;
			float dy2 = dy0 / 2.0;
			float dx3 = dx1 / 2.0;
			float dy3 = dy1 / 2.0;
			shadow = (
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy, shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, dy1 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy1 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, dy1 ), shadowCoord.z )
			) * ( 1.0 / 17.0 );
		#elif defined( SHADOWMAP_TYPE_PCF_SOFT )
			vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
			float dx = texelSize.x;
			float dy = texelSize.y;
			vec2 uv = shadowCoord.xy;
			vec2 f = fract( uv * shadowMapSize + 0.5 );
			uv -= f * texelSize;
			shadow = (
				texture2DCompare( shadowMap, uv, shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + vec2( dx, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + vec2( 0.0, dy ), shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + texelSize, shadowCoord.z ) +
				mix( texture2DCompare( shadowMap, uv + vec2( -dx, 0.0 ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, 0.0 ), shadowCoord.z ),
					 f.x ) +
				mix( texture2DCompare( shadowMap, uv + vec2( -dx, dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, dy ), shadowCoord.z ),
					 f.x ) +
				mix( texture2DCompare( shadowMap, uv + vec2( 0.0, -dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 0.0, 2.0 * dy ), shadowCoord.z ),
					 f.y ) +
				mix( texture2DCompare( shadowMap, uv + vec2( dx, -dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( dx, 2.0 * dy ), shadowCoord.z ),
					 f.y ) +
				mix( mix( texture2DCompare( shadowMap, uv + vec2( -dx, -dy ), shadowCoord.z ),
						  texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, -dy ), shadowCoord.z ),
						  f.x ),
					 mix( texture2DCompare( shadowMap, uv + vec2( -dx, 2.0 * dy ), shadowCoord.z ),
						  texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, 2.0 * dy ), shadowCoord.z ),
						  f.x ),
					 f.y )
			) * ( 1.0 / 9.0 );
		#elif defined( SHADOWMAP_TYPE_VSM )
			shadow = VSMShadow( shadowMap, shadowCoord.xy, shadowCoord.z );
		#else
			shadow = texture2DCompare( shadowMap, shadowCoord.xy, shadowCoord.z );
		#endif
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
	vec2 cubeToUV( vec3 v, float texelSizeY ) {
		vec3 absV = abs( v );
		float scaleToCube = 1.0 / max( absV.x, max( absV.y, absV.z ) );
		absV *= scaleToCube;
		v *= scaleToCube * ( 1.0 - 2.0 * texelSizeY );
		vec2 planar = v.xy;
		float almostATexel = 1.5 * texelSizeY;
		float almostOne = 1.0 - almostATexel;
		if ( absV.z >= almostOne ) {
			if ( v.z > 0.0 )
				planar.x = 4.0 - v.x;
		} else if ( absV.x >= almostOne ) {
			float signX = sign( v.x );
			planar.x = v.z * signX + 2.0 * signX;
		} else if ( absV.y >= almostOne ) {
			float signY = sign( v.y );
			planar.x = v.x + 2.0 * signY + 2.0;
			planar.y = v.z * signY - 2.0;
		}
		return vec2( 0.125, 0.25 ) * planar + vec2( 0.375, 0.75 );
	}
	float getPointShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord, float shadowCameraNear, float shadowCameraFar ) {
		float shadow = 1.0;
		vec3 lightToPosition = shadowCoord.xyz;
		
		float lightToPositionLength = length( lightToPosition );
		if ( lightToPositionLength - shadowCameraFar <= 0.0 && lightToPositionLength - shadowCameraNear >= 0.0 ) {
			float dp = ( lightToPositionLength - shadowCameraNear ) / ( shadowCameraFar - shadowCameraNear );			dp += shadowBias;
			vec3 bd3D = normalize( lightToPosition );
			vec2 texelSize = vec2( 1.0 ) / ( shadowMapSize * vec2( 4.0, 2.0 ) );
			#if defined( SHADOWMAP_TYPE_PCF ) || defined( SHADOWMAP_TYPE_PCF_SOFT ) || defined( SHADOWMAP_TYPE_VSM )
				vec2 offset = vec2( - 1, 1 ) * shadowRadius * texelSize.y;
				shadow = (
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xyy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yyy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xyx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yyx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xxy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yxy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xxx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yxx, texelSize.y ), dp )
				) * ( 1.0 / 9.0 );
			#else
				shadow = texture2DCompare( shadowMap, cubeToUV( bd3D, texelSize.y ), dp );
			#endif
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
#endif`,yg=`#if NUM_SPOT_LIGHT_COORDS > 0
	uniform mat4 spotLightMatrix[ NUM_SPOT_LIGHT_COORDS ];
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform mat4 directionalShadowMatrix[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		uniform mat4 pointShadowMatrix[ NUM_POINT_LIGHT_SHADOWS ];
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
#endif`,_g=`#if ( defined( USE_SHADOWMAP ) && ( NUM_DIR_LIGHT_SHADOWS > 0 || NUM_POINT_LIGHT_SHADOWS > 0 ) ) || ( NUM_SPOT_LIGHT_COORDS > 0 )
	vec3 shadowWorldNormal = inverseTransformDirection( transformedNormal, viewMatrix );
	vec4 shadowWorldPosition;
#endif
#if defined( USE_SHADOWMAP )
	#if NUM_DIR_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * directionalLightShadows[ i ].shadowNormalBias, 0 );
			vDirectionalShadowCoord[ i ] = directionalShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * pointLightShadows[ i ].shadowNormalBias, 0 );
			vPointShadowCoord[ i ] = pointShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
#endif
#if NUM_SPOT_LIGHT_COORDS > 0
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_COORDS; i ++ ) {
		shadowWorldPosition = worldPosition;
		#if ( defined( USE_SHADOWMAP ) && UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
			shadowWorldPosition.xyz += shadowWorldNormal * spotLightShadows[ i ].shadowNormalBias;
		#endif
		vSpotLightCoord[ i ] = spotLightMatrix[ i ] * shadowWorldPosition;
	}
	#pragma unroll_loop_end
#endif`,Mg=`float getShadowMask() {
	float shadow = 1.0;
	#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
		directionalLight = directionalLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( directionalShadowMap[ i ], directionalLight.shadowMapSize, directionalLight.shadowIntensity, directionalLight.shadowBias, directionalLight.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_SHADOWS; i ++ ) {
		spotLight = spotLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( spotShadowMap[ i ], spotLight.shadowMapSize, spotLight.shadowIntensity, spotLight.shadowBias, spotLight.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
	PointLightShadow pointLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
		pointLight = pointLightShadows[ i ];
		shadow *= receiveShadow ? getPointShadow( pointShadowMap[ i ], pointLight.shadowMapSize, pointLight.shadowIntensity, pointLight.shadowBias, pointLight.shadowRadius, vPointShadowCoord[ i ], pointLight.shadowCameraNear, pointLight.shadowCameraFar ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#endif
	return shadow;
}`,Sg=`#ifdef USE_SKINNING
	mat4 boneMatX = getBoneMatrix( skinIndex.x );
	mat4 boneMatY = getBoneMatrix( skinIndex.y );
	mat4 boneMatZ = getBoneMatrix( skinIndex.z );
	mat4 boneMatW = getBoneMatrix( skinIndex.w );
#endif`,bg=`#ifdef USE_SKINNING
	uniform mat4 bindMatrix;
	uniform mat4 bindMatrixInverse;
	uniform highp sampler2D boneTexture;
	mat4 getBoneMatrix( const in float i ) {
		int size = textureSize( boneTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( boneTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( boneTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( boneTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( boneTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
#endif`,wg=`#ifdef USE_SKINNING
	vec4 skinVertex = bindMatrix * vec4( transformed, 1.0 );
	vec4 skinned = vec4( 0.0 );
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = ( bindMatrixInverse * skinned ).xyz;
#endif`,Eg=`#ifdef USE_SKINNING
	mat4 skinMatrix = mat4( 0.0 );
	skinMatrix += skinWeight.x * boneMatX;
	skinMatrix += skinWeight.y * boneMatY;
	skinMatrix += skinWeight.z * boneMatZ;
	skinMatrix += skinWeight.w * boneMatW;
	skinMatrix = bindMatrixInverse * skinMatrix * bindMatrix;
	objectNormal = vec4( skinMatrix * vec4( objectNormal, 0.0 ) ).xyz;
	#ifdef USE_TANGENT
		objectTangent = vec4( skinMatrix * vec4( objectTangent, 0.0 ) ).xyz;
	#endif
#endif`,Ag=`float specularStrength;
#ifdef USE_SPECULARMAP
	vec4 texelSpecular = texture2D( specularMap, vSpecularMapUv );
	specularStrength = texelSpecular.r;
#else
	specularStrength = 1.0;
#endif`,Tg=`#ifdef USE_SPECULARMAP
	uniform sampler2D specularMap;
#endif`,Cg=`#if defined( TONE_MAPPING )
	gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );
#endif`,Rg=`#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
uniform float toneMappingExposure;
vec3 LinearToneMapping( vec3 color ) {
	return saturate( toneMappingExposure * color );
}
vec3 ReinhardToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	return saturate( color / ( vec3( 1.0 ) + color ) );
}
vec3 CineonToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	color = max( vec3( 0.0 ), color - 0.004 );
	return pow( ( color * ( 6.2 * color + 0.5 ) ) / ( color * ( 6.2 * color + 1.7 ) + 0.06 ), vec3( 2.2 ) );
}
vec3 RRTAndODTFit( vec3 v ) {
	vec3 a = v * ( v + 0.0245786 ) - 0.000090537;
	vec3 b = v * ( 0.983729 * v + 0.4329510 ) + 0.238081;
	return a / b;
}
vec3 ACESFilmicToneMapping( vec3 color ) {
	const mat3 ACESInputMat = mat3(
		vec3( 0.59719, 0.07600, 0.02840 ),		vec3( 0.35458, 0.90834, 0.13383 ),
		vec3( 0.04823, 0.01566, 0.83777 )
	);
	const mat3 ACESOutputMat = mat3(
		vec3(  1.60475, -0.10208, -0.00327 ),		vec3( -0.53108,  1.10813, -0.07276 ),
		vec3( -0.07367, -0.00605,  1.07602 )
	);
	color *= toneMappingExposure / 0.6;
	color = ACESInputMat * color;
	color = RRTAndODTFit( color );
	color = ACESOutputMat * color;
	return saturate( color );
}
const mat3 LINEAR_REC2020_TO_LINEAR_SRGB = mat3(
	vec3( 1.6605, - 0.1246, - 0.0182 ),
	vec3( - 0.5876, 1.1329, - 0.1006 ),
	vec3( - 0.0728, - 0.0083, 1.1187 )
);
const mat3 LINEAR_SRGB_TO_LINEAR_REC2020 = mat3(
	vec3( 0.6274, 0.0691, 0.0164 ),
	vec3( 0.3293, 0.9195, 0.0880 ),
	vec3( 0.0433, 0.0113, 0.8956 )
);
vec3 agxDefaultContrastApprox( vec3 x ) {
	vec3 x2 = x * x;
	vec3 x4 = x2 * x2;
	return + 15.5 * x4 * x2
		- 40.14 * x4 * x
		+ 31.96 * x4
		- 6.868 * x2 * x
		+ 0.4298 * x2
		+ 0.1191 * x
		- 0.00232;
}
vec3 AgXToneMapping( vec3 color ) {
	const mat3 AgXInsetMatrix = mat3(
		vec3( 0.856627153315983, 0.137318972929847, 0.11189821299995 ),
		vec3( 0.0951212405381588, 0.761241990602591, 0.0767994186031903 ),
		vec3( 0.0482516061458583, 0.101439036467562, 0.811302368396859 )
	);
	const mat3 AgXOutsetMatrix = mat3(
		vec3( 1.1271005818144368, - 0.1413297634984383, - 0.14132976349843826 ),
		vec3( - 0.11060664309660323, 1.157823702216272, - 0.11060664309660294 ),
		vec3( - 0.016493938717834573, - 0.016493938717834257, 1.2519364065950405 )
	);
	const float AgxMinEv = - 12.47393;	const float AgxMaxEv = 4.026069;
	color *= toneMappingExposure;
	color = LINEAR_SRGB_TO_LINEAR_REC2020 * color;
	color = AgXInsetMatrix * color;
	color = max( color, 1e-10 );	color = log2( color );
	color = ( color - AgxMinEv ) / ( AgxMaxEv - AgxMinEv );
	color = clamp( color, 0.0, 1.0 );
	color = agxDefaultContrastApprox( color );
	color = AgXOutsetMatrix * color;
	color = pow( max( vec3( 0.0 ), color ), vec3( 2.2 ) );
	color = LINEAR_REC2020_TO_LINEAR_SRGB * color;
	color = clamp( color, 0.0, 1.0 );
	return color;
}
vec3 NeutralToneMapping( vec3 color ) {
	const float StartCompression = 0.8 - 0.04;
	const float Desaturation = 0.15;
	color *= toneMappingExposure;
	float x = min( color.r, min( color.g, color.b ) );
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;
	float peak = max( color.r, max( color.g, color.b ) );
	if ( peak < StartCompression ) return color;
	float d = 1. - StartCompression;
	float newPeak = 1. - d * d / ( peak + d - StartCompression );
	color *= newPeak / peak;
	float g = 1. - 1. / ( Desaturation * ( peak - newPeak ) + 1. );
	return mix( color, vec3( newPeak ), g );
}
vec3 CustomToneMapping( vec3 color ) { return color; }`,Pg=`#ifdef USE_TRANSMISSION
	material.transmission = transmission;
	material.transmissionAlpha = 1.0;
	material.thickness = thickness;
	material.attenuationDistance = attenuationDistance;
	material.attenuationColor = attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		material.transmission *= texture2D( transmissionMap, vTransmissionMapUv ).r;
	#endif
	#ifdef USE_THICKNESSMAP
		material.thickness *= texture2D( thicknessMap, vThicknessMapUv ).g;
	#endif
	vec3 pos = vWorldPosition;
	vec3 v = normalize( cameraPosition - pos );
	vec3 n = inverseTransformDirection( normal, viewMatrix );
	vec4 transmitted = getIBLVolumeRefraction(
		n, v, material.roughness, material.diffuseColor, material.specularColor, material.specularF90,
		pos, modelMatrix, viewMatrix, projectionMatrix, material.dispersion, material.ior, material.thickness,
		material.attenuationColor, material.attenuationDistance );
	material.transmissionAlpha = mix( material.transmissionAlpha, transmitted.a, material.transmission );
	totalDiffuse = mix( totalDiffuse, transmitted.rgb, material.transmission );
#endif`,Ig=`#ifdef USE_TRANSMISSION
	uniform float transmission;
	uniform float thickness;
	uniform float attenuationDistance;
	uniform vec3 attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		uniform sampler2D transmissionMap;
	#endif
	#ifdef USE_THICKNESSMAP
		uniform sampler2D thicknessMap;
	#endif
	uniform vec2 transmissionSamplerSize;
	uniform sampler2D transmissionSamplerMap;
	uniform mat4 modelMatrix;
	uniform mat4 projectionMatrix;
	varying vec3 vWorldPosition;
	float w0( float a ) {
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - a + 3.0 ) - 3.0 ) + 1.0 );
	}
	float w1( float a ) {
		return ( 1.0 / 6.0 ) * ( a *  a * ( 3.0 * a - 6.0 ) + 4.0 );
	}
	float w2( float a ){
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - 3.0 * a + 3.0 ) + 3.0 ) + 1.0 );
	}
	float w3( float a ) {
		return ( 1.0 / 6.0 ) * ( a * a * a );
	}
	float g0( float a ) {
		return w0( a ) + w1( a );
	}
	float g1( float a ) {
		return w2( a ) + w3( a );
	}
	float h0( float a ) {
		return - 1.0 + w1( a ) / ( w0( a ) + w1( a ) );
	}
	float h1( float a ) {
		return 1.0 + w3( a ) / ( w2( a ) + w3( a ) );
	}
	vec4 bicubic( sampler2D tex, vec2 uv, vec4 texelSize, float lod ) {
		uv = uv * texelSize.zw + 0.5;
		vec2 iuv = floor( uv );
		vec2 fuv = fract( uv );
		float g0x = g0( fuv.x );
		float g1x = g1( fuv.x );
		float h0x = h0( fuv.x );
		float h1x = h1( fuv.x );
		float h0y = h0( fuv.y );
		float h1y = h1( fuv.y );
		vec2 p0 = ( vec2( iuv.x + h0x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p1 = ( vec2( iuv.x + h1x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p2 = ( vec2( iuv.x + h0x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		vec2 p3 = ( vec2( iuv.x + h1x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		return g0( fuv.y ) * ( g0x * textureLod( tex, p0, lod ) + g1x * textureLod( tex, p1, lod ) ) +
			g1( fuv.y ) * ( g0x * textureLod( tex, p2, lod ) + g1x * textureLod( tex, p3, lod ) );
	}
	vec4 textureBicubic( sampler2D sampler, vec2 uv, float lod ) {
		vec2 fLodSize = vec2( textureSize( sampler, int( lod ) ) );
		vec2 cLodSize = vec2( textureSize( sampler, int( lod + 1.0 ) ) );
		vec2 fLodSizeInv = 1.0 / fLodSize;
		vec2 cLodSizeInv = 1.0 / cLodSize;
		vec4 fSample = bicubic( sampler, uv, vec4( fLodSizeInv, fLodSize ), floor( lod ) );
		vec4 cSample = bicubic( sampler, uv, vec4( cLodSizeInv, cLodSize ), ceil( lod ) );
		return mix( fSample, cSample, fract( lod ) );
	}
	vec3 getVolumeTransmissionRay( const in vec3 n, const in vec3 v, const in float thickness, const in float ior, const in mat4 modelMatrix ) {
		vec3 refractionVector = refract( - v, normalize( n ), 1.0 / ior );
		vec3 modelScale;
		modelScale.x = length( vec3( modelMatrix[ 0 ].xyz ) );
		modelScale.y = length( vec3( modelMatrix[ 1 ].xyz ) );
		modelScale.z = length( vec3( modelMatrix[ 2 ].xyz ) );
		return normalize( refractionVector ) * thickness * modelScale;
	}
	float applyIorToRoughness( const in float roughness, const in float ior ) {
		return roughness * clamp( ior * 2.0 - 2.0, 0.0, 1.0 );
	}
	vec4 getTransmissionSample( const in vec2 fragCoord, const in float roughness, const in float ior ) {
		float lod = log2( transmissionSamplerSize.x ) * applyIorToRoughness( roughness, ior );
		return textureBicubic( transmissionSamplerMap, fragCoord.xy, lod );
	}
	vec3 volumeAttenuation( const in float transmissionDistance, const in vec3 attenuationColor, const in float attenuationDistance ) {
		if ( isinf( attenuationDistance ) ) {
			return vec3( 1.0 );
		} else {
			vec3 attenuationCoefficient = -log( attenuationColor ) / attenuationDistance;
			vec3 transmittance = exp( - attenuationCoefficient * transmissionDistance );			return transmittance;
		}
	}
	vec4 getIBLVolumeRefraction( const in vec3 n, const in vec3 v, const in float roughness, const in vec3 diffuseColor,
		const in vec3 specularColor, const in float specularF90, const in vec3 position, const in mat4 modelMatrix,
		const in mat4 viewMatrix, const in mat4 projMatrix, const in float dispersion, const in float ior, const in float thickness,
		const in vec3 attenuationColor, const in float attenuationDistance ) {
		vec4 transmittedLight;
		vec3 transmittance;
		#ifdef USE_DISPERSION
			float halfSpread = ( ior - 1.0 ) * 0.025 * dispersion;
			vec3 iors = vec3( ior - halfSpread, ior, ior + halfSpread );
			for ( int i = 0; i < 3; i ++ ) {
				vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, iors[ i ], modelMatrix );
				vec3 refractedRayExit = position + transmissionRay;
				vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
				vec2 refractionCoords = ndcPos.xy / ndcPos.w;
				refractionCoords += 1.0;
				refractionCoords /= 2.0;
				vec4 transmissionSample = getTransmissionSample( refractionCoords, roughness, iors[ i ] );
				transmittedLight[ i ] = transmissionSample[ i ];
				transmittedLight.a += transmissionSample.a;
				transmittance[ i ] = diffuseColor[ i ] * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance )[ i ];
			}
			transmittedLight.a /= 3.0;
		#else
			vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, ior, modelMatrix );
			vec3 refractedRayExit = position + transmissionRay;
			vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
			vec2 refractionCoords = ndcPos.xy / ndcPos.w;
			refractionCoords += 1.0;
			refractionCoords /= 2.0;
			transmittedLight = getTransmissionSample( refractionCoords, roughness, ior );
			transmittance = diffuseColor * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance );
		#endif
		vec3 attenuatedColor = transmittance * transmittedLight.rgb;
		vec3 F = EnvironmentBRDF( n, v, specularColor, specularF90, roughness );
		float transmittanceFactor = ( transmittance.r + transmittance.g + transmittance.b ) / 3.0;
		return vec4( ( 1.0 - F ) * attenuatedColor, 1.0 - ( 1.0 - transmittedLight.a ) * transmittanceFactor );
	}
#endif`,Ng=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_SPECULARMAP
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,Lg=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	uniform mat3 mapTransform;
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	uniform mat3 alphaMapTransform;
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	uniform mat3 lightMapTransform;
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	uniform mat3 aoMapTransform;
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	uniform mat3 bumpMapTransform;
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	uniform mat3 normalMapTransform;
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_DISPLACEMENTMAP
	uniform mat3 displacementMapTransform;
	varying vec2 vDisplacementMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	uniform mat3 emissiveMapTransform;
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	uniform mat3 metalnessMapTransform;
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	uniform mat3 roughnessMapTransform;
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	uniform mat3 anisotropyMapTransform;
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	uniform mat3 clearcoatMapTransform;
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform mat3 clearcoatNormalMapTransform;
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform mat3 clearcoatRoughnessMapTransform;
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	uniform mat3 sheenColorMapTransform;
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	uniform mat3 sheenRoughnessMapTransform;
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	uniform mat3 iridescenceMapTransform;
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform mat3 iridescenceThicknessMapTransform;
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SPECULARMAP
	uniform mat3 specularMapTransform;
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	uniform mat3 specularColorMapTransform;
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	uniform mat3 specularIntensityMapTransform;
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,Dg=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	vUv = vec3( uv, 1 ).xy;
#endif
#ifdef USE_MAP
	vMapUv = ( mapTransform * vec3( MAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ALPHAMAP
	vAlphaMapUv = ( alphaMapTransform * vec3( ALPHAMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_LIGHTMAP
	vLightMapUv = ( lightMapTransform * vec3( LIGHTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_AOMAP
	vAoMapUv = ( aoMapTransform * vec3( AOMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_BUMPMAP
	vBumpMapUv = ( bumpMapTransform * vec3( BUMPMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_NORMALMAP
	vNormalMapUv = ( normalMapTransform * vec3( NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_DISPLACEMENTMAP
	vDisplacementMapUv = ( displacementMapTransform * vec3( DISPLACEMENTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_EMISSIVEMAP
	vEmissiveMapUv = ( emissiveMapTransform * vec3( EMISSIVEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_METALNESSMAP
	vMetalnessMapUv = ( metalnessMapTransform * vec3( METALNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ROUGHNESSMAP
	vRoughnessMapUv = ( roughnessMapTransform * vec3( ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ANISOTROPYMAP
	vAnisotropyMapUv = ( anisotropyMapTransform * vec3( ANISOTROPYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOATMAP
	vClearcoatMapUv = ( clearcoatMapTransform * vec3( CLEARCOATMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	vClearcoatNormalMapUv = ( clearcoatNormalMapTransform * vec3( CLEARCOAT_NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	vClearcoatRoughnessMapUv = ( clearcoatRoughnessMapTransform * vec3( CLEARCOAT_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCEMAP
	vIridescenceMapUv = ( iridescenceMapTransform * vec3( IRIDESCENCEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	vIridescenceThicknessMapUv = ( iridescenceThicknessMapTransform * vec3( IRIDESCENCE_THICKNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_COLORMAP
	vSheenColorMapUv = ( sheenColorMapTransform * vec3( SHEEN_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	vSheenRoughnessMapUv = ( sheenRoughnessMapTransform * vec3( SHEEN_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULARMAP
	vSpecularMapUv = ( specularMapTransform * vec3( SPECULARMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_COLORMAP
	vSpecularColorMapUv = ( specularColorMapTransform * vec3( SPECULAR_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	vSpecularIntensityMapUv = ( specularIntensityMapTransform * vec3( SPECULAR_INTENSITYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_TRANSMISSIONMAP
	vTransmissionMapUv = ( transmissionMapTransform * vec3( TRANSMISSIONMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_THICKNESSMAP
	vThicknessMapUv = ( thicknessMapTransform * vec3( THICKNESSMAP_UV, 1 ) ).xy;
#endif`,Fg=`#if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0
	vec4 worldPosition = vec4( transformed, 1.0 );
	#ifdef USE_BATCHING
		worldPosition = batchingMatrix * worldPosition;
	#endif
	#ifdef USE_INSTANCING
		worldPosition = instanceMatrix * worldPosition;
	#endif
	worldPosition = modelMatrix * worldPosition;
#endif`,Bg=`varying vec2 vUv;
uniform mat3 uvTransform;
void main() {
	vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	gl_Position = vec4( position.xy, 1.0, 1.0 );
}`,Ug=`uniform sampler2D t2D;
uniform float backgroundIntensity;
varying vec2 vUv;
void main() {
	vec4 texColor = texture2D( t2D, vUv );
	#ifdef DECODE_VIDEO_TEXTURE
		texColor = vec4( mix( pow( texColor.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), texColor.rgb * 0.0773993808, vec3( lessThanEqual( texColor.rgb, vec3( 0.04045 ) ) ) ), texColor.w );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Og=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,zg=`#ifdef ENVMAP_TYPE_CUBE
	uniform samplerCube envMap;
#elif defined( ENVMAP_TYPE_CUBE_UV )
	uniform sampler2D envMap;
#endif
uniform float flipEnvMap;
uniform float backgroundBlurriness;
uniform float backgroundIntensity;
uniform mat3 backgroundRotation;
varying vec3 vWorldDirection;
#include <cube_uv_reflection_fragment>
void main() {
	#ifdef ENVMAP_TYPE_CUBE
		vec4 texColor = textureCube( envMap, backgroundRotation * vec3( flipEnvMap * vWorldDirection.x, vWorldDirection.yz ) );
	#elif defined( ENVMAP_TYPE_CUBE_UV )
		vec4 texColor = textureCubeUV( envMap, backgroundRotation * vWorldDirection, backgroundBlurriness );
	#else
		vec4 texColor = vec4( 0.0, 0.0, 0.0, 1.0 );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,kg=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,Vg=`uniform samplerCube tCube;
uniform float tFlip;
uniform float opacity;
varying vec3 vWorldDirection;
void main() {
	vec4 texColor = textureCube( tCube, vec3( tFlip * vWorldDirection.x, vWorldDirection.yz ) );
	gl_FragColor = texColor;
	gl_FragColor.a *= opacity;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Hg=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
varying vec2 vHighPrecisionZW;
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vHighPrecisionZW = gl_Position.zw;
}`,Gg=`#if DEPTH_PACKING == 3200
	uniform float opacity;
#endif
#include <common>
#include <packing>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
varying vec2 vHighPrecisionZW;
void main() {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#if DEPTH_PACKING == 3200
		diffuseColor.a = opacity;
	#endif
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <logdepthbuf_fragment>
	#ifdef USE_REVERSED_DEPTH_BUFFER
		float fragCoordZ = vHighPrecisionZW[ 0 ] / vHighPrecisionZW[ 1 ];
	#else
		float fragCoordZ = 0.5 * vHighPrecisionZW[ 0 ] / vHighPrecisionZW[ 1 ] + 0.5;
	#endif
	#if DEPTH_PACKING == 3200
		gl_FragColor = vec4( vec3( 1.0 - fragCoordZ ), opacity );
	#elif DEPTH_PACKING == 3201
		gl_FragColor = packDepthToRGBA( fragCoordZ );
	#elif DEPTH_PACKING == 3202
		gl_FragColor = vec4( packDepthToRGB( fragCoordZ ), 1.0 );
	#elif DEPTH_PACKING == 3203
		gl_FragColor = vec4( packDepthToRG( fragCoordZ ), 0.0, 1.0 );
	#endif
}`,Wg=`#define DISTANCE
varying vec3 vWorldPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <worldpos_vertex>
	#include <clipping_planes_vertex>
	vWorldPosition = worldPosition.xyz;
}`,qg=`#define DISTANCE
uniform vec3 referencePosition;
uniform float nearDistance;
uniform float farDistance;
varying vec3 vWorldPosition;
#include <common>
#include <packing>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <clipping_planes_pars_fragment>
void main () {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	float dist = length( vWorldPosition - referencePosition );
	dist = ( dist - nearDistance ) / ( farDistance - nearDistance );
	dist = saturate( dist );
	gl_FragColor = packDepthToRGBA( dist );
}`,Xg=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
}`,$g=`uniform sampler2D tEquirect;
varying vec3 vWorldDirection;
#include <common>
void main() {
	vec3 direction = normalize( vWorldDirection );
	vec2 sampleUV = equirectUv( direction );
	gl_FragColor = texture2D( tEquirect, sampleUV );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Yg=`uniform float scale;
attribute float lineDistance;
varying float vLineDistance;
#include <common>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	vLineDistance = scale * lineDistance;
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,Zg=`uniform vec3 diffuse;
uniform float opacity;
uniform float dashSize;
uniform float totalSize;
varying float vLineDistance;
#include <common>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	if ( mod( vLineDistance, totalSize ) > dashSize ) {
		discard;
	}
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,Kg=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#if defined ( USE_ENVMAP ) || defined ( USE_SKINNING )
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinbase_vertex>
		#include <skinnormal_vertex>
		#include <defaultnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <fog_vertex>
}`,Jg=`uniform vec3 diffuse;
uniform float opacity;
#ifndef FLAT_SHADED
	varying vec3 vNormal;
#endif
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		reflectedLight.indirectDiffuse += lightMapTexel.rgb * lightMapIntensity * RECIPROCAL_PI;
	#else
		reflectedLight.indirectDiffuse += vec3( 1.0 );
	#endif
	#include <aomap_fragment>
	reflectedLight.indirectDiffuse *= diffuseColor.rgb;
	vec3 outgoingLight = reflectedLight.indirectDiffuse;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,jg=`#define LAMBERT
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,Qg=`#define LAMBERT
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_lambert_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_lambert_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,e0=`#define MATCAP
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <displacementmap_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
	vViewPosition = - mvPosition.xyz;
}`,t0=`#define MATCAP
uniform vec3 diffuse;
uniform float opacity;
uniform sampler2D matcap;
varying vec3 vViewPosition;
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	vec3 viewDir = normalize( vViewPosition );
	vec3 x = normalize( vec3( viewDir.z, 0.0, - viewDir.x ) );
	vec3 y = cross( viewDir, x );
	vec2 uv = vec2( dot( x, normal ), dot( y, normal ) ) * 0.495 + 0.5;
	#ifdef USE_MATCAP
		vec4 matcapColor = texture2D( matcap, uv );
	#else
		vec4 matcapColor = vec4( vec3( mix( 0.2, 0.8, uv.y ) ), 1.0 );
	#endif
	vec3 outgoingLight = diffuseColor.rgb * matcapColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,n0=`#define NORMAL
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	vViewPosition = - mvPosition.xyz;
#endif
}`,i0=`#define NORMAL
uniform float opacity;
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <packing>
#include <uv_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( 0.0, 0.0, 0.0, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	gl_FragColor = vec4( packNormalToRGB( normal ), diffuseColor.a );
	#ifdef OPAQUE
		gl_FragColor.a = 1.0;
	#endif
}`,s0=`#define PHONG
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,r0=`#define PHONG
uniform vec3 diffuse;
uniform vec3 emissive;
uniform vec3 specular;
uniform float shininess;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_phong_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_phong_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + reflectedLight.directSpecular + reflectedLight.indirectSpecular + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,o0=`#define STANDARD
varying vec3 vViewPosition;
#ifdef USE_TRANSMISSION
	varying vec3 vWorldPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
#ifdef USE_TRANSMISSION
	vWorldPosition = worldPosition.xyz;
#endif
}`,a0=`#define STANDARD
#ifdef PHYSICAL
	#define IOR
	#define USE_SPECULAR
#endif
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float roughness;
uniform float metalness;
uniform float opacity;
#ifdef IOR
	uniform float ior;
#endif
#ifdef USE_SPECULAR
	uniform float specularIntensity;
	uniform vec3 specularColor;
	#ifdef USE_SPECULAR_COLORMAP
		uniform sampler2D specularColorMap;
	#endif
	#ifdef USE_SPECULAR_INTENSITYMAP
		uniform sampler2D specularIntensityMap;
	#endif
#endif
#ifdef USE_CLEARCOAT
	uniform float clearcoat;
	uniform float clearcoatRoughness;
#endif
#ifdef USE_DISPERSION
	uniform float dispersion;
#endif
#ifdef USE_IRIDESCENCE
	uniform float iridescence;
	uniform float iridescenceIOR;
	uniform float iridescenceThicknessMinimum;
	uniform float iridescenceThicknessMaximum;
#endif
#ifdef USE_SHEEN
	uniform vec3 sheenColor;
	uniform float sheenRoughness;
	#ifdef USE_SHEEN_COLORMAP
		uniform sampler2D sheenColorMap;
	#endif
	#ifdef USE_SHEEN_ROUGHNESSMAP
		uniform sampler2D sheenRoughnessMap;
	#endif
#endif
#ifdef USE_ANISOTROPY
	uniform vec2 anisotropyVector;
	#ifdef USE_ANISOTROPYMAP
		uniform sampler2D anisotropyMap;
	#endif
#endif
varying vec3 vViewPosition;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <iridescence_fragment>
#include <cube_uv_reflection_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_physical_pars_fragment>
#include <fog_pars_fragment>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_physical_pars_fragment>
#include <transmission_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <clearcoat_pars_fragment>
#include <iridescence_pars_fragment>
#include <roughnessmap_pars_fragment>
#include <metalnessmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <roughnessmap_fragment>
	#include <metalnessmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <clearcoat_normal_fragment_begin>
	#include <clearcoat_normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_physical_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 totalDiffuse = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse;
	vec3 totalSpecular = reflectedLight.directSpecular + reflectedLight.indirectSpecular;
	#include <transmission_fragment>
	vec3 outgoingLight = totalDiffuse + totalSpecular + totalEmissiveRadiance;
	#ifdef USE_SHEEN
		float sheenEnergyComp = 1.0 - 0.157 * max3( material.sheenColor );
		outgoingLight = outgoingLight * sheenEnergyComp + sheenSpecularDirect + sheenSpecularIndirect;
	#endif
	#ifdef USE_CLEARCOAT
		float dotNVcc = saturate( dot( geometryClearcoatNormal, geometryViewDir ) );
		vec3 Fcc = F_Schlick( material.clearcoatF0, material.clearcoatF90, dotNVcc );
		outgoingLight = outgoingLight * ( 1.0 - material.clearcoat * Fcc ) + ( clearcoatSpecularDirect + clearcoatSpecularIndirect ) * material.clearcoat;
	#endif
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,l0=`#define TOON
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,c0=`#define TOON
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <gradientmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_toon_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_toon_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,h0=`uniform float size;
uniform float scale;
#include <common>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
#ifdef USE_POINTS_UV
	varying vec2 vUv;
	uniform mat3 uvTransform;
#endif
void main() {
	#ifdef USE_POINTS_UV
		vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	#endif
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	gl_PointSize = size;
	#ifdef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) gl_PointSize *= ( scale / - mvPosition.z );
	#endif
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <fog_vertex>
}`,u0=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <color_pars_fragment>
#include <map_particle_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_particle_fragment>
	#include <color_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,f0=`#include <common>
#include <batching_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <shadowmap_pars_vertex>
void main() {
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,d0=`uniform vec3 color;
uniform float opacity;
#include <common>
#include <packing>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <logdepthbuf_pars_fragment>
#include <shadowmap_pars_fragment>
#include <shadowmask_pars_fragment>
void main() {
	#include <logdepthbuf_fragment>
	gl_FragColor = vec4( color, opacity * ( 1.0 - getShadowMask() ) );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`,p0=`uniform float rotation;
uniform vec2 center;
#include <common>
#include <uv_pars_vertex>
#include <fog_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	vec4 mvPosition = modelViewMatrix[ 3 ];
	vec2 scale = vec2( length( modelMatrix[ 0 ].xyz ), length( modelMatrix[ 1 ].xyz ) );
	#ifndef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) scale *= - mvPosition.z;
	#endif
	vec2 alignedPosition = ( position.xy - ( center - vec2( 0.5 ) ) ) * scale;
	vec2 rotatedPosition;
	rotatedPosition.x = cos( rotation ) * alignedPosition.x - sin( rotation ) * alignedPosition.y;
	rotatedPosition.y = sin( rotation ) * alignedPosition.x + cos( rotation ) * alignedPosition.y;
	mvPosition.xy += rotatedPosition;
	gl_Position = projectionMatrix * mvPosition;
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,m0=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`,it={alphahash_fragment:Up,alphahash_pars_fragment:Op,alphamap_fragment:zp,alphamap_pars_fragment:kp,alphatest_fragment:Vp,alphatest_pars_fragment:Hp,aomap_fragment:Gp,aomap_pars_fragment:Wp,batching_pars_vertex:qp,batching_vertex:Xp,begin_vertex:$p,beginnormal_vertex:Yp,bsdfs:Zp,iridescence_fragment:Kp,bumpmap_pars_fragment:Jp,clipping_planes_fragment:jp,clipping_planes_pars_fragment:Qp,clipping_planes_pars_vertex:em,clipping_planes_vertex:tm,color_fragment:nm,color_pars_fragment:im,color_pars_vertex:sm,color_vertex:rm,common:om,cube_uv_reflection_fragment:am,defaultnormal_vertex:lm,displacementmap_pars_vertex:cm,displacementmap_vertex:hm,emissivemap_fragment:um,emissivemap_pars_fragment:fm,colorspace_fragment:dm,colorspace_pars_fragment:pm,envmap_fragment:mm,envmap_common_pars_fragment:gm,envmap_pars_fragment:vm,envmap_pars_vertex:xm,envmap_physical_pars_fragment:Rm,envmap_vertex:ym,fog_vertex:_m,fog_pars_vertex:Mm,fog_fragment:Sm,fog_pars_fragment:bm,gradientmap_pars_fragment:wm,lightmap_pars_fragment:Em,lights_lambert_fragment:Am,lights_lambert_pars_fragment:Tm,lights_pars_begin:Cm,lights_toon_fragment:Pm,lights_toon_pars_fragment:Im,lights_phong_fragment:Nm,lights_phong_pars_fragment:Lm,lights_physical_fragment:Dm,lights_physical_pars_fragment:Fm,lights_fragment_begin:Bm,lights_fragment_maps:Um,lights_fragment_end:Om,logdepthbuf_fragment:zm,logdepthbuf_pars_fragment:km,logdepthbuf_pars_vertex:Vm,logdepthbuf_vertex:Hm,map_fragment:Gm,map_pars_fragment:Wm,map_particle_fragment:qm,map_particle_pars_fragment:Xm,metalnessmap_fragment:$m,metalnessmap_pars_fragment:Ym,morphinstance_vertex:Zm,morphcolor_vertex:Km,morphnormal_vertex:Jm,morphtarget_pars_vertex:jm,morphtarget_vertex:Qm,normal_fragment_begin:eg,normal_fragment_maps:tg,normal_pars_fragment:ng,normal_pars_vertex:ig,normal_vertex:sg,normalmap_pars_fragment:rg,clearcoat_normal_fragment_begin:og,clearcoat_normal_fragment_maps:ag,clearcoat_pars_fragment:lg,iridescence_pars_fragment:cg,opaque_fragment:hg,packing:ug,premultiplied_alpha_fragment:fg,project_vertex:dg,dithering_fragment:pg,dithering_pars_fragment:mg,roughnessmap_fragment:gg,roughnessmap_pars_fragment:vg,shadowmap_pars_fragment:xg,shadowmap_pars_vertex:yg,shadowmap_vertex:_g,shadowmask_pars_fragment:Mg,skinbase_vertex:Sg,skinning_pars_vertex:bg,skinning_vertex:wg,skinnormal_vertex:Eg,specularmap_fragment:Ag,specularmap_pars_fragment:Tg,tonemapping_fragment:Cg,tonemapping_pars_fragment:Rg,transmission_fragment:Pg,transmission_pars_fragment:Ig,uv_pars_fragment:Ng,uv_pars_vertex:Lg,uv_vertex:Dg,worldpos_vertex:Fg,background_vert:Bg,background_frag:Ug,backgroundCube_vert:Og,backgroundCube_frag:zg,cube_vert:kg,cube_frag:Vg,depth_vert:Hg,depth_frag:Gg,distanceRGBA_vert:Wg,distanceRGBA_frag:qg,equirect_vert:Xg,equirect_frag:$g,linedashed_vert:Yg,linedashed_frag:Zg,meshbasic_vert:Kg,meshbasic_frag:Jg,meshlambert_vert:jg,meshlambert_frag:Qg,meshmatcap_vert:e0,meshmatcap_frag:t0,meshnormal_vert:n0,meshnormal_frag:i0,meshphong_vert:s0,meshphong_frag:r0,meshphysical_vert:o0,meshphysical_frag:a0,meshtoon_vert:l0,meshtoon_frag:c0,points_vert:h0,points_frag:u0,shadow_vert:f0,shadow_frag:d0,sprite_vert:p0,sprite_frag:m0},ve={common:{diffuse:{value:new ot(16777215)},opacity:{value:1},map:{value:null},mapTransform:{value:new tt},alphaMap:{value:null},alphaMapTransform:{value:new tt},alphaTest:{value:0}},specularmap:{specularMap:{value:null},specularMapTransform:{value:new tt}},envmap:{envMap:{value:null},envMapRotation:{value:new tt},flipEnvMap:{value:-1},reflectivity:{value:1},ior:{value:1.5},refractionRatio:{value:.98}},aomap:{aoMap:{value:null},aoMapIntensity:{value:1},aoMapTransform:{value:new tt}},lightmap:{lightMap:{value:null},lightMapIntensity:{value:1},lightMapTransform:{value:new tt}},bumpmap:{bumpMap:{value:null},bumpMapTransform:{value:new tt},bumpScale:{value:1}},normalmap:{normalMap:{value:null},normalMapTransform:{value:new tt},normalScale:{value:new et(1,1)}},displacementmap:{displacementMap:{value:null},displacementMapTransform:{value:new tt},displacementScale:{value:1},displacementBias:{value:0}},emissivemap:{emissiveMap:{value:null},emissiveMapTransform:{value:new tt}},metalnessmap:{metalnessMap:{value:null},metalnessMapTransform:{value:new tt}},roughnessmap:{roughnessMap:{value:null},roughnessMapTransform:{value:new tt}},gradientmap:{gradientMap:{value:null}},fog:{fogDensity:{value:25e-5},fogNear:{value:1},fogFar:{value:2e3},fogColor:{value:new ot(16777215)}},lights:{ambientLightColor:{value:[]},lightProbe:{value:[]},directionalLights:{value:[],properties:{direction:{},color:{}}},directionalLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},directionalShadowMap:{value:[]},directionalShadowMatrix:{value:[]},spotLights:{value:[],properties:{color:{},position:{},direction:{},distance:{},coneCos:{},penumbraCos:{},decay:{}}},spotLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},spotLightMap:{value:[]},spotShadowMap:{value:[]},spotLightMatrix:{value:[]},pointLights:{value:[],properties:{color:{},position:{},decay:{},distance:{}}},pointLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{},shadowCameraNear:{},shadowCameraFar:{}}},pointShadowMap:{value:[]},pointShadowMatrix:{value:[]},hemisphereLights:{value:[],properties:{direction:{},skyColor:{},groundColor:{}}},rectAreaLights:{value:[],properties:{color:{},position:{},width:{},height:{}}},ltc_1:{value:null},ltc_2:{value:null}},points:{diffuse:{value:new ot(16777215)},opacity:{value:1},size:{value:1},scale:{value:1},map:{value:null},alphaMap:{value:null},alphaMapTransform:{value:new tt},alphaTest:{value:0},uvTransform:{value:new tt}},sprite:{diffuse:{value:new ot(16777215)},opacity:{value:1},center:{value:new et(.5,.5)},rotation:{value:0},map:{value:null},mapTransform:{value:new tt},alphaMap:{value:null},alphaMapTransform:{value:new tt},alphaTest:{value:0}}},hi={basic:{uniforms:en([ve.common,ve.specularmap,ve.envmap,ve.aomap,ve.lightmap,ve.fog]),vertexShader:it.meshbasic_vert,fragmentShader:it.meshbasic_frag},lambert:{uniforms:en([ve.common,ve.specularmap,ve.envmap,ve.aomap,ve.lightmap,ve.emissivemap,ve.bumpmap,ve.normalmap,ve.displacementmap,ve.fog,ve.lights,{emissive:{value:new ot(0)}}]),vertexShader:it.meshlambert_vert,fragmentShader:it.meshlambert_frag},phong:{uniforms:en([ve.common,ve.specularmap,ve.envmap,ve.aomap,ve.lightmap,ve.emissivemap,ve.bumpmap,ve.normalmap,ve.displacementmap,ve.fog,ve.lights,{emissive:{value:new ot(0)},specular:{value:new ot(1118481)},shininess:{value:30}}]),vertexShader:it.meshphong_vert,fragmentShader:it.meshphong_frag},standard:{uniforms:en([ve.common,ve.envmap,ve.aomap,ve.lightmap,ve.emissivemap,ve.bumpmap,ve.normalmap,ve.displacementmap,ve.roughnessmap,ve.metalnessmap,ve.fog,ve.lights,{emissive:{value:new ot(0)},roughness:{value:1},metalness:{value:0},envMapIntensity:{value:1}}]),vertexShader:it.meshphysical_vert,fragmentShader:it.meshphysical_frag},toon:{uniforms:en([ve.common,ve.aomap,ve.lightmap,ve.emissivemap,ve.bumpmap,ve.normalmap,ve.displacementmap,ve.gradientmap,ve.fog,ve.lights,{emissive:{value:new ot(0)}}]),vertexShader:it.meshtoon_vert,fragmentShader:it.meshtoon_frag},matcap:{uniforms:en([ve.common,ve.bumpmap,ve.normalmap,ve.displacementmap,ve.fog,{matcap:{value:null}}]),vertexShader:it.meshmatcap_vert,fragmentShader:it.meshmatcap_frag},points:{uniforms:en([ve.points,ve.fog]),vertexShader:it.points_vert,fragmentShader:it.points_frag},dashed:{uniforms:en([ve.common,ve.fog,{scale:{value:1},dashSize:{value:1},totalSize:{value:2}}]),vertexShader:it.linedashed_vert,fragmentShader:it.linedashed_frag},depth:{uniforms:en([ve.common,ve.displacementmap]),vertexShader:it.depth_vert,fragmentShader:it.depth_frag},normal:{uniforms:en([ve.common,ve.bumpmap,ve.normalmap,ve.displacementmap,{opacity:{value:1}}]),vertexShader:it.meshnormal_vert,fragmentShader:it.meshnormal_frag},sprite:{uniforms:en([ve.sprite,ve.fog]),vertexShader:it.sprite_vert,fragmentShader:it.sprite_frag},background:{uniforms:{uvTransform:{value:new tt},t2D:{value:null},backgroundIntensity:{value:1}},vertexShader:it.background_vert,fragmentShader:it.background_frag},backgroundCube:{uniforms:{envMap:{value:null},flipEnvMap:{value:-1},backgroundBlurriness:{value:0},backgroundIntensity:{value:1},backgroundRotation:{value:new tt}},vertexShader:it.backgroundCube_vert,fragmentShader:it.backgroundCube_frag},cube:{uniforms:{tCube:{value:null},tFlip:{value:-1},opacity:{value:1}},vertexShader:it.cube_vert,fragmentShader:it.cube_frag},equirect:{uniforms:{tEquirect:{value:null}},vertexShader:it.equirect_vert,fragmentShader:it.equirect_frag},distanceRGBA:{uniforms:en([ve.common,ve.displacementmap,{referencePosition:{value:new G},nearDistance:{value:1},farDistance:{value:1e3}}]),vertexShader:it.distanceRGBA_vert,fragmentShader:it.distanceRGBA_frag},shadow:{uniforms:en([ve.lights,ve.fog,{color:{value:new ot(0)},opacity:{value:1}}]),vertexShader:it.shadow_vert,fragmentShader:it.shadow_frag}};hi.physical={uniforms:en([hi.standard.uniforms,{clearcoat:{value:0},clearcoatMap:{value:null},clearcoatMapTransform:{value:new tt},clearcoatNormalMap:{value:null},clearcoatNormalMapTransform:{value:new tt},clearcoatNormalScale:{value:new et(1,1)},clearcoatRoughness:{value:0},clearcoatRoughnessMap:{value:null},clearcoatRoughnessMapTransform:{value:new tt},dispersion:{value:0},iridescence:{value:0},iridescenceMap:{value:null},iridescenceMapTransform:{value:new tt},iridescenceIOR:{value:1.3},iridescenceThicknessMinimum:{value:100},iridescenceThicknessMaximum:{value:400},iridescenceThicknessMap:{value:null},iridescenceThicknessMapTransform:{value:new tt},sheen:{value:0},sheenColor:{value:new ot(0)},sheenColorMap:{value:null},sheenColorMapTransform:{value:new tt},sheenRoughness:{value:1},sheenRoughnessMap:{value:null},sheenRoughnessMapTransform:{value:new tt},transmission:{value:0},transmissionMap:{value:null},transmissionMapTransform:{value:new tt},transmissionSamplerSize:{value:new et},transmissionSamplerMap:{value:null},thickness:{value:0},thicknessMap:{value:null},thicknessMapTransform:{value:new tt},attenuationDistance:{value:0},attenuationColor:{value:new ot(0)},specularColor:{value:new ot(1,1,1)},specularColorMap:{value:null},specularColorMapTransform:{value:new tt},specularIntensity:{value:1},specularIntensityMap:{value:null},specularIntensityMapTransform:{value:new tt},anisotropyVector:{value:new et},anisotropyMap:{value:null},anisotropyMapTransform:{value:new tt}}]),vertexShader:it.meshphysical_vert,fragmentShader:it.meshphysical_frag};var ml={r:0,b:0,g:0},ws=new Zn,g0=new Mt;function v0(r,e,t,n,i,s,o){let a=new ot(0),l=s===!0?0:1,h,f,c=null,u=0,d=null;function p(x){let y=x.isScene===!0?x.background:null;return y&&y.isTexture&&(y=(x.backgroundBlurriness>0?t:e).get(y)),y}function v(x){let y=!1,S=p(x);S===null?m(a,l):S&&S.isColor&&(m(S,1),y=!0);let M=r.xr.getEnvironmentBlendMode();M==="additive"?n.buffers.color.setClear(0,0,0,1,o):M==="alpha-blend"&&n.buffers.color.setClear(0,0,0,0,o),(r.autoClear||y)&&(n.buffers.depth.setTest(!0),n.buffers.depth.setMask(!0),n.buffers.color.setMask(!0),r.clear(r.autoClearColor,r.autoClearDepth,r.autoClearStencil))}function g(x,y){let S=p(y);S&&(S.isCubeTexture||S.mapping===no)?(f===void 0&&(f=new fn(new Yi(1,1,1),new Kn({name:"BackgroundCubeMaterial",uniforms:bs(hi.backgroundCube.uniforms),vertexShader:hi.backgroundCube.vertexShader,fragmentShader:hi.backgroundCube.fragmentShader,side:on,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),f.geometry.deleteAttribute("normal"),f.geometry.deleteAttribute("uv"),f.onBeforeRender=function(M,E,A){this.matrixWorld.copyPosition(A.matrixWorld)},Object.defineProperty(f.material,"envMap",{get:function(){return this.uniforms.envMap.value}}),i.update(f)),ws.copy(y.backgroundRotation),ws.x*=-1,ws.y*=-1,ws.z*=-1,S.isCubeTexture&&S.isRenderTargetTexture===!1&&(ws.y*=-1,ws.z*=-1),f.material.uniforms.envMap.value=S,f.material.uniforms.flipEnvMap.value=S.isCubeTexture&&S.isRenderTargetTexture===!1?-1:1,f.material.uniforms.backgroundBlurriness.value=y.backgroundBlurriness,f.material.uniforms.backgroundIntensity.value=y.backgroundIntensity,f.material.uniforms.backgroundRotation.value.setFromMatrix4(g0.makeRotationFromEuler(ws)),f.material.toneMapped=lt.getTransfer(S.colorSpace)!==dt,(c!==S||u!==S.version||d!==r.toneMapping)&&(f.material.needsUpdate=!0,c=S,u=S.version,d=r.toneMapping),f.layers.enableAll(),x.unshift(f,f.geometry,f.material,0,0,null)):S&&S.isTexture&&(h===void 0&&(h=new fn(new ys(2,2),new Kn({name:"BackgroundMaterial",uniforms:bs(hi.background.uniforms),vertexShader:hi.background.vertexShader,fragmentShader:hi.background.fragmentShader,side:Si,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),h.geometry.deleteAttribute("normal"),Object.defineProperty(h.material,"map",{get:function(){return this.uniforms.t2D.value}}),i.update(h)),h.material.uniforms.t2D.value=S,h.material.uniforms.backgroundIntensity.value=y.backgroundIntensity,h.material.toneMapped=lt.getTransfer(S.colorSpace)!==dt,S.matrixAutoUpdate===!0&&S.updateMatrix(),h.material.uniforms.uvTransform.value.copy(S.matrix),(c!==S||u!==S.version||d!==r.toneMapping)&&(h.material.needsUpdate=!0,c=S,u=S.version,d=r.toneMapping),h.layers.enableAll(),x.unshift(h,h.geometry,h.material,0,0,null))}function m(x,y){x.getRGB(ml,rh(r)),n.buffers.color.setClear(ml.r,ml.g,ml.b,y,o)}function _(){f!==void 0&&(f.geometry.dispose(),f.material.dispose(),f=void 0),h!==void 0&&(h.geometry.dispose(),h.material.dispose(),h=void 0)}return{getClearColor:function(){return a},setClearColor:function(x,y=1){a.set(x),l=y,m(a,l)},getClearAlpha:function(){return l},setClearAlpha:function(x){l=x,m(a,l)},render:v,addToRenderList:g,dispose:_}}function x0(r,e){let t=r.getParameter(r.MAX_VERTEX_ATTRIBS),n={},i=u(null),s=i,o=!1;function a(w,T,F,D,C){let P=!1,N=c(D,F,T);s!==N&&(s=N,h(s.object)),P=d(w,D,F,C),P&&p(w,D,F,C),C!==null&&e.update(C,r.ELEMENT_ARRAY_BUFFER),(P||o)&&(o=!1,y(w,T,F,D),C!==null&&r.bindBuffer(r.ELEMENT_ARRAY_BUFFER,e.get(C).buffer))}function l(){return r.createVertexArray()}function h(w){return r.bindVertexArray(w)}function f(w){return r.deleteVertexArray(w)}function c(w,T,F){let D=F.wireframe===!0,C=n[w.id];C===void 0&&(C={},n[w.id]=C);let P=C[T.id];P===void 0&&(P={},C[T.id]=P);let N=P[D];return N===void 0&&(N=u(l()),P[D]=N),N}function u(w){let T=[],F=[],D=[];for(let C=0;C<t;C++)T[C]=0,F[C]=0,D[C]=0;return{geometry:null,program:null,wireframe:!1,newAttributes:T,enabledAttributes:F,attributeDivisors:D,object:w,attributes:{},index:null}}function d(w,T,F,D){let C=s.attributes,P=T.attributes,N=0,z=F.getAttributes();for(let O in z)if(z[O].location>=0){let ee=C[O],oe=P[O];if(oe===void 0&&(O==="instanceMatrix"&&w.instanceMatrix&&(oe=w.instanceMatrix),O==="instanceColor"&&w.instanceColor&&(oe=w.instanceColor)),ee===void 0||ee.attribute!==oe||oe&&ee.data!==oe.data)return!0;N++}return s.attributesNum!==N||s.index!==D}function p(w,T,F,D){let C={},P=T.attributes,N=0,z=F.getAttributes();for(let O in z)if(z[O].location>=0){let ee=P[O];ee===void 0&&(O==="instanceMatrix"&&w.instanceMatrix&&(ee=w.instanceMatrix),O==="instanceColor"&&w.instanceColor&&(ee=w.instanceColor));let oe={};oe.attribute=ee,ee&&ee.data&&(oe.data=ee.data),C[O]=oe,N++}s.attributes=C,s.attributesNum=N,s.index=D}function v(){let w=s.newAttributes;for(let T=0,F=w.length;T<F;T++)w[T]=0}function g(w){m(w,0)}function m(w,T){let F=s.newAttributes,D=s.enabledAttributes,C=s.attributeDivisors;F[w]=1,D[w]===0&&(r.enableVertexAttribArray(w),D[w]=1),C[w]!==T&&(r.vertexAttribDivisor(w,T),C[w]=T)}function _(){let w=s.newAttributes,T=s.enabledAttributes;for(let F=0,D=T.length;F<D;F++)T[F]!==w[F]&&(r.disableVertexAttribArray(F),T[F]=0)}function x(w,T,F,D,C,P,N){N===!0?r.vertexAttribIPointer(w,T,F,C,P):r.vertexAttribPointer(w,T,F,D,C,P)}function y(w,T,F,D){v();let C=D.attributes,P=F.getAttributes(),N=T.defaultAttributeValues;for(let z in P){let O=P[z];if(O.location>=0){let K=C[z];if(K===void 0&&(z==="instanceMatrix"&&w.instanceMatrix&&(K=w.instanceMatrix),z==="instanceColor"&&w.instanceColor&&(K=w.instanceColor)),K!==void 0){let ee=K.normalized,oe=K.itemSize,ae=e.get(K);if(ae===void 0)continue;let Ge=ae.buffer,Ce=ae.type,We=ae.bytesPerElement,j=Ce===r.INT||Ce===r.UNSIGNED_INT||K.gpuType===Fa;if(K.isInterleavedBufferAttribute){let ne=K.data,ye=ne.stride,De=K.offset;if(ne.isInstancedInterleavedBuffer){for(let Se=0;Se<O.locationSize;Se++)m(O.location+Se,ne.meshPerAttribute);w.isInstancedMesh!==!0&&D._maxInstanceCount===void 0&&(D._maxInstanceCount=ne.meshPerAttribute*ne.count)}else for(let Se=0;Se<O.locationSize;Se++)g(O.location+Se);r.bindBuffer(r.ARRAY_BUFFER,Ge);for(let Se=0;Se<O.locationSize;Se++)x(O.location+Se,oe/O.locationSize,Ce,ee,ye*We,(De+oe/O.locationSize*Se)*We,j)}else{if(K.isInstancedBufferAttribute){for(let ne=0;ne<O.locationSize;ne++)m(O.location+ne,K.meshPerAttribute);w.isInstancedMesh!==!0&&D._maxInstanceCount===void 0&&(D._maxInstanceCount=K.meshPerAttribute*K.count)}else for(let ne=0;ne<O.locationSize;ne++)g(O.location+ne);r.bindBuffer(r.ARRAY_BUFFER,Ge);for(let ne=0;ne<O.locationSize;ne++)x(O.location+ne,oe/O.locationSize,Ce,ee,oe*We,oe/O.locationSize*ne*We,j)}}else if(N!==void 0){let ee=N[z];if(ee!==void 0)switch(ee.length){case 2:r.vertexAttrib2fv(O.location,ee);break;case 3:r.vertexAttrib3fv(O.location,ee);break;case 4:r.vertexAttrib4fv(O.location,ee);break;default:r.vertexAttrib1fv(O.location,ee)}}}}_()}function S(){A();for(let w in n){let T=n[w];for(let F in T){let D=T[F];for(let C in D)f(D[C].object),delete D[C];delete T[F]}delete n[w]}}function M(w){if(n[w.id]===void 0)return;let T=n[w.id];for(let F in T){let D=T[F];for(let C in D)f(D[C].object),delete D[C];delete T[F]}delete n[w.id]}function E(w){for(let T in n){let F=n[T];if(F[w.id]===void 0)continue;let D=F[w.id];for(let C in D)f(D[C].object),delete D[C];delete F[w.id]}}function A(){b(),o=!0,s!==i&&(s=i,h(s.object))}function b(){i.geometry=null,i.program=null,i.wireframe=!1}return{setup:a,reset:A,resetDefaultState:b,dispose:S,releaseStatesOfGeometry:M,releaseStatesOfProgram:E,initAttributes:v,enableAttribute:g,disableUnusedAttributes:_}}function y0(r,e,t){let n;function i(h){n=h}function s(h,f){r.drawArrays(n,h,f),t.update(f,n,1)}function o(h,f,c){c!==0&&(r.drawArraysInstanced(n,h,f,c),t.update(f,n,c))}function a(h,f,c){if(c===0)return;e.get("WEBGL_multi_draw").multiDrawArraysWEBGL(n,h,0,f,0,c);let d=0;for(let p=0;p<c;p++)d+=f[p];t.update(d,n,1)}function l(h,f,c,u){if(c===0)return;let d=e.get("WEBGL_multi_draw");if(d===null)for(let p=0;p<h.length;p++)o(h[p],f[p],u[p]);else{d.multiDrawArraysInstancedWEBGL(n,h,0,f,0,u,0,c);let p=0;for(let v=0;v<c;v++)p+=f[v]*u[v];t.update(p,n,1)}}this.setMode=i,this.render=s,this.renderInstances=o,this.renderMultiDraw=a,this.renderMultiDrawInstances=l}function _0(r,e,t,n){let i;function s(){if(i!==void 0)return i;if(e.has("EXT_texture_filter_anisotropic")===!0){let E=e.get("EXT_texture_filter_anisotropic");i=r.getParameter(E.MAX_TEXTURE_MAX_ANISOTROPY_EXT)}else i=0;return i}function o(E){return!(E!==Bn&&n.convert(E)!==r.getParameter(r.IMPLEMENTATION_COLOR_READ_FORMAT))}function a(E){let A=E===ar&&(e.has("EXT_color_buffer_half_float")||e.has("EXT_color_buffer_float"));return!(E!==Jn&&n.convert(E)!==r.getParameter(r.IMPLEMENTATION_COLOR_READ_TYPE)&&E!==ci&&!A)}function l(E){if(E==="highp"){if(r.getShaderPrecisionFormat(r.VERTEX_SHADER,r.HIGH_FLOAT).precision>0&&r.getShaderPrecisionFormat(r.FRAGMENT_SHADER,r.HIGH_FLOAT).precision>0)return"highp";E="mediump"}return E==="mediump"&&r.getShaderPrecisionFormat(r.VERTEX_SHADER,r.MEDIUM_FLOAT).precision>0&&r.getShaderPrecisionFormat(r.FRAGMENT_SHADER,r.MEDIUM_FLOAT).precision>0?"mediump":"lowp"}let h=t.precision!==void 0?t.precision:"highp",f=l(h);f!==h&&(console.warn("THREE.WebGLRenderer:",h,"not supported, using",f,"instead."),h=f);let c=t.logarithmicDepthBuffer===!0,u=t.reversedDepthBuffer===!0&&e.has("EXT_clip_control"),d=r.getParameter(r.MAX_TEXTURE_IMAGE_UNITS),p=r.getParameter(r.MAX_VERTEX_TEXTURE_IMAGE_UNITS),v=r.getParameter(r.MAX_TEXTURE_SIZE),g=r.getParameter(r.MAX_CUBE_MAP_TEXTURE_SIZE),m=r.getParameter(r.MAX_VERTEX_ATTRIBS),_=r.getParameter(r.MAX_VERTEX_UNIFORM_VECTORS),x=r.getParameter(r.MAX_VARYING_VECTORS),y=r.getParameter(r.MAX_FRAGMENT_UNIFORM_VECTORS),S=p>0,M=r.getParameter(r.MAX_SAMPLES);return{isWebGL2:!0,getMaxAnisotropy:s,getMaxPrecision:l,textureFormatReadable:o,textureTypeReadable:a,precision:h,logarithmicDepthBuffer:c,reversedDepthBuffer:u,maxTextures:d,maxVertexTextures:p,maxTextureSize:v,maxCubemapSize:g,maxAttributes:m,maxVertexUniforms:_,maxVaryings:x,maxFragmentUniforms:y,vertexTextures:S,maxSamples:M}}function M0(r){let e=this,t=null,n=0,i=!1,s=!1,o=new Dn,a=new tt,l={value:null,needsUpdate:!1};this.uniform=l,this.numPlanes=0,this.numIntersection=0,this.init=function(c,u){let d=c.length!==0||u||n!==0||i;return i=u,n=c.length,d},this.beginShadows=function(){s=!0,f(null)},this.endShadows=function(){s=!1},this.setGlobalState=function(c,u){t=f(c,u,0)},this.setState=function(c,u,d){let p=c.clippingPlanes,v=c.clipIntersection,g=c.clipShadows,m=r.get(c);if(!i||p===null||p.length===0||s&&!g)s?f(null):h();else{let _=s?0:n,x=_*4,y=m.clippingState||null;l.value=y,y=f(p,u,x,d);for(let S=0;S!==x;++S)y[S]=t[S];m.clippingState=y,this.numIntersection=v?this.numPlanes:0,this.numPlanes+=_}};function h(){l.value!==t&&(l.value=t,l.needsUpdate=n>0),e.numPlanes=n,e.numIntersection=0}function f(c,u,d,p){let v=c!==null?c.length:0,g=null;if(v!==0){if(g=l.value,p!==!0||g===null){let m=d+v*4,_=u.matrixWorldInverse;a.getNormalMatrix(_),(g===null||g.length<m)&&(g=new Float32Array(m));for(let x=0,y=d;x!==v;++x,y+=4)o.copy(c[x]).applyMatrix4(_,a),o.normal.toArray(g,y),g[y+3]=o.constant}l.value=g,l.needsUpdate=!0}return e.numPlanes=v,e.numIntersection=0,g}}function S0(r){let e=new WeakMap;function t(o,a){return a===Na?o.mapping=Ms:a===La&&(o.mapping=Ss),o}function n(o){if(o&&o.isTexture){let a=o.mapping;if(a===Na||a===La)if(e.has(o)){let l=e.get(o).texture;return t(l,o.mapping)}else{let l=o.image;if(l&&l.height>0){let h=new la(l.height);return h.fromEquirectangularTexture(r,o),e.set(o,h),o.addEventListener("dispose",i),t(h.texture,o.mapping)}else return null}}return o}function i(o){let a=o.target;a.removeEventListener("dispose",i);let l=e.get(a);l!==void 0&&(e.delete(a),l.dispose())}function s(){e=new WeakMap}return{get:n,dispose:s}}var ur=4,wf=[.125,.215,.35,.446,.526,.582],Ts=20,ch=new eo,Ef=new ot,hh=null,uh=0,fh=0,dh=!1,As=(1+Math.sqrt(5))/2,hr=1/As,Af=[new G(-As,hr,0),new G(As,hr,0),new G(-hr,0,As),new G(hr,0,As),new G(0,As,-hr),new G(0,As,hr),new G(-1,1,-1),new G(1,1,-1),new G(-1,1,1),new G(1,1,1)],b0=new G,xl=class{constructor(e){this._renderer=e,this._pingPongRenderTarget=null,this._lodMax=0,this._cubeSize=0,this._lodPlanes=[],this._sizeLods=[],this._sigmas=[],this._blurMaterial=null,this._cubemapMaterial=null,this._equirectMaterial=null,this._compileMaterial(this._blurMaterial)}fromScene(e,t=0,n=.1,i=100,s={}){let{size:o=256,position:a=b0}=s;hh=this._renderer.getRenderTarget(),uh=this._renderer.getActiveCubeFace(),fh=this._renderer.getActiveMipmapLevel(),dh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1,this._setSize(o);let l=this._allocateTargets();return l.depthBuffer=!0,this._sceneToCubeUV(e,n,i,l,a),t>0&&this._blur(l,0,0,t),this._applyPMREM(l),this._cleanup(l),l}fromEquirectangular(e,t=null){return this._fromTexture(e,t)}fromCubemap(e,t=null){return this._fromTexture(e,t)}compileCubemapShader(){this._cubemapMaterial===null&&(this._cubemapMaterial=Rf(),this._compileMaterial(this._cubemapMaterial))}compileEquirectangularShader(){this._equirectMaterial===null&&(this._equirectMaterial=Cf(),this._compileMaterial(this._equirectMaterial))}dispose(){this._dispose(),this._cubemapMaterial!==null&&this._cubemapMaterial.dispose(),this._equirectMaterial!==null&&this._equirectMaterial.dispose()}_setSize(e){this._lodMax=Math.floor(Math.log2(e)),this._cubeSize=Math.pow(2,this._lodMax)}_dispose(){this._blurMaterial!==null&&this._blurMaterial.dispose(),this._pingPongRenderTarget!==null&&this._pingPongRenderTarget.dispose();for(let e=0;e<this._lodPlanes.length;e++)this._lodPlanes[e].dispose()}_cleanup(e){this._renderer.setRenderTarget(hh,uh,fh),this._renderer.xr.enabled=dh,e.scissorTest=!1,gl(e,0,0,e.width,e.height)}_fromTexture(e,t){e.mapping===Ms||e.mapping===Ss?this._setSize(e.image.length===0?16:e.image[0].width||e.image[0].image.width):this._setSize(e.image.width/4),hh=this._renderer.getRenderTarget(),uh=this._renderer.getActiveCubeFace(),fh=this._renderer.getActiveMipmapLevel(),dh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1;let n=t||this._allocateTargets();return this._textureToCubeUV(e,n),this._applyPMREM(n),this._cleanup(n),n}_allocateTargets(){let e=3*Math.max(this._cubeSize,112),t=4*this._cubeSize,n={magFilter:Yn,minFilter:Yn,generateMipmaps:!1,type:ar,format:Bn,colorSpace:gs,depthBuffer:!1},i=Tf(e,t,n);if(this._pingPongRenderTarget===null||this._pingPongRenderTarget.width!==e||this._pingPongRenderTarget.height!==t){this._pingPongRenderTarget!==null&&this._dispose(),this._pingPongRenderTarget=Tf(e,t,n);let{_lodMax:s}=this;({sizeLods:this._sizeLods,lodPlanes:this._lodPlanes,sigmas:this._sigmas}=w0(s)),this._blurMaterial=E0(s,e,t)}return i}_compileMaterial(e){let t=new fn(this._lodPlanes[0],e);this._renderer.compile(t,ch)}_sceneToCubeUV(e,t,n,i,s){let l=new Qt(90,1,t,n),h=[1,-1,1,1,1,1],f=[1,1,1,-1,-1,-1],c=this._renderer,u=c.autoClear,d=c.toneMapping;c.getClearColor(Ef),c.toneMapping=Ti,c.autoClear=!1,c.state.buffers.depth.getReversed()&&(c.setRenderTarget(i),c.clearDepth(),c.setRenderTarget(null));let v=new xs({name:"PMREM.Background",side:on,depthWrite:!1,depthTest:!1}),g=new fn(new Yi,v),m=!1,_=e.background;_?_.isColor&&(v.color.copy(_),e.background=null,m=!0):(v.color.copy(Ef),m=!0);for(let x=0;x<6;x++){let y=x%3;y===0?(l.up.set(0,h[x],0),l.position.set(s.x,s.y,s.z),l.lookAt(s.x+f[x],s.y,s.z)):y===1?(l.up.set(0,0,h[x]),l.position.set(s.x,s.y,s.z),l.lookAt(s.x,s.y+f[x],s.z)):(l.up.set(0,h[x],0),l.position.set(s.x,s.y,s.z),l.lookAt(s.x,s.y,s.z+f[x]));let S=this._cubeSize;gl(i,y*S,x>2?S:0,S,S),c.setRenderTarget(i),m&&c.render(g,l),c.render(e,l)}g.geometry.dispose(),g.material.dispose(),c.toneMapping=d,c.autoClear=u,e.background=_}_textureToCubeUV(e,t){let n=this._renderer,i=e.mapping===Ms||e.mapping===Ss;i?(this._cubemapMaterial===null&&(this._cubemapMaterial=Rf()),this._cubemapMaterial.uniforms.flipEnvMap.value=e.isRenderTargetTexture===!1?-1:1):this._equirectMaterial===null&&(this._equirectMaterial=Cf());let s=i?this._cubemapMaterial:this._equirectMaterial,o=new fn(this._lodPlanes[0],s),a=s.uniforms;a.envMap.value=e;let l=this._cubeSize;gl(t,0,0,3*l,2*l),n.setRenderTarget(t),n.render(o,ch)}_applyPMREM(e){let t=this._renderer,n=t.autoClear;t.autoClear=!1;let i=this._lodPlanes.length;for(let s=1;s<i;s++){let o=Math.sqrt(this._sigmas[s]*this._sigmas[s]-this._sigmas[s-1]*this._sigmas[s-1]),a=Af[(i-s-1)%Af.length];this._blur(e,s-1,s,o,a)}t.autoClear=n}_blur(e,t,n,i,s){let o=this._pingPongRenderTarget;this._halfBlur(e,o,t,n,i,"latitudinal",s),this._halfBlur(o,e,n,n,i,"longitudinal",s)}_halfBlur(e,t,n,i,s,o,a){let l=this._renderer,h=this._blurMaterial;o!=="latitudinal"&&o!=="longitudinal"&&console.error("blur direction must be either latitudinal or longitudinal!");let f=3,c=new fn(this._lodPlanes[i],h),u=h.uniforms,d=this._sizeLods[n]-1,p=isFinite(s)?Math.PI/(2*d):2*Math.PI/(2*Ts-1),v=s/p,g=isFinite(s)?1+Math.floor(f*v):Ts;g>Ts&&console.warn(`sigmaRadians, ${s}, is too large and will clip, as it requested ${g} samples when the maximum is set to ${Ts}`);let m=[],_=0;for(let E=0;E<Ts;++E){let A=E/v,b=Math.exp(-A*A/2);m.push(b),E===0?_+=b:E<g&&(_+=2*b)}for(let E=0;E<m.length;E++)m[E]=m[E]/_;u.envMap.value=e.texture,u.samples.value=g,u.weights.value=m,u.latitudinal.value=o==="latitudinal",a&&(u.poleAxis.value=a);let{_lodMax:x}=this;u.dTheta.value=p,u.mipInt.value=x-n;let y=this._sizeLods[i],S=3*y*(i>x-ur?i-x+ur:0),M=4*(this._cubeSize-y);gl(t,S,M,3*y,2*y),l.setRenderTarget(t),l.render(c,ch)}};function w0(r){let e=[],t=[],n=[],i=r,s=r-ur+1+wf.length;for(let o=0;o<s;o++){let a=Math.pow(2,i);t.push(a);let l=1/a;o>r-ur?l=wf[o-r+ur-1]:o===0&&(l=0),n.push(l);let h=1/(a-2),f=-h,c=1+h,u=[f,f,c,f,c,c,f,f,c,c,f,c],d=6,p=6,v=3,g=2,m=1,_=new Float32Array(v*p*d),x=new Float32Array(g*p*d),y=new Float32Array(m*p*d);for(let M=0;M<d;M++){let E=M%3*2/3-1,A=M>2?0:-1,b=[E,A,0,E+2/3,A,0,E+2/3,A+1,0,E,A,0,E+2/3,A+1,0,E,A+1,0];_.set(b,v*p*M),x.set(u,g*p*M);let w=[M,M,M,M,M,M];y.set(w,m*p*M)}let S=new Lt;S.setAttribute("position",new Mn(_,v)),S.setAttribute("uv",new Mn(x,g)),S.setAttribute("faceIndex",new Mn(y,m)),e.push(S),i>ur&&i--}return{lodPlanes:e,sizeLods:t,sigmas:n}}function Tf(r,e,t){let n=new oi(r,e,t);return n.texture.mapping=no,n.texture.name="PMREM.cubeUv",n.scissorTest=!0,n}function gl(r,e,t,n,i){r.viewport.set(e,t,n,i),r.scissor.set(e,t,n,i)}function E0(r,e,t){let n=new Float32Array(Ts),i=new G(0,1,0);return new Kn({name:"SphericalGaussianBlur",defines:{n:Ts,CUBEUV_TEXEL_WIDTH:1/e,CUBEUV_TEXEL_HEIGHT:1/t,CUBEUV_MAX_MIP:`${r}.0`},uniforms:{envMap:{value:null},samples:{value:1},weights:{value:n},latitudinal:{value:!1},dTheta:{value:0},mipInt:{value:0},poleAxis:{value:i}},vertexShader:bh(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;
			uniform int samples;
			uniform float weights[ n ];
			uniform bool latitudinal;
			uniform float dTheta;
			uniform float mipInt;
			uniform vec3 poleAxis;

			#define ENVMAP_TYPE_CUBE_UV
			#include <cube_uv_reflection_fragment>

			vec3 getSample( float theta, vec3 axis ) {

				float cosTheta = cos( theta );
				// Rodrigues' axis-angle rotation
				vec3 sampleDirection = vOutputDirection * cosTheta
					+ cross( axis, vOutputDirection ) * sin( theta )
					+ axis * dot( axis, vOutputDirection ) * ( 1.0 - cosTheta );

				return bilinearCubeUV( envMap, sampleDirection, mipInt );

			}

			void main() {

				vec3 axis = latitudinal ? poleAxis : cross( poleAxis, vOutputDirection );

				if ( all( equal( axis, vec3( 0.0 ) ) ) ) {

					axis = vec3( vOutputDirection.z, 0.0, - vOutputDirection.x );

				}

				axis = normalize( axis );

				gl_FragColor = vec4( 0.0, 0.0, 0.0, 1.0 );
				gl_FragColor.rgb += weights[ 0 ] * getSample( 0.0, axis );

				for ( int i = 1; i < n; i++ ) {

					if ( i >= samples ) {

						break;

					}

					float theta = dTheta * float( i );
					gl_FragColor.rgb += weights[ i ] * getSample( -1.0 * theta, axis );
					gl_FragColor.rgb += weights[ i ] * getSample( theta, axis );

				}

			}
		`,blending:Ai,depthTest:!1,depthWrite:!1})}function Cf(){return new Kn({name:"EquirectangularToCubeUV",uniforms:{envMap:{value:null}},vertexShader:bh(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;

			#include <common>

			void main() {

				vec3 outputDirection = normalize( vOutputDirection );
				vec2 uv = equirectUv( outputDirection );

				gl_FragColor = vec4( texture2D ( envMap, uv ).rgb, 1.0 );

			}
		`,blending:Ai,depthTest:!1,depthWrite:!1})}function Rf(){return new Kn({name:"CubemapToCubeUV",uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:bh(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			uniform float flipEnvMap;

			varying vec3 vOutputDirection;

			uniform samplerCube envMap;

			void main() {

				gl_FragColor = textureCube( envMap, vec3( flipEnvMap * vOutputDirection.x, vOutputDirection.yz ) );

			}
		`,blending:Ai,depthTest:!1,depthWrite:!1})}function bh(){return`

		precision mediump float;
		precision mediump int;

		attribute float faceIndex;

		varying vec3 vOutputDirection;

		// RH coordinate system; PMREM face-indexing convention
		vec3 getDirection( vec2 uv, float face ) {

			uv = 2.0 * uv - 1.0;

			vec3 direction = vec3( uv, 1.0 );

			if ( face == 0.0 ) {

				direction = direction.zyx; // ( 1, v, u ) pos x

			} else if ( face == 1.0 ) {

				direction = direction.xzy;
				direction.xz *= -1.0; // ( -u, 1, -v ) pos y

			} else if ( face == 2.0 ) {

				direction.x *= -1.0; // ( -u, v, 1 ) pos z

			} else if ( face == 3.0 ) {

				direction = direction.zyx;
				direction.xz *= -1.0; // ( -1, v, -u ) neg x

			} else if ( face == 4.0 ) {

				direction = direction.xzy;
				direction.xy *= -1.0; // ( -u, -1, v ) neg y

			} else if ( face == 5.0 ) {

				direction.z *= -1.0; // ( u, v, -1 ) neg z

			}

			return direction;

		}

		void main() {

			vOutputDirection = getDirection( uv, faceIndex );
			gl_Position = vec4( position, 1.0 );

		}
	`}function A0(r){let e=new WeakMap,t=null;function n(a){if(a&&a.isTexture){let l=a.mapping,h=l===Na||l===La,f=l===Ms||l===Ss;if(h||f){let c=e.get(a),u=c!==void 0?c.texture.pmremVersion:0;if(a.isRenderTargetTexture&&a.pmremVersion!==u)return t===null&&(t=new xl(r)),c=h?t.fromEquirectangular(a,c):t.fromCubemap(a,c),c.texture.pmremVersion=a.pmremVersion,e.set(a,c),c.texture;if(c!==void 0)return c.texture;{let d=a.image;return h&&d&&d.height>0||f&&d&&i(d)?(t===null&&(t=new xl(r)),c=h?t.fromEquirectangular(a):t.fromCubemap(a),c.texture.pmremVersion=a.pmremVersion,e.set(a,c),a.addEventListener("dispose",s),c.texture):null}}}return a}function i(a){let l=0,h=6;for(let f=0;f<h;f++)a[f]!==void 0&&l++;return l===h}function s(a){let l=a.target;l.removeEventListener("dispose",s);let h=e.get(l);h!==void 0&&(e.delete(l),h.dispose())}function o(){e=new WeakMap,t!==null&&(t.dispose(),t=null)}return{get:n,dispose:o}}function T0(r){let e={};function t(n){if(e[n]!==void 0)return e[n];let i;switch(n){case"WEBGL_depth_texture":i=r.getExtension("WEBGL_depth_texture")||r.getExtension("MOZ_WEBGL_depth_texture")||r.getExtension("WEBKIT_WEBGL_depth_texture");break;case"EXT_texture_filter_anisotropic":i=r.getExtension("EXT_texture_filter_anisotropic")||r.getExtension("MOZ_EXT_texture_filter_anisotropic")||r.getExtension("WEBKIT_EXT_texture_filter_anisotropic");break;case"WEBGL_compressed_texture_s3tc":i=r.getExtension("WEBGL_compressed_texture_s3tc")||r.getExtension("MOZ_WEBGL_compressed_texture_s3tc")||r.getExtension("WEBKIT_WEBGL_compressed_texture_s3tc");break;case"WEBGL_compressed_texture_pvrtc":i=r.getExtension("WEBGL_compressed_texture_pvrtc")||r.getExtension("WEBKIT_WEBGL_compressed_texture_pvrtc");break;default:i=r.getExtension(n)}return e[n]=i,i}return{has:function(n){return t(n)!==null},init:function(){t("EXT_color_buffer_float"),t("WEBGL_clip_cull_distance"),t("OES_texture_float_linear"),t("EXT_color_buffer_half_float"),t("WEBGL_multisampled_render_to_texture"),t("WEBGL_render_shared_exponent")},get:function(n){let i=t(n);return i===null&&Ks("THREE.WebGLRenderer: "+n+" extension not supported."),i}}}function C0(r,e,t,n){let i={},s=new WeakMap;function o(c){let u=c.target;u.index!==null&&e.remove(u.index);for(let p in u.attributes)e.remove(u.attributes[p]);u.removeEventListener("dispose",o),delete i[u.id];let d=s.get(u);d&&(e.remove(d),s.delete(u)),n.releaseStatesOfGeometry(u),u.isInstancedBufferGeometry===!0&&delete u._maxInstanceCount,t.memory.geometries--}function a(c,u){return i[u.id]===!0||(u.addEventListener("dispose",o),i[u.id]=!0,t.memory.geometries++),u}function l(c){let u=c.attributes;for(let d in u)e.update(u[d],r.ARRAY_BUFFER)}function h(c){let u=[],d=c.index,p=c.attributes.position,v=0;if(d!==null){let _=d.array;v=d.version;for(let x=0,y=_.length;x<y;x+=3){let S=_[x+0],M=_[x+1],E=_[x+2];u.push(S,M,M,E,E,S)}}else if(p!==void 0){let _=p.array;v=p.version;for(let x=0,y=_.length/3-1;x<y;x+=3){let S=x+0,M=x+1,E=x+2;u.push(S,M,M,E,E,S)}}else return;let g=new(sh(u)?Or:Ur)(u,1);g.version=v;let m=s.get(c);m&&e.remove(m),s.set(c,g)}function f(c){let u=s.get(c);if(u){let d=c.index;d!==null&&u.version<d.version&&h(c)}else h(c);return s.get(c)}return{get:a,update:l,getWireframeAttribute:f}}function R0(r,e,t){let n;function i(u){n=u}let s,o;function a(u){s=u.type,o=u.bytesPerElement}function l(u,d){r.drawElements(n,d,s,u*o),t.update(d,n,1)}function h(u,d,p){p!==0&&(r.drawElementsInstanced(n,d,s,u*o,p),t.update(d,n,p))}function f(u,d,p){if(p===0)return;e.get("WEBGL_multi_draw").multiDrawElementsWEBGL(n,d,0,s,u,0,p);let g=0;for(let m=0;m<p;m++)g+=d[m];t.update(g,n,1)}function c(u,d,p,v){if(p===0)return;let g=e.get("WEBGL_multi_draw");if(g===null)for(let m=0;m<u.length;m++)h(u[m]/o,d[m],v[m]);else{g.multiDrawElementsInstancedWEBGL(n,d,0,s,u,0,v,0,p);let m=0;for(let _=0;_<p;_++)m+=d[_]*v[_];t.update(m,n,1)}}this.setMode=i,this.setIndex=a,this.render=l,this.renderInstances=h,this.renderMultiDraw=f,this.renderMultiDrawInstances=c}function P0(r){let e={geometries:0,textures:0},t={frame:0,calls:0,triangles:0,points:0,lines:0};function n(s,o,a){switch(t.calls++,o){case r.TRIANGLES:t.triangles+=a*(s/3);break;case r.LINES:t.lines+=a*(s/2);break;case r.LINE_STRIP:t.lines+=a*(s-1);break;case r.LINE_LOOP:t.lines+=a*s;break;case r.POINTS:t.points+=a*s;break;default:console.error("THREE.WebGLInfo: Unknown draw mode:",o);break}}function i(){t.calls=0,t.triangles=0,t.points=0,t.lines=0}return{memory:e,render:t,programs:null,autoReset:!0,reset:i,update:n}}function I0(r,e,t){let n=new WeakMap,i=new St;function s(o,a,l){let h=o.morphTargetInfluences,f=a.morphAttributes.position||a.morphAttributes.normal||a.morphAttributes.color,c=f!==void 0?f.length:0,u=n.get(a);if(u===void 0||u.count!==c){let b=function(){E.dispose(),n.delete(a),a.removeEventListener("dispose",b)};u!==void 0&&u.texture.dispose();let d=a.morphAttributes.position!==void 0,p=a.morphAttributes.normal!==void 0,v=a.morphAttributes.color!==void 0,g=a.morphAttributes.position||[],m=a.morphAttributes.normal||[],_=a.morphAttributes.color||[],x=0;d===!0&&(x=1),p===!0&&(x=2),v===!0&&(x=3);let y=a.attributes.position.count*x,S=1;y>e.maxTextureSize&&(S=Math.ceil(y/e.maxTextureSize),y=e.maxTextureSize);let M=new Float32Array(y*S*4*c),E=new Br(M,y,S,c);E.type=ci,E.needsUpdate=!0;let A=x*4;for(let w=0;w<c;w++){let T=g[w],F=m[w],D=_[w],C=y*S*4*w;for(let P=0;P<T.count;P++){let N=P*A;d===!0&&(i.fromBufferAttribute(T,P),M[C+N+0]=i.x,M[C+N+1]=i.y,M[C+N+2]=i.z,M[C+N+3]=0),p===!0&&(i.fromBufferAttribute(F,P),M[C+N+4]=i.x,M[C+N+5]=i.y,M[C+N+6]=i.z,M[C+N+7]=0),v===!0&&(i.fromBufferAttribute(D,P),M[C+N+8]=i.x,M[C+N+9]=i.y,M[C+N+10]=i.z,M[C+N+11]=D.itemSize===4?i.w:1)}}u={count:c,texture:E,size:new et(y,S)},n.set(a,u),a.addEventListener("dispose",b)}if(o.isInstancedMesh===!0&&o.morphTexture!==null)l.getUniforms().setValue(r,"morphTexture",o.morphTexture,t);else{let d=0;for(let v=0;v<h.length;v++)d+=h[v];let p=a.morphTargetsRelative?1:1-d;l.getUniforms().setValue(r,"morphTargetBaseInfluence",p),l.getUniforms().setValue(r,"morphTargetInfluences",h)}l.getUniforms().setValue(r,"morphTargetsTexture",u.texture,t),l.getUniforms().setValue(r,"morphTargetsTextureSize",u.size)}return{update:s}}function N0(r,e,t,n){let i=new WeakMap;function s(l){let h=n.render.frame,f=l.geometry,c=e.get(l,f);if(i.get(c)!==h&&(e.update(c),i.set(c,h)),l.isInstancedMesh&&(l.hasEventListener("dispose",a)===!1&&l.addEventListener("dispose",a),i.get(l)!==h&&(t.update(l.instanceMatrix,r.ARRAY_BUFFER),l.instanceColor!==null&&t.update(l.instanceColor,r.ARRAY_BUFFER),i.set(l,h))),l.isSkinnedMesh){let u=l.skeleton;i.get(u)!==h&&(u.update(),i.set(u,h))}return c}function o(){i=new WeakMap}function a(l){let h=l.target;h.removeEventListener("dispose",a),t.remove(h.instanceMatrix),h.instanceColor!==null&&t.remove(h.instanceColor)}return{update:s,dispose:o}}var Yf=new un,Pf=new qr(1,1),Zf=new Br,Kf=new oa,Jf=new kr,If=[],Nf=[],Lf=new Float32Array(16),Df=new Float32Array(9),Ff=new Float32Array(4);function dr(r,e,t){let n=r[0];if(n<=0||n>0)return r;let i=e*t,s=If[i];if(s===void 0&&(s=new Float32Array(i),If[i]=s),e!==0){n.toArray(s,0);for(let o=1,a=0;o!==e;++o)a+=t,r[o].toArray(s,a)}return s}function Dt(r,e){if(r.length!==e.length)return!1;for(let t=0,n=r.length;t<n;t++)if(r[t]!==e[t])return!1;return!0}function Ft(r,e){for(let t=0,n=e.length;t<n;t++)r[t]=e[t]}function _l(r,e){let t=Nf[e];t===void 0&&(t=new Int32Array(e),Nf[e]=t);for(let n=0;n!==e;++n)t[n]=r.allocateTextureUnit();return t}function L0(r,e){let t=this.cache;t[0]!==e&&(r.uniform1f(this.addr,e),t[0]=e)}function D0(r,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(r.uniform2f(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(Dt(t,e))return;r.uniform2fv(this.addr,e),Ft(t,e)}}function F0(r,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(r.uniform3f(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else if(e.r!==void 0)(t[0]!==e.r||t[1]!==e.g||t[2]!==e.b)&&(r.uniform3f(this.addr,e.r,e.g,e.b),t[0]=e.r,t[1]=e.g,t[2]=e.b);else{if(Dt(t,e))return;r.uniform3fv(this.addr,e),Ft(t,e)}}function B0(r,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(r.uniform4f(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(Dt(t,e))return;r.uniform4fv(this.addr,e),Ft(t,e)}}function U0(r,e){let t=this.cache,n=e.elements;if(n===void 0){if(Dt(t,e))return;r.uniformMatrix2fv(this.addr,!1,e),Ft(t,e)}else{if(Dt(t,n))return;Ff.set(n),r.uniformMatrix2fv(this.addr,!1,Ff),Ft(t,n)}}function O0(r,e){let t=this.cache,n=e.elements;if(n===void 0){if(Dt(t,e))return;r.uniformMatrix3fv(this.addr,!1,e),Ft(t,e)}else{if(Dt(t,n))return;Df.set(n),r.uniformMatrix3fv(this.addr,!1,Df),Ft(t,n)}}function z0(r,e){let t=this.cache,n=e.elements;if(n===void 0){if(Dt(t,e))return;r.uniformMatrix4fv(this.addr,!1,e),Ft(t,e)}else{if(Dt(t,n))return;Lf.set(n),r.uniformMatrix4fv(this.addr,!1,Lf),Ft(t,n)}}function k0(r,e){let t=this.cache;t[0]!==e&&(r.uniform1i(this.addr,e),t[0]=e)}function V0(r,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(r.uniform2i(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(Dt(t,e))return;r.uniform2iv(this.addr,e),Ft(t,e)}}function H0(r,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(r.uniform3i(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(Dt(t,e))return;r.uniform3iv(this.addr,e),Ft(t,e)}}function G0(r,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(r.uniform4i(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(Dt(t,e))return;r.uniform4iv(this.addr,e),Ft(t,e)}}function W0(r,e){let t=this.cache;t[0]!==e&&(r.uniform1ui(this.addr,e),t[0]=e)}function q0(r,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(r.uniform2ui(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(Dt(t,e))return;r.uniform2uiv(this.addr,e),Ft(t,e)}}function X0(r,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(r.uniform3ui(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(Dt(t,e))return;r.uniform3uiv(this.addr,e),Ft(t,e)}}function $0(r,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(r.uniform4ui(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(Dt(t,e))return;r.uniform4uiv(this.addr,e),Ft(t,e)}}function Y0(r,e,t){let n=this.cache,i=t.allocateTextureUnit();n[0]!==i&&(r.uniform1i(this.addr,i),n[0]=i);let s;this.type===r.SAMPLER_2D_SHADOW?(Pf.compareFunction=nh,s=Pf):s=Yf,t.setTexture2D(e||s,i)}function Z0(r,e,t){let n=this.cache,i=t.allocateTextureUnit();n[0]!==i&&(r.uniform1i(this.addr,i),n[0]=i),t.setTexture3D(e||Kf,i)}function K0(r,e,t){let n=this.cache,i=t.allocateTextureUnit();n[0]!==i&&(r.uniform1i(this.addr,i),n[0]=i),t.setTextureCube(e||Jf,i)}function J0(r,e,t){let n=this.cache,i=t.allocateTextureUnit();n[0]!==i&&(r.uniform1i(this.addr,i),n[0]=i),t.setTexture2DArray(e||Zf,i)}function j0(r){switch(r){case 5126:return L0;case 35664:return D0;case 35665:return F0;case 35666:return B0;case 35674:return U0;case 35675:return O0;case 35676:return z0;case 5124:case 35670:return k0;case 35667:case 35671:return V0;case 35668:case 35672:return H0;case 35669:case 35673:return G0;case 5125:return W0;case 36294:return q0;case 36295:return X0;case 36296:return $0;case 35678:case 36198:case 36298:case 36306:case 35682:return Y0;case 35679:case 36299:case 36307:return Z0;case 35680:case 36300:case 36308:case 36293:return K0;case 36289:case 36303:case 36311:case 36292:return J0}}function Q0(r,e){r.uniform1fv(this.addr,e)}function ev(r,e){let t=dr(e,this.size,2);r.uniform2fv(this.addr,t)}function tv(r,e){let t=dr(e,this.size,3);r.uniform3fv(this.addr,t)}function nv(r,e){let t=dr(e,this.size,4);r.uniform4fv(this.addr,t)}function iv(r,e){let t=dr(e,this.size,4);r.uniformMatrix2fv(this.addr,!1,t)}function sv(r,e){let t=dr(e,this.size,9);r.uniformMatrix3fv(this.addr,!1,t)}function rv(r,e){let t=dr(e,this.size,16);r.uniformMatrix4fv(this.addr,!1,t)}function ov(r,e){r.uniform1iv(this.addr,e)}function av(r,e){r.uniform2iv(this.addr,e)}function lv(r,e){r.uniform3iv(this.addr,e)}function cv(r,e){r.uniform4iv(this.addr,e)}function hv(r,e){r.uniform1uiv(this.addr,e)}function uv(r,e){r.uniform2uiv(this.addr,e)}function fv(r,e){r.uniform3uiv(this.addr,e)}function dv(r,e){r.uniform4uiv(this.addr,e)}function pv(r,e,t){let n=this.cache,i=e.length,s=_l(t,i);Dt(n,s)||(r.uniform1iv(this.addr,s),Ft(n,s));for(let o=0;o!==i;++o)t.setTexture2D(e[o]||Yf,s[o])}function mv(r,e,t){let n=this.cache,i=e.length,s=_l(t,i);Dt(n,s)||(r.uniform1iv(this.addr,s),Ft(n,s));for(let o=0;o!==i;++o)t.setTexture3D(e[o]||Kf,s[o])}function gv(r,e,t){let n=this.cache,i=e.length,s=_l(t,i);Dt(n,s)||(r.uniform1iv(this.addr,s),Ft(n,s));for(let o=0;o!==i;++o)t.setTextureCube(e[o]||Jf,s[o])}function vv(r,e,t){let n=this.cache,i=e.length,s=_l(t,i);Dt(n,s)||(r.uniform1iv(this.addr,s),Ft(n,s));for(let o=0;o!==i;++o)t.setTexture2DArray(e[o]||Zf,s[o])}function xv(r){switch(r){case 5126:return Q0;case 35664:return ev;case 35665:return tv;case 35666:return nv;case 35674:return iv;case 35675:return sv;case 35676:return rv;case 5124:case 35670:return ov;case 35667:case 35671:return av;case 35668:case 35672:return lv;case 35669:case 35673:return cv;case 5125:return hv;case 36294:return uv;case 36295:return fv;case 36296:return dv;case 35678:case 36198:case 36298:case 36306:case 35682:return pv;case 35679:case 36299:case 36307:return mv;case 35680:case 36300:case 36308:case 36293:return gv;case 36289:case 36303:case 36311:case 36292:return vv}}var mh=class{constructor(e,t,n){this.id=e,this.addr=n,this.cache=[],this.type=t.type,this.setValue=j0(t.type)}},gh=class{constructor(e,t,n){this.id=e,this.addr=n,this.cache=[],this.type=t.type,this.size=t.size,this.setValue=xv(t.type)}},vh=class{constructor(e){this.id=e,this.seq=[],this.map={}}setValue(e,t,n){let i=this.seq;for(let s=0,o=i.length;s!==o;++s){let a=i[s];a.setValue(e,t[a.id],n)}}},ph=/(\w+)(\])?(\[|\.)?/g;function Bf(r,e){r.seq.push(e),r.map[e.id]=e}function yv(r,e,t){let n=r.name,i=n.length;for(ph.lastIndex=0;;){let s=ph.exec(n),o=ph.lastIndex,a=s[1],l=s[2]==="]",h=s[3];if(l&&(a=a|0),h===void 0||h==="["&&o+2===i){Bf(t,h===void 0?new mh(a,r,e):new gh(a,r,e));break}else{let c=t.map[a];c===void 0&&(c=new vh(a),Bf(t,c)),t=c}}}var fr=class{constructor(e,t){this.seq=[],this.map={};let n=e.getProgramParameter(t,e.ACTIVE_UNIFORMS);for(let i=0;i<n;++i){let s=e.getActiveUniform(t,i),o=e.getUniformLocation(t,s.name);yv(s,o,this)}}setValue(e,t,n,i){let s=this.map[t];s!==void 0&&s.setValue(e,n,i)}setOptional(e,t,n){let i=t[n];i!==void 0&&this.setValue(e,n,i)}static upload(e,t,n,i){for(let s=0,o=t.length;s!==o;++s){let a=t[s],l=n[a.id];l.needsUpdate!==!1&&a.setValue(e,l.value,i)}}static seqWithValue(e,t){let n=[];for(let i=0,s=e.length;i!==s;++i){let o=e[i];o.id in t&&n.push(o)}return n}};function Uf(r,e,t){let n=r.createShader(e);return r.shaderSource(n,t),r.compileShader(n),n}var _v=37297,Mv=0;function Sv(r,e){let t=r.split(`
`),n=[],i=Math.max(e-6,0),s=Math.min(e+6,t.length);for(let o=i;o<s;o++){let a=o+1;n.push(`${a===e?">":" "} ${a}: ${t[o]}`)}return n.join(`
`)}var Of=new tt;function bv(r){lt._getMatrix(Of,lt.workingColorSpace,r);let e=`mat3( ${Of.elements.map(t=>t.toFixed(4))} )`;switch(lt.getTransfer(r)){case Lr:return[e,"LinearTransferOETF"];case dt:return[e,"sRGBTransferOETF"];default:return console.warn("THREE.WebGLProgram: Unsupported color space: ",r),[e,"LinearTransferOETF"]}}function zf(r,e,t){let n=r.getShaderParameter(e,r.COMPILE_STATUS),s=(r.getShaderInfoLog(e)||"").trim();if(n&&s==="")return"";let o=/ERROR: 0:(\d+)/.exec(s);if(o){let a=parseInt(o[1]);return t.toUpperCase()+`

`+s+`

`+Sv(r.getShaderSource(e),a)}else return s}function wv(r,e){let t=bv(e);return[`vec4 ${r}( vec4 value ) {`,`	return ${t[1]}( vec4( value.rgb * ${t[0]}, value.a ) );`,"}"].join(`
`)}function Ev(r,e){let t;switch(e){case tf:t="Linear";break;case nf:t="Reinhard";break;case sf:t="Cineon";break;case Ia:t="ACESFilmic";break;case of:t="AgX";break;case af:t="Neutral";break;case rf:t="Custom";break;default:console.warn("THREE.WebGLProgram: Unsupported toneMapping:",e),t="Linear"}return"vec3 "+r+"( vec3 color ) { return "+t+"ToneMapping( color ); }"}var vl=new G;function Av(){lt.getLuminanceCoefficients(vl);let r=vl.x.toFixed(4),e=vl.y.toFixed(4),t=vl.z.toFixed(4);return["float luminance( const in vec3 rgb ) {",`	const vec3 weights = vec3( ${r}, ${e}, ${t} );`,"	return dot( weights, rgb );","}"].join(`
`)}function Tv(r){return[r.extensionClipCullDistance?"#extension GL_ANGLE_clip_cull_distance : require":"",r.extensionMultiDraw?"#extension GL_ANGLE_multi_draw : require":""].filter(co).join(`
`)}function Cv(r){let e=[];for(let t in r){let n=r[t];n!==!1&&e.push("#define "+t+" "+n)}return e.join(`
`)}function Rv(r,e){let t={},n=r.getProgramParameter(e,r.ACTIVE_ATTRIBUTES);for(let i=0;i<n;i++){let s=r.getActiveAttrib(e,i),o=s.name,a=1;s.type===r.FLOAT_MAT2&&(a=2),s.type===r.FLOAT_MAT3&&(a=3),s.type===r.FLOAT_MAT4&&(a=4),t[o]={type:s.type,location:r.getAttribLocation(e,o),locationSize:a}}return t}function co(r){return r!==""}function kf(r,e){let t=e.numSpotLightShadows+e.numSpotLightMaps-e.numSpotLightShadowsWithMaps;return r.replace(/NUM_DIR_LIGHTS/g,e.numDirLights).replace(/NUM_SPOT_LIGHTS/g,e.numSpotLights).replace(/NUM_SPOT_LIGHT_MAPS/g,e.numSpotLightMaps).replace(/NUM_SPOT_LIGHT_COORDS/g,t).replace(/NUM_RECT_AREA_LIGHTS/g,e.numRectAreaLights).replace(/NUM_POINT_LIGHTS/g,e.numPointLights).replace(/NUM_HEMI_LIGHTS/g,e.numHemiLights).replace(/NUM_DIR_LIGHT_SHADOWS/g,e.numDirLightShadows).replace(/NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g,e.numSpotLightShadowsWithMaps).replace(/NUM_SPOT_LIGHT_SHADOWS/g,e.numSpotLightShadows).replace(/NUM_POINT_LIGHT_SHADOWS/g,e.numPointLightShadows)}function Vf(r,e){return r.replace(/NUM_CLIPPING_PLANES/g,e.numClippingPlanes).replace(/UNION_CLIPPING_PLANES/g,e.numClippingPlanes-e.numClipIntersection)}var Pv=/^[ \t]*#include +<([\w\d./]+)>/gm;function xh(r){return r.replace(Pv,Nv)}var Iv=new Map;function Nv(r,e){let t=it[e];if(t===void 0){let n=Iv.get(e);if(n!==void 0)t=it[n],console.warn('THREE.WebGLRenderer: Shader chunk "%s" has been deprecated. Use "%s" instead.',e,n);else throw new Error("Can not resolve #include <"+e+">")}return xh(t)}var Lv=/#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;function Hf(r){return r.replace(Lv,Dv)}function Dv(r,e,t,n){let i="";for(let s=parseInt(e);s<parseInt(t);s++)i+=n.replace(/\[\s*i\s*\]/g,"[ "+s+" ]").replace(/UNROLLED_LOOP_INDEX/g,s);return i}function Gf(r){let e=`precision ${r.precision} float;
	precision ${r.precision} int;
	precision ${r.precision} sampler2D;
	precision ${r.precision} samplerCube;
	precision ${r.precision} sampler3D;
	precision ${r.precision} sampler2DArray;
	precision ${r.precision} sampler2DShadow;
	precision ${r.precision} samplerCubeShadow;
	precision ${r.precision} sampler2DArrayShadow;
	precision ${r.precision} isampler2D;
	precision ${r.precision} isampler3D;
	precision ${r.precision} isamplerCube;
	precision ${r.precision} isampler2DArray;
	precision ${r.precision} usampler2D;
	precision ${r.precision} usampler3D;
	precision ${r.precision} usamplerCube;
	precision ${r.precision} usampler2DArray;
	`;return r.precision==="highp"?e+=`
#define HIGH_PRECISION`:r.precision==="mediump"?e+=`
#define MEDIUM_PRECISION`:r.precision==="lowp"&&(e+=`
#define LOW_PRECISION`),e}function Fv(r){let e="SHADOWMAP_TYPE_BASIC";return r.shadowMapType===Vc?e="SHADOWMAP_TYPE_PCF":r.shadowMapType===ba?e="SHADOWMAP_TYPE_PCF_SOFT":r.shadowMapType===li&&(e="SHADOWMAP_TYPE_VSM"),e}function Bv(r){let e="ENVMAP_TYPE_CUBE";if(r.envMap)switch(r.envMapMode){case Ms:case Ss:e="ENVMAP_TYPE_CUBE";break;case no:e="ENVMAP_TYPE_CUBE_UV";break}return e}function Uv(r){let e="ENVMAP_MODE_REFLECTION";if(r.envMap)switch(r.envMapMode){case Ss:e="ENVMAP_MODE_REFRACTION";break}return e}function Ov(r){let e="ENVMAP_BLENDING_NONE";if(r.envMap)switch(r.combine){case qc:e="ENVMAP_BLENDING_MULTIPLY";break;case Qu:e="ENVMAP_BLENDING_MIX";break;case ef:e="ENVMAP_BLENDING_ADD";break}return e}function zv(r){let e=r.envMapCubeUVHeight;if(e===null)return null;let t=Math.log2(e)-2,n=1/e;return{texelWidth:1/(3*Math.max(Math.pow(2,t),112)),texelHeight:n,maxMip:t}}function kv(r,e,t,n){let i=r.getContext(),s=t.defines,o=t.vertexShader,a=t.fragmentShader,l=Fv(t),h=Bv(t),f=Uv(t),c=Ov(t),u=zv(t),d=Tv(t),p=Cv(s),v=i.createProgram(),g,m,_=t.glslVersion?"#version "+t.glslVersion+`
`:"";t.isRawShaderMaterial?(g=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,p].filter(co).join(`
`),g.length>0&&(g+=`
`),m=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,p].filter(co).join(`
`),m.length>0&&(m+=`
`)):(g=[Gf(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,p,t.extensionClipCullDistance?"#define USE_CLIP_DISTANCE":"",t.batching?"#define USE_BATCHING":"",t.batchingColor?"#define USE_BATCHING_COLOR":"",t.instancing?"#define USE_INSTANCING":"",t.instancingColor?"#define USE_INSTANCING_COLOR":"",t.instancingMorph?"#define USE_INSTANCING_MORPH":"",t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.map?"#define USE_MAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+f:"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.displacementMap?"#define USE_DISPLACEMENTMAP":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.mapUv?"#define MAP_UV "+t.mapUv:"",t.alphaMapUv?"#define ALPHAMAP_UV "+t.alphaMapUv:"",t.lightMapUv?"#define LIGHTMAP_UV "+t.lightMapUv:"",t.aoMapUv?"#define AOMAP_UV "+t.aoMapUv:"",t.emissiveMapUv?"#define EMISSIVEMAP_UV "+t.emissiveMapUv:"",t.bumpMapUv?"#define BUMPMAP_UV "+t.bumpMapUv:"",t.normalMapUv?"#define NORMALMAP_UV "+t.normalMapUv:"",t.displacementMapUv?"#define DISPLACEMENTMAP_UV "+t.displacementMapUv:"",t.metalnessMapUv?"#define METALNESSMAP_UV "+t.metalnessMapUv:"",t.roughnessMapUv?"#define ROUGHNESSMAP_UV "+t.roughnessMapUv:"",t.anisotropyMapUv?"#define ANISOTROPYMAP_UV "+t.anisotropyMapUv:"",t.clearcoatMapUv?"#define CLEARCOATMAP_UV "+t.clearcoatMapUv:"",t.clearcoatNormalMapUv?"#define CLEARCOAT_NORMALMAP_UV "+t.clearcoatNormalMapUv:"",t.clearcoatRoughnessMapUv?"#define CLEARCOAT_ROUGHNESSMAP_UV "+t.clearcoatRoughnessMapUv:"",t.iridescenceMapUv?"#define IRIDESCENCEMAP_UV "+t.iridescenceMapUv:"",t.iridescenceThicknessMapUv?"#define IRIDESCENCE_THICKNESSMAP_UV "+t.iridescenceThicknessMapUv:"",t.sheenColorMapUv?"#define SHEEN_COLORMAP_UV "+t.sheenColorMapUv:"",t.sheenRoughnessMapUv?"#define SHEEN_ROUGHNESSMAP_UV "+t.sheenRoughnessMapUv:"",t.specularMapUv?"#define SPECULARMAP_UV "+t.specularMapUv:"",t.specularColorMapUv?"#define SPECULAR_COLORMAP_UV "+t.specularColorMapUv:"",t.specularIntensityMapUv?"#define SPECULAR_INTENSITYMAP_UV "+t.specularIntensityMapUv:"",t.transmissionMapUv?"#define TRANSMISSIONMAP_UV "+t.transmissionMapUv:"",t.thicknessMapUv?"#define THICKNESSMAP_UV "+t.thicknessMapUv:"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexColors?"#define USE_COLOR":"",t.vertexAlphas?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.flatShading?"#define FLAT_SHADED":"",t.skinning?"#define USE_SKINNING":"",t.morphTargets?"#define USE_MORPHTARGETS":"",t.morphNormals&&t.flatShading===!1?"#define USE_MORPHNORMALS":"",t.morphColors?"#define USE_MORPHCOLORS":"",t.morphTargetsCount>0?"#define MORPHTARGETS_TEXTURE_STRIDE "+t.morphTextureStride:"",t.morphTargetsCount>0?"#define MORPHTARGETS_COUNT "+t.morphTargetsCount:"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+l:"",t.sizeAttenuation?"#define USE_SIZEATTENUATION":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",t.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 modelMatrix;","uniform mat4 modelViewMatrix;","uniform mat4 projectionMatrix;","uniform mat4 viewMatrix;","uniform mat3 normalMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;","#ifdef USE_INSTANCING","	attribute mat4 instanceMatrix;","#endif","#ifdef USE_INSTANCING_COLOR","	attribute vec3 instanceColor;","#endif","#ifdef USE_INSTANCING_MORPH","	uniform sampler2D morphTexture;","#endif","attribute vec3 position;","attribute vec3 normal;","attribute vec2 uv;","#ifdef USE_UV1","	attribute vec2 uv1;","#endif","#ifdef USE_UV2","	attribute vec2 uv2;","#endif","#ifdef USE_UV3","	attribute vec2 uv3;","#endif","#ifdef USE_TANGENT","	attribute vec4 tangent;","#endif","#if defined( USE_COLOR_ALPHA )","	attribute vec4 color;","#elif defined( USE_COLOR )","	attribute vec3 color;","#endif","#ifdef USE_SKINNING","	attribute vec4 skinIndex;","	attribute vec4 skinWeight;","#endif",`
`].filter(co).join(`
`),m=[Gf(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,p,t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.alphaToCoverage?"#define ALPHA_TO_COVERAGE":"",t.map?"#define USE_MAP":"",t.matcap?"#define USE_MATCAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+h:"",t.envMap?"#define "+f:"",t.envMap?"#define "+c:"",u?"#define CUBEUV_TEXEL_WIDTH "+u.texelWidth:"",u?"#define CUBEUV_TEXEL_HEIGHT "+u.texelHeight:"",u?"#define CUBEUV_MAX_MIP "+u.maxMip+".0":"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoat?"#define USE_CLEARCOAT":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.dispersion?"#define USE_DISPERSION":"",t.iridescence?"#define USE_IRIDESCENCE":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaTest?"#define USE_ALPHATEST":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.sheen?"#define USE_SHEEN":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexColors||t.instancingColor||t.batchingColor?"#define USE_COLOR":"",t.vertexAlphas?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.gradientMap?"#define USE_GRADIENTMAP":"",t.flatShading?"#define FLAT_SHADED":"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+l:"",t.premultipliedAlpha?"#define PREMULTIPLIED_ALPHA":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.decodeVideoTexture?"#define DECODE_VIDEO_TEXTURE":"",t.decodeVideoTextureEmissive?"#define DECODE_VIDEO_TEXTURE_EMISSIVE":"",t.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",t.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 viewMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;",t.toneMapping!==Ti?"#define TONE_MAPPING":"",t.toneMapping!==Ti?it.tonemapping_pars_fragment:"",t.toneMapping!==Ti?Ev("toneMapping",t.toneMapping):"",t.dithering?"#define DITHERING":"",t.opaque?"#define OPAQUE":"",it.colorspace_pars_fragment,wv("linearToOutputTexel",t.outputColorSpace),Av(),t.useDepthPacking?"#define DEPTH_PACKING "+t.depthPacking:"",`
`].filter(co).join(`
`)),o=xh(o),o=kf(o,t),o=Vf(o,t),a=xh(a),a=kf(a,t),a=Vf(a,t),o=Hf(o),a=Hf(a),t.isRawShaderMaterial!==!0&&(_=`#version 300 es
`,g=[d,"#define attribute in","#define varying out","#define texture2D texture"].join(`
`)+`
`+g,m=["#define varying in",t.glslVersion===ih?"":"layout(location = 0) out highp vec4 pc_fragColor;",t.glslVersion===ih?"":"#define gl_FragColor pc_fragColor","#define gl_FragDepthEXT gl_FragDepth","#define texture2D texture","#define textureCube texture","#define texture2DProj textureProj","#define texture2DLodEXT textureLod","#define texture2DProjLodEXT textureProjLod","#define textureCubeLodEXT textureLod","#define texture2DGradEXT textureGrad","#define texture2DProjGradEXT textureProjGrad","#define textureCubeGradEXT textureGrad"].join(`
`)+`
`+m);let x=_+g+o,y=_+m+a,S=Uf(i,i.VERTEX_SHADER,x),M=Uf(i,i.FRAGMENT_SHADER,y);i.attachShader(v,S),i.attachShader(v,M),t.index0AttributeName!==void 0?i.bindAttribLocation(v,0,t.index0AttributeName):t.morphTargets===!0&&i.bindAttribLocation(v,0,"position"),i.linkProgram(v);function E(T){if(r.debug.checkShaderErrors){let F=i.getProgramInfoLog(v)||"",D=i.getShaderInfoLog(S)||"",C=i.getShaderInfoLog(M)||"",P=F.trim(),N=D.trim(),z=C.trim(),O=!0,K=!0;if(i.getProgramParameter(v,i.LINK_STATUS)===!1)if(O=!1,typeof r.debug.onShaderError=="function")r.debug.onShaderError(i,v,S,M);else{let ee=zf(i,S,"vertex"),oe=zf(i,M,"fragment");console.error("THREE.WebGLProgram: Shader Error "+i.getError()+" - VALIDATE_STATUS "+i.getProgramParameter(v,i.VALIDATE_STATUS)+`

Material Name: `+T.name+`
Material Type: `+T.type+`

Program Info Log: `+P+`
`+ee+`
`+oe)}else P!==""?console.warn("THREE.WebGLProgram: Program Info Log:",P):(N===""||z==="")&&(K=!1);K&&(T.diagnostics={runnable:O,programLog:P,vertexShader:{log:N,prefix:g},fragmentShader:{log:z,prefix:m}})}i.deleteShader(S),i.deleteShader(M),A=new fr(i,v),b=Rv(i,v)}let A;this.getUniforms=function(){return A===void 0&&E(this),A};let b;this.getAttributes=function(){return b===void 0&&E(this),b};let w=t.rendererExtensionParallelShaderCompile===!1;return this.isReady=function(){return w===!1&&(w=i.getProgramParameter(v,_v)),w},this.destroy=function(){n.releaseStatesOfProgram(this),i.deleteProgram(v),this.program=void 0},this.type=t.shaderType,this.name=t.shaderName,this.id=Mv++,this.cacheKey=e,this.usedTimes=1,this.program=v,this.vertexShader=S,this.fragmentShader=M,this}var Vv=0,yh=class{constructor(){this.shaderCache=new Map,this.materialCache=new Map}update(e){let t=e.vertexShader,n=e.fragmentShader,i=this._getShaderStage(t),s=this._getShaderStage(n),o=this._getShaderCacheForMaterial(e);return o.has(i)===!1&&(o.add(i),i.usedTimes++),o.has(s)===!1&&(o.add(s),s.usedTimes++),this}remove(e){let t=this.materialCache.get(e);for(let n of t)n.usedTimes--,n.usedTimes===0&&this.shaderCache.delete(n.code);return this.materialCache.delete(e),this}getVertexShaderID(e){return this._getShaderStage(e.vertexShader).id}getFragmentShaderID(e){return this._getShaderStage(e.fragmentShader).id}dispose(){this.shaderCache.clear(),this.materialCache.clear()}_getShaderCacheForMaterial(e){let t=this.materialCache,n=t.get(e);return n===void 0&&(n=new Set,t.set(e,n)),n}_getShaderStage(e){let t=this.shaderCache,n=t.get(e);return n===void 0&&(n=new _h(e),t.set(e,n)),n}},_h=class{constructor(e){this.id=Vv++,this.code=e,this.usedTimes=0}};function Hv(r,e,t,n,i,s,o){let a=new Qs,l=new yh,h=new Set,f=[],c=i.logarithmicDepthBuffer,u=i.vertexTextures,d=i.precision,p={MeshDepthMaterial:"depth",MeshDistanceMaterial:"distanceRGBA",MeshNormalMaterial:"normal",MeshBasicMaterial:"basic",MeshLambertMaterial:"lambert",MeshPhongMaterial:"phong",MeshToonMaterial:"toon",MeshStandardMaterial:"physical",MeshPhysicalMaterial:"physical",MeshMatcapMaterial:"matcap",LineBasicMaterial:"basic",LineDashedMaterial:"dashed",PointsMaterial:"points",ShadowMaterial:"shadow",SpriteMaterial:"sprite"};function v(b){return h.add(b),b===0?"uv":`uv${b}`}function g(b,w,T,F,D){let C=F.fog,P=D.geometry,N=b.isMeshStandardMaterial?F.environment:null,z=(b.isMeshStandardMaterial?t:e).get(b.envMap||N),O=z&&z.mapping===no?z.image.height:null,K=p[b.type];b.precision!==null&&(d=i.getMaxPrecision(b.precision),d!==b.precision&&console.warn("THREE.WebGLProgram.getParameters:",b.precision,"not supported, using",d,"instead."));let ee=P.morphAttributes.position||P.morphAttributes.normal||P.morphAttributes.color,oe=ee!==void 0?ee.length:0,ae=0;P.morphAttributes.position!==void 0&&(ae=1),P.morphAttributes.normal!==void 0&&(ae=2),P.morphAttributes.color!==void 0&&(ae=3);let Ge,Ce,We,j;if(K){let ct=hi[K];Ge=ct.vertexShader,Ce=ct.fragmentShader}else Ge=b.vertexShader,Ce=b.fragmentShader,l.update(b),We=l.getVertexShaderID(b),j=l.getFragmentShaderID(b);let ne=r.getRenderTarget(),ye=r.state.buffers.depth.getReversed(),De=D.isInstancedMesh===!0,Se=D.isBatchedMesh===!0,st=!!b.map,Ct=!!b.matcap,U=!!z,ft=!!b.aoMap,$e=!!b.lightMap,ke=!!b.bumpMap,be=!!b.normalMap,ht=!!b.displacementMap,Ee=!!b.emissiveMap,Ke=!!b.metalnessMap,yt=!!b.roughnessMap,gt=b.anisotropy>0,B=b.clearcoat>0,I=b.dispersion>0,X=b.iridescence>0,te=b.sheen>0,se=b.transmission>0,Q=gt&&!!b.anisotropyMap,Ue=B&&!!b.clearcoatMap,fe=B&&!!b.clearcoatNormalMap,Ne=B&&!!b.clearcoatRoughnessMap,Fe=X&&!!b.iridescenceMap,he=X&&!!b.iridescenceThicknessMap,Me=te&&!!b.sheenColorMap,He=te&&!!b.sheenRoughnessMap,Be=!!b.specularMap,me=!!b.specularColorMap,Qe=!!b.specularIntensityMap,k=se&&!!b.transmissionMap,ue=se&&!!b.thicknessMap,de=!!b.gradientMap,Ae=!!b.alphaMap,le=b.alphaTest>0,ie=!!b.alphaHash,Pe=!!b.extensions,Je=Ti;b.toneMapped&&(ne===null||ne.isXRRenderTarget===!0)&&(Je=r.toneMapping);let mt={shaderID:K,shaderType:b.type,shaderName:b.name,vertexShader:Ge,fragmentShader:Ce,defines:b.defines,customVertexShaderID:We,customFragmentShaderID:j,isRawShaderMaterial:b.isRawShaderMaterial===!0,glslVersion:b.glslVersion,precision:d,batching:Se,batchingColor:Se&&D._colorsTexture!==null,instancing:De,instancingColor:De&&D.instanceColor!==null,instancingMorph:De&&D.morphTexture!==null,supportsVertexTextures:u,outputColorSpace:ne===null?r.outputColorSpace:ne.isXRRenderTarget===!0?ne.texture.colorSpace:gs,alphaToCoverage:!!b.alphaToCoverage,map:st,matcap:Ct,envMap:U,envMapMode:U&&z.mapping,envMapCubeUVHeight:O,aoMap:ft,lightMap:$e,bumpMap:ke,normalMap:be,displacementMap:u&&ht,emissiveMap:Ee,normalMapObjectSpace:be&&b.normalMapType===uf,normalMapTangentSpace:be&&b.normalMapType===th,metalnessMap:Ke,roughnessMap:yt,anisotropy:gt,anisotropyMap:Q,clearcoat:B,clearcoatMap:Ue,clearcoatNormalMap:fe,clearcoatRoughnessMap:Ne,dispersion:I,iridescence:X,iridescenceMap:Fe,iridescenceThicknessMap:he,sheen:te,sheenColorMap:Me,sheenRoughnessMap:He,specularMap:Be,specularColorMap:me,specularIntensityMap:Qe,transmission:se,transmissionMap:k,thicknessMap:ue,gradientMap:de,opaque:b.transparent===!1&&b.blending===ps&&b.alphaToCoverage===!1,alphaMap:Ae,alphaTest:le,alphaHash:ie,combine:b.combine,mapUv:st&&v(b.map.channel),aoMapUv:ft&&v(b.aoMap.channel),lightMapUv:$e&&v(b.lightMap.channel),bumpMapUv:ke&&v(b.bumpMap.channel),normalMapUv:be&&v(b.normalMap.channel),displacementMapUv:ht&&v(b.displacementMap.channel),emissiveMapUv:Ee&&v(b.emissiveMap.channel),metalnessMapUv:Ke&&v(b.metalnessMap.channel),roughnessMapUv:yt&&v(b.roughnessMap.channel),anisotropyMapUv:Q&&v(b.anisotropyMap.channel),clearcoatMapUv:Ue&&v(b.clearcoatMap.channel),clearcoatNormalMapUv:fe&&v(b.clearcoatNormalMap.channel),clearcoatRoughnessMapUv:Ne&&v(b.clearcoatRoughnessMap.channel),iridescenceMapUv:Fe&&v(b.iridescenceMap.channel),iridescenceThicknessMapUv:he&&v(b.iridescenceThicknessMap.channel),sheenColorMapUv:Me&&v(b.sheenColorMap.channel),sheenRoughnessMapUv:He&&v(b.sheenRoughnessMap.channel),specularMapUv:Be&&v(b.specularMap.channel),specularColorMapUv:me&&v(b.specularColorMap.channel),specularIntensityMapUv:Qe&&v(b.specularIntensityMap.channel),transmissionMapUv:k&&v(b.transmissionMap.channel),thicknessMapUv:ue&&v(b.thicknessMap.channel),alphaMapUv:Ae&&v(b.alphaMap.channel),vertexTangents:!!P.attributes.tangent&&(be||gt),vertexColors:b.vertexColors,vertexAlphas:b.vertexColors===!0&&!!P.attributes.color&&P.attributes.color.itemSize===4,pointsUvs:D.isPoints===!0&&!!P.attributes.uv&&(st||Ae),fog:!!C,useFog:b.fog===!0,fogExp2:!!C&&C.isFogExp2,flatShading:b.flatShading===!0&&b.wireframe===!1,sizeAttenuation:b.sizeAttenuation===!0,logarithmicDepthBuffer:c,reversedDepthBuffer:ye,skinning:D.isSkinnedMesh===!0,morphTargets:P.morphAttributes.position!==void 0,morphNormals:P.morphAttributes.normal!==void 0,morphColors:P.morphAttributes.color!==void 0,morphTargetsCount:oe,morphTextureStride:ae,numDirLights:w.directional.length,numPointLights:w.point.length,numSpotLights:w.spot.length,numSpotLightMaps:w.spotLightMap.length,numRectAreaLights:w.rectArea.length,numHemiLights:w.hemi.length,numDirLightShadows:w.directionalShadowMap.length,numPointLightShadows:w.pointShadowMap.length,numSpotLightShadows:w.spotShadowMap.length,numSpotLightShadowsWithMaps:w.numSpotLightShadowsWithMaps,numLightProbes:w.numLightProbes,numClippingPlanes:o.numPlanes,numClipIntersection:o.numIntersection,dithering:b.dithering,shadowMapEnabled:r.shadowMap.enabled&&T.length>0,shadowMapType:r.shadowMap.type,toneMapping:Je,decodeVideoTexture:st&&b.map.isVideoTexture===!0&&lt.getTransfer(b.map.colorSpace)===dt,decodeVideoTextureEmissive:Ee&&b.emissiveMap.isVideoTexture===!0&&lt.getTransfer(b.emissiveMap.colorSpace)===dt,premultipliedAlpha:b.premultipliedAlpha,doubleSided:b.side===bn,flipSided:b.side===on,useDepthPacking:b.depthPacking>=0,depthPacking:b.depthPacking||0,index0AttributeName:b.index0AttributeName,extensionClipCullDistance:Pe&&b.extensions.clipCullDistance===!0&&n.has("WEBGL_clip_cull_distance"),extensionMultiDraw:(Pe&&b.extensions.multiDraw===!0||Se)&&n.has("WEBGL_multi_draw"),rendererExtensionParallelShaderCompile:n.has("KHR_parallel_shader_compile"),customProgramCacheKey:b.customProgramCacheKey()};return mt.vertexUv1s=h.has(1),mt.vertexUv2s=h.has(2),mt.vertexUv3s=h.has(3),h.clear(),mt}function m(b){let w=[];if(b.shaderID?w.push(b.shaderID):(w.push(b.customVertexShaderID),w.push(b.customFragmentShaderID)),b.defines!==void 0)for(let T in b.defines)w.push(T),w.push(b.defines[T]);return b.isRawShaderMaterial===!1&&(_(w,b),x(w,b),w.push(r.outputColorSpace)),w.push(b.customProgramCacheKey),w.join()}function _(b,w){b.push(w.precision),b.push(w.outputColorSpace),b.push(w.envMapMode),b.push(w.envMapCubeUVHeight),b.push(w.mapUv),b.push(w.alphaMapUv),b.push(w.lightMapUv),b.push(w.aoMapUv),b.push(w.bumpMapUv),b.push(w.normalMapUv),b.push(w.displacementMapUv),b.push(w.emissiveMapUv),b.push(w.metalnessMapUv),b.push(w.roughnessMapUv),b.push(w.anisotropyMapUv),b.push(w.clearcoatMapUv),b.push(w.clearcoatNormalMapUv),b.push(w.clearcoatRoughnessMapUv),b.push(w.iridescenceMapUv),b.push(w.iridescenceThicknessMapUv),b.push(w.sheenColorMapUv),b.push(w.sheenRoughnessMapUv),b.push(w.specularMapUv),b.push(w.specularColorMapUv),b.push(w.specularIntensityMapUv),b.push(w.transmissionMapUv),b.push(w.thicknessMapUv),b.push(w.combine),b.push(w.fogExp2),b.push(w.sizeAttenuation),b.push(w.morphTargetsCount),b.push(w.morphAttributeCount),b.push(w.numDirLights),b.push(w.numPointLights),b.push(w.numSpotLights),b.push(w.numSpotLightMaps),b.push(w.numHemiLights),b.push(w.numRectAreaLights),b.push(w.numDirLightShadows),b.push(w.numPointLightShadows),b.push(w.numSpotLightShadows),b.push(w.numSpotLightShadowsWithMaps),b.push(w.numLightProbes),b.push(w.shadowMapType),b.push(w.toneMapping),b.push(w.numClippingPlanes),b.push(w.numClipIntersection),b.push(w.depthPacking)}function x(b,w){a.disableAll(),w.supportsVertexTextures&&a.enable(0),w.instancing&&a.enable(1),w.instancingColor&&a.enable(2),w.instancingMorph&&a.enable(3),w.matcap&&a.enable(4),w.envMap&&a.enable(5),w.normalMapObjectSpace&&a.enable(6),w.normalMapTangentSpace&&a.enable(7),w.clearcoat&&a.enable(8),w.iridescence&&a.enable(9),w.alphaTest&&a.enable(10),w.vertexColors&&a.enable(11),w.vertexAlphas&&a.enable(12),w.vertexUv1s&&a.enable(13),w.vertexUv2s&&a.enable(14),w.vertexUv3s&&a.enable(15),w.vertexTangents&&a.enable(16),w.anisotropy&&a.enable(17),w.alphaHash&&a.enable(18),w.batching&&a.enable(19),w.dispersion&&a.enable(20),w.batchingColor&&a.enable(21),w.gradientMap&&a.enable(22),b.push(a.mask),a.disableAll(),w.fog&&a.enable(0),w.useFog&&a.enable(1),w.flatShading&&a.enable(2),w.logarithmicDepthBuffer&&a.enable(3),w.reversedDepthBuffer&&a.enable(4),w.skinning&&a.enable(5),w.morphTargets&&a.enable(6),w.morphNormals&&a.enable(7),w.morphColors&&a.enable(8),w.premultipliedAlpha&&a.enable(9),w.shadowMapEnabled&&a.enable(10),w.doubleSided&&a.enable(11),w.flipSided&&a.enable(12),w.useDepthPacking&&a.enable(13),w.dithering&&a.enable(14),w.transmission&&a.enable(15),w.sheen&&a.enable(16),w.opaque&&a.enable(17),w.pointsUvs&&a.enable(18),w.decodeVideoTexture&&a.enable(19),w.decodeVideoTextureEmissive&&a.enable(20),w.alphaToCoverage&&a.enable(21),b.push(a.mask)}function y(b){let w=p[b.type],T;if(w){let F=hi[w];T=Sf.clone(F.uniforms)}else T=b.uniforms;return T}function S(b,w){let T;for(let F=0,D=f.length;F<D;F++){let C=f[F];if(C.cacheKey===w){T=C,++T.usedTimes;break}}return T===void 0&&(T=new kv(r,w,b,s),f.push(T)),T}function M(b){if(--b.usedTimes===0){let w=f.indexOf(b);f[w]=f[f.length-1],f.pop(),b.destroy()}}function E(b){l.remove(b)}function A(){l.dispose()}return{getParameters:g,getProgramCacheKey:m,getUniforms:y,acquireProgram:S,releaseProgram:M,releaseShaderCache:E,programs:f,dispose:A}}function Gv(){let r=new WeakMap;function e(o){return r.has(o)}function t(o){let a=r.get(o);return a===void 0&&(a={},r.set(o,a)),a}function n(o){r.delete(o)}function i(o,a,l){r.get(o)[a]=l}function s(){r=new WeakMap}return{has:e,get:t,remove:n,update:i,dispose:s}}function Wv(r,e){return r.groupOrder!==e.groupOrder?r.groupOrder-e.groupOrder:r.renderOrder!==e.renderOrder?r.renderOrder-e.renderOrder:r.material.id!==e.material.id?r.material.id-e.material.id:r.z!==e.z?r.z-e.z:r.id-e.id}function Wf(r,e){return r.groupOrder!==e.groupOrder?r.groupOrder-e.groupOrder:r.renderOrder!==e.renderOrder?r.renderOrder-e.renderOrder:r.z!==e.z?e.z-r.z:r.id-e.id}function qf(){let r=[],e=0,t=[],n=[],i=[];function s(){e=0,t.length=0,n.length=0,i.length=0}function o(c,u,d,p,v,g){let m=r[e];return m===void 0?(m={id:c.id,object:c,geometry:u,material:d,groupOrder:p,renderOrder:c.renderOrder,z:v,group:g},r[e]=m):(m.id=c.id,m.object=c,m.geometry=u,m.material=d,m.groupOrder=p,m.renderOrder=c.renderOrder,m.z=v,m.group=g),e++,m}function a(c,u,d,p,v,g){let m=o(c,u,d,p,v,g);d.transmission>0?n.push(m):d.transparent===!0?i.push(m):t.push(m)}function l(c,u,d,p,v,g){let m=o(c,u,d,p,v,g);d.transmission>0?n.unshift(m):d.transparent===!0?i.unshift(m):t.unshift(m)}function h(c,u){t.length>1&&t.sort(c||Wv),n.length>1&&n.sort(u||Wf),i.length>1&&i.sort(u||Wf)}function f(){for(let c=e,u=r.length;c<u;c++){let d=r[c];if(d.id===null)break;d.id=null,d.object=null,d.geometry=null,d.material=null,d.group=null}}return{opaque:t,transmissive:n,transparent:i,init:s,push:a,unshift:l,finish:f,sort:h}}function qv(){let r=new WeakMap;function e(n,i){let s=r.get(n),o;return s===void 0?(o=new qf,r.set(n,[o])):i>=s.length?(o=new qf,s.push(o)):o=s[i],o}function t(){r=new WeakMap}return{get:e,dispose:t}}function Xv(){let r={};return{get:function(e){if(r[e.id]!==void 0)return r[e.id];let t;switch(e.type){case"DirectionalLight":t={direction:new G,color:new ot};break;case"SpotLight":t={position:new G,direction:new G,color:new ot,distance:0,coneCos:0,penumbraCos:0,decay:0};break;case"PointLight":t={position:new G,color:new ot,distance:0,decay:0};break;case"HemisphereLight":t={direction:new G,skyColor:new ot,groundColor:new ot};break;case"RectAreaLight":t={color:new ot,position:new G,halfWidth:new G,halfHeight:new G};break}return r[e.id]=t,t}}}function $v(){let r={};return{get:function(e){if(r[e.id]!==void 0)return r[e.id];let t;switch(e.type){case"DirectionalLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new et};break;case"SpotLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new et};break;case"PointLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new et,shadowCameraNear:1,shadowCameraFar:1e3};break}return r[e.id]=t,t}}}var Yv=0;function Zv(r,e){return(e.castShadow?2:0)-(r.castShadow?2:0)+(e.map?1:0)-(r.map?1:0)}function Kv(r){let e=new Xv,t=$v(),n={version:0,hash:{directionalLength:-1,pointLength:-1,spotLength:-1,rectAreaLength:-1,hemiLength:-1,numDirectionalShadows:-1,numPointShadows:-1,numSpotShadows:-1,numSpotMaps:-1,numLightProbes:-1},ambient:[0,0,0],probe:[],directional:[],directionalShadow:[],directionalShadowMap:[],directionalShadowMatrix:[],spot:[],spotLightMap:[],spotShadow:[],spotShadowMap:[],spotLightMatrix:[],rectArea:[],rectAreaLTC1:null,rectAreaLTC2:null,point:[],pointShadow:[],pointShadowMap:[],pointShadowMatrix:[],hemi:[],numSpotLightShadowsWithMaps:0,numLightProbes:0};for(let h=0;h<9;h++)n.probe.push(new G);let i=new G,s=new Mt,o=new Mt;function a(h){let f=0,c=0,u=0;for(let b=0;b<9;b++)n.probe[b].set(0,0,0);let d=0,p=0,v=0,g=0,m=0,_=0,x=0,y=0,S=0,M=0,E=0;h.sort(Zv);for(let b=0,w=h.length;b<w;b++){let T=h[b],F=T.color,D=T.intensity,C=T.distance,P=T.shadow&&T.shadow.map?T.shadow.map.texture:null;if(T.isAmbientLight)f+=F.r*D,c+=F.g*D,u+=F.b*D;else if(T.isLightProbe){for(let N=0;N<9;N++)n.probe[N].addScaledVector(T.sh.coefficients[N],D);E++}else if(T.isDirectionalLight){let N=e.get(T);if(N.color.copy(T.color).multiplyScalar(T.intensity),T.castShadow){let z=T.shadow,O=t.get(T);O.shadowIntensity=z.intensity,O.shadowBias=z.bias,O.shadowNormalBias=z.normalBias,O.shadowRadius=z.radius,O.shadowMapSize=z.mapSize,n.directionalShadow[d]=O,n.directionalShadowMap[d]=P,n.directionalShadowMatrix[d]=T.shadow.matrix,_++}n.directional[d]=N,d++}else if(T.isSpotLight){let N=e.get(T);N.position.setFromMatrixPosition(T.matrixWorld),N.color.copy(F).multiplyScalar(D),N.distance=C,N.coneCos=Math.cos(T.angle),N.penumbraCos=Math.cos(T.angle*(1-T.penumbra)),N.decay=T.decay,n.spot[v]=N;let z=T.shadow;if(T.map&&(n.spotLightMap[S]=T.map,S++,z.updateMatrices(T),T.castShadow&&M++),n.spotLightMatrix[v]=z.matrix,T.castShadow){let O=t.get(T);O.shadowIntensity=z.intensity,O.shadowBias=z.bias,O.shadowNormalBias=z.normalBias,O.shadowRadius=z.radius,O.shadowMapSize=z.mapSize,n.spotShadow[v]=O,n.spotShadowMap[v]=P,y++}v++}else if(T.isRectAreaLight){let N=e.get(T);N.color.copy(F).multiplyScalar(D),N.halfWidth.set(T.width*.5,0,0),N.halfHeight.set(0,T.height*.5,0),n.rectArea[g]=N,g++}else if(T.isPointLight){let N=e.get(T);if(N.color.copy(T.color).multiplyScalar(T.intensity),N.distance=T.distance,N.decay=T.decay,T.castShadow){let z=T.shadow,O=t.get(T);O.shadowIntensity=z.intensity,O.shadowBias=z.bias,O.shadowNormalBias=z.normalBias,O.shadowRadius=z.radius,O.shadowMapSize=z.mapSize,O.shadowCameraNear=z.camera.near,O.shadowCameraFar=z.camera.far,n.pointShadow[p]=O,n.pointShadowMap[p]=P,n.pointShadowMatrix[p]=T.shadow.matrix,x++}n.point[p]=N,p++}else if(T.isHemisphereLight){let N=e.get(T);N.skyColor.copy(T.color).multiplyScalar(D),N.groundColor.copy(T.groundColor).multiplyScalar(D),n.hemi[m]=N,m++}}g>0&&(r.has("OES_texture_float_linear")===!0?(n.rectAreaLTC1=ve.LTC_FLOAT_1,n.rectAreaLTC2=ve.LTC_FLOAT_2):(n.rectAreaLTC1=ve.LTC_HALF_1,n.rectAreaLTC2=ve.LTC_HALF_2)),n.ambient[0]=f,n.ambient[1]=c,n.ambient[2]=u;let A=n.hash;(A.directionalLength!==d||A.pointLength!==p||A.spotLength!==v||A.rectAreaLength!==g||A.hemiLength!==m||A.numDirectionalShadows!==_||A.numPointShadows!==x||A.numSpotShadows!==y||A.numSpotMaps!==S||A.numLightProbes!==E)&&(n.directional.length=d,n.spot.length=v,n.rectArea.length=g,n.point.length=p,n.hemi.length=m,n.directionalShadow.length=_,n.directionalShadowMap.length=_,n.pointShadow.length=x,n.pointShadowMap.length=x,n.spotShadow.length=y,n.spotShadowMap.length=y,n.directionalShadowMatrix.length=_,n.pointShadowMatrix.length=x,n.spotLightMatrix.length=y+S-M,n.spotLightMap.length=S,n.numSpotLightShadowsWithMaps=M,n.numLightProbes=E,A.directionalLength=d,A.pointLength=p,A.spotLength=v,A.rectAreaLength=g,A.hemiLength=m,A.numDirectionalShadows=_,A.numPointShadows=x,A.numSpotShadows=y,A.numSpotMaps=S,A.numLightProbes=E,n.version=Yv++)}function l(h,f){let c=0,u=0,d=0,p=0,v=0,g=f.matrixWorldInverse;for(let m=0,_=h.length;m<_;m++){let x=h[m];if(x.isDirectionalLight){let y=n.directional[c];y.direction.setFromMatrixPosition(x.matrixWorld),i.setFromMatrixPosition(x.target.matrixWorld),y.direction.sub(i),y.direction.transformDirection(g),c++}else if(x.isSpotLight){let y=n.spot[d];y.position.setFromMatrixPosition(x.matrixWorld),y.position.applyMatrix4(g),y.direction.setFromMatrixPosition(x.matrixWorld),i.setFromMatrixPosition(x.target.matrixWorld),y.direction.sub(i),y.direction.transformDirection(g),d++}else if(x.isRectAreaLight){let y=n.rectArea[p];y.position.setFromMatrixPosition(x.matrixWorld),y.position.applyMatrix4(g),o.identity(),s.copy(x.matrixWorld),s.premultiply(g),o.extractRotation(s),y.halfWidth.set(x.width*.5,0,0),y.halfHeight.set(0,x.height*.5,0),y.halfWidth.applyMatrix4(o),y.halfHeight.applyMatrix4(o),p++}else if(x.isPointLight){let y=n.point[u];y.position.setFromMatrixPosition(x.matrixWorld),y.position.applyMatrix4(g),u++}else if(x.isHemisphereLight){let y=n.hemi[v];y.direction.setFromMatrixPosition(x.matrixWorld),y.direction.transformDirection(g),v++}}}return{setup:a,setupView:l,state:n}}function Xf(r){let e=new Kv(r),t=[],n=[];function i(f){h.camera=f,t.length=0,n.length=0}function s(f){t.push(f)}function o(f){n.push(f)}function a(){e.setup(t)}function l(f){e.setupView(t,f)}let h={lightsArray:t,shadowsArray:n,camera:null,lights:e,transmissionRenderTarget:{}};return{init:i,state:h,setupLights:a,setupLightsView:l,pushLight:s,pushShadow:o}}function Jv(r){let e=new WeakMap;function t(i,s=0){let o=e.get(i),a;return o===void 0?(a=new Xf(r),e.set(i,[a])):s>=o.length?(a=new Xf(r),o.push(a)):a=o[s],a}function n(){e=new WeakMap}return{get:t,dispose:n}}var jv=`void main() {
	gl_Position = vec4( position, 1.0 );
}`,Qv=`uniform sampler2D shadow_pass;
uniform vec2 resolution;
uniform float radius;
#include <packing>
void main() {
	const float samples = float( VSM_SAMPLES );
	float mean = 0.0;
	float squared_mean = 0.0;
	float uvStride = samples <= 1.0 ? 0.0 : 2.0 / ( samples - 1.0 );
	float uvStart = samples <= 1.0 ? 0.0 : - 1.0;
	for ( float i = 0.0; i < samples; i ++ ) {
		float uvOffset = uvStart + i * uvStride;
		#ifdef HORIZONTAL_PASS
			vec2 distribution = unpackRGBATo2Half( texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( uvOffset, 0.0 ) * radius ) / resolution ) );
			mean += distribution.x;
			squared_mean += distribution.y * distribution.y + distribution.x * distribution.x;
		#else
			float depth = unpackRGBAToDepth( texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( 0.0, uvOffset ) * radius ) / resolution ) );
			mean += depth;
			squared_mean += depth * depth;
		#endif
	}
	mean = mean / samples;
	squared_mean = squared_mean / samples;
	float std_dev = sqrt( squared_mean - mean * mean );
	gl_FragColor = pack2HalfToRGBA( vec2( mean, std_dev ) );
}`;function ex(r,e,t){let n=new tr,i=new et,s=new et,o=new St,a=new ua({depthPacking:hf}),l=new fa,h={},f=t.maxTextureSize,c={[Si]:on,[on]:Si,[bn]:bn},u=new Kn({defines:{VSM_SAMPLES:8},uniforms:{shadow_pass:{value:null},resolution:{value:new et},radius:{value:4}},vertexShader:jv,fragmentShader:Qv}),d=u.clone();d.defines.HORIZONTAL_PASS=1;let p=new Lt;p.setAttribute("position",new Mn(new Float32Array([-1,-1,.5,3,-1,.5,-1,3,.5]),3));let v=new fn(p,u),g=this;this.enabled=!1,this.autoUpdate=!0,this.needsUpdate=!1,this.type=Vc;let m=this.type;this.render=function(M,E,A){if(g.enabled===!1||g.autoUpdate===!1&&g.needsUpdate===!1||M.length===0)return;let b=r.getRenderTarget(),w=r.getActiveCubeFace(),T=r.getActiveMipmapLevel(),F=r.state;F.setBlending(Ai),F.buffers.depth.getReversed()===!0?F.buffers.color.setClear(0,0,0,0):F.buffers.color.setClear(1,1,1,1),F.buffers.depth.setTest(!0),F.setScissorTest(!1);let D=m!==li&&this.type===li,C=m===li&&this.type!==li;for(let P=0,N=M.length;P<N;P++){let z=M[P],O=z.shadow;if(O===void 0){console.warn("THREE.WebGLShadowMap:",z,"has no shadow.");continue}if(O.autoUpdate===!1&&O.needsUpdate===!1)continue;i.copy(O.mapSize);let K=O.getFrameExtents();if(i.multiply(K),s.copy(O.mapSize),(i.x>f||i.y>f)&&(i.x>f&&(s.x=Math.floor(f/K.x),i.x=s.x*K.x,O.mapSize.x=s.x),i.y>f&&(s.y=Math.floor(f/K.y),i.y=s.y*K.y,O.mapSize.y=s.y)),O.map===null||D===!0||C===!0){let oe=this.type!==li?{minFilter:Fn,magFilter:Fn}:{};O.map!==null&&O.map.dispose(),O.map=new oi(i.x,i.y,oe),O.map.texture.name=z.name+".shadowMap",O.camera.updateProjectionMatrix()}r.setRenderTarget(O.map),r.clear();let ee=O.getViewportCount();for(let oe=0;oe<ee;oe++){let ae=O.getViewport(oe);o.set(s.x*ae.x,s.y*ae.y,s.x*ae.z,s.y*ae.w),F.viewport(o),O.updateMatrices(z,oe),n=O.getFrustum(),y(E,A,O.camera,z,this.type)}O.isPointLightShadow!==!0&&this.type===li&&_(O,A),O.needsUpdate=!1}m=this.type,g.needsUpdate=!1,r.setRenderTarget(b,w,T)};function _(M,E){let A=e.update(v);u.defines.VSM_SAMPLES!==M.blurSamples&&(u.defines.VSM_SAMPLES=M.blurSamples,d.defines.VSM_SAMPLES=M.blurSamples,u.needsUpdate=!0,d.needsUpdate=!0),M.mapPass===null&&(M.mapPass=new oi(i.x,i.y)),u.uniforms.shadow_pass.value=M.map.texture,u.uniforms.resolution.value=M.mapSize,u.uniforms.radius.value=M.radius,r.setRenderTarget(M.mapPass),r.clear(),r.renderBufferDirect(E,null,A,u,v,null),d.uniforms.shadow_pass.value=M.mapPass.texture,d.uniforms.resolution.value=M.mapSize,d.uniforms.radius.value=M.radius,r.setRenderTarget(M.map),r.clear(),r.renderBufferDirect(E,null,A,d,v,null)}function x(M,E,A,b){let w=null,T=A.isPointLight===!0?M.customDistanceMaterial:M.customDepthMaterial;if(T!==void 0)w=T;else if(w=A.isPointLight===!0?l:a,r.localClippingEnabled&&E.clipShadows===!0&&Array.isArray(E.clippingPlanes)&&E.clippingPlanes.length!==0||E.displacementMap&&E.displacementScale!==0||E.alphaMap&&E.alphaTest>0||E.map&&E.alphaTest>0||E.alphaToCoverage===!0){let F=w.uuid,D=E.uuid,C=h[F];C===void 0&&(C={},h[F]=C);let P=C[D];P===void 0&&(P=w.clone(),C[D]=P,E.addEventListener("dispose",S)),w=P}if(w.visible=E.visible,w.wireframe=E.wireframe,b===li?w.side=E.shadowSide!==null?E.shadowSide:E.side:w.side=E.shadowSide!==null?E.shadowSide:c[E.side],w.alphaMap=E.alphaMap,w.alphaTest=E.alphaToCoverage===!0?.5:E.alphaTest,w.map=E.map,w.clipShadows=E.clipShadows,w.clippingPlanes=E.clippingPlanes,w.clipIntersection=E.clipIntersection,w.displacementMap=E.displacementMap,w.displacementScale=E.displacementScale,w.displacementBias=E.displacementBias,w.wireframeLinewidth=E.wireframeLinewidth,w.linewidth=E.linewidth,A.isPointLight===!0&&w.isMeshDistanceMaterial===!0){let F=r.properties.get(w);F.light=A}return w}function y(M,E,A,b,w){if(M.visible===!1)return;if(M.layers.test(E.layers)&&(M.isMesh||M.isLine||M.isPoints)&&(M.castShadow||M.receiveShadow&&w===li)&&(!M.frustumCulled||n.intersectsObject(M))){M.modelViewMatrix.multiplyMatrices(A.matrixWorldInverse,M.matrixWorld);let D=e.update(M),C=M.material;if(Array.isArray(C)){let P=D.groups;for(let N=0,z=P.length;N<z;N++){let O=P[N],K=C[O.materialIndex];if(K&&K.visible){let ee=x(M,K,b,w);M.onBeforeShadow(r,M,E,A,D,ee,O),r.renderBufferDirect(A,null,D,ee,M,O),M.onAfterShadow(r,M,E,A,D,ee,O)}}}else if(C.visible){let P=x(M,C,b,w);M.onBeforeShadow(r,M,E,A,D,P,null),r.renderBufferDirect(A,null,D,P,M,null),M.onAfterShadow(r,M,E,A,D,P,null)}}let F=M.children;for(let D=0,C=F.length;D<C;D++)y(F[D],E,A,b,w)}function S(M){M.target.removeEventListener("dispose",S);for(let A in h){let b=h[A],w=M.target.uuid;w in b&&(b[w].dispose(),delete b[w])}}}var tx={[wa]:Ea,[Aa]:Ra,[Ta]:Pa,[ms]:Ca,[Ea]:wa,[Ra]:Aa,[Pa]:Ta,[Ca]:ms};function nx(r,e){function t(){let k=!1,ue=new St,de=null,Ae=new St(0,0,0,0);return{setMask:function(le){de!==le&&!k&&(r.colorMask(le,le,le,le),de=le)},setLocked:function(le){k=le},setClear:function(le,ie,Pe,Je,mt){mt===!0&&(le*=Je,ie*=Je,Pe*=Je),ue.set(le,ie,Pe,Je),Ae.equals(ue)===!1&&(r.clearColor(le,ie,Pe,Je),Ae.copy(ue))},reset:function(){k=!1,de=null,Ae.set(-1,0,0,0)}}}function n(){let k=!1,ue=!1,de=null,Ae=null,le=null;return{setReversed:function(ie){if(ue!==ie){let Pe=e.get("EXT_clip_control");ie?Pe.clipControlEXT(Pe.LOWER_LEFT_EXT,Pe.ZERO_TO_ONE_EXT):Pe.clipControlEXT(Pe.LOWER_LEFT_EXT,Pe.NEGATIVE_ONE_TO_ONE_EXT),ue=ie;let Je=le;le=null,this.setClear(Je)}},getReversed:function(){return ue},setTest:function(ie){ie?ne(r.DEPTH_TEST):ye(r.DEPTH_TEST)},setMask:function(ie){de!==ie&&!k&&(r.depthMask(ie),de=ie)},setFunc:function(ie){if(ue&&(ie=tx[ie]),Ae!==ie){switch(ie){case wa:r.depthFunc(r.NEVER);break;case Ea:r.depthFunc(r.ALWAYS);break;case Aa:r.depthFunc(r.LESS);break;case ms:r.depthFunc(r.LEQUAL);break;case Ta:r.depthFunc(r.EQUAL);break;case Ca:r.depthFunc(r.GEQUAL);break;case Ra:r.depthFunc(r.GREATER);break;case Pa:r.depthFunc(r.NOTEQUAL);break;default:r.depthFunc(r.LEQUAL)}Ae=ie}},setLocked:function(ie){k=ie},setClear:function(ie){le!==ie&&(ue&&(ie=1-ie),r.clearDepth(ie),le=ie)},reset:function(){k=!1,de=null,Ae=null,le=null,ue=!1}}}function i(){let k=!1,ue=null,de=null,Ae=null,le=null,ie=null,Pe=null,Je=null,mt=null;return{setTest:function(ct){k||(ct?ne(r.STENCIL_TEST):ye(r.STENCIL_TEST))},setMask:function(ct){ue!==ct&&!k&&(r.stencilMask(ct),ue=ct)},setFunc:function(ct,Y,Wt){(de!==ct||Ae!==Y||le!==Wt)&&(r.stencilFunc(ct,Y,Wt),de=ct,Ae=Y,le=Wt)},setOp:function(ct,Y,Wt){(ie!==ct||Pe!==Y||Je!==Wt)&&(r.stencilOp(ct,Y,Wt),ie=ct,Pe=Y,Je=Wt)},setLocked:function(ct){k=ct},setClear:function(ct){mt!==ct&&(r.clearStencil(ct),mt=ct)},reset:function(){k=!1,ue=null,de=null,Ae=null,le=null,ie=null,Pe=null,Je=null,mt=null}}}let s=new t,o=new n,a=new i,l=new WeakMap,h=new WeakMap,f={},c={},u=new WeakMap,d=[],p=null,v=!1,g=null,m=null,_=null,x=null,y=null,S=null,M=null,E=new ot(0,0,0),A=0,b=!1,w=null,T=null,F=null,D=null,C=null,P=r.getParameter(r.MAX_COMBINED_TEXTURE_IMAGE_UNITS),N=!1,z=0,O=r.getParameter(r.VERSION);O.indexOf("WebGL")!==-1?(z=parseFloat(/^WebGL (\d)/.exec(O)[1]),N=z>=1):O.indexOf("OpenGL ES")!==-1&&(z=parseFloat(/^OpenGL ES (\d)/.exec(O)[1]),N=z>=2);let K=null,ee={},oe=r.getParameter(r.SCISSOR_BOX),ae=r.getParameter(r.VIEWPORT),Ge=new St().fromArray(oe),Ce=new St().fromArray(ae);function We(k,ue,de,Ae){let le=new Uint8Array(4),ie=r.createTexture();r.bindTexture(k,ie),r.texParameteri(k,r.TEXTURE_MIN_FILTER,r.NEAREST),r.texParameteri(k,r.TEXTURE_MAG_FILTER,r.NEAREST);for(let Pe=0;Pe<de;Pe++)k===r.TEXTURE_3D||k===r.TEXTURE_2D_ARRAY?r.texImage3D(ue,0,r.RGBA,1,1,Ae,0,r.RGBA,r.UNSIGNED_BYTE,le):r.texImage2D(ue+Pe,0,r.RGBA,1,1,0,r.RGBA,r.UNSIGNED_BYTE,le);return ie}let j={};j[r.TEXTURE_2D]=We(r.TEXTURE_2D,r.TEXTURE_2D,1),j[r.TEXTURE_CUBE_MAP]=We(r.TEXTURE_CUBE_MAP,r.TEXTURE_CUBE_MAP_POSITIVE_X,6),j[r.TEXTURE_2D_ARRAY]=We(r.TEXTURE_2D_ARRAY,r.TEXTURE_2D_ARRAY,1,1),j[r.TEXTURE_3D]=We(r.TEXTURE_3D,r.TEXTURE_3D,1,1),s.setClear(0,0,0,1),o.setClear(1),a.setClear(0),ne(r.DEPTH_TEST),o.setFunc(ms),ke(!1),be(kc),ne(r.CULL_FACE),ft(Ai);function ne(k){f[k]!==!0&&(r.enable(k),f[k]=!0)}function ye(k){f[k]!==!1&&(r.disable(k),f[k]=!1)}function De(k,ue){return c[k]!==ue?(r.bindFramebuffer(k,ue),c[k]=ue,k===r.DRAW_FRAMEBUFFER&&(c[r.FRAMEBUFFER]=ue),k===r.FRAMEBUFFER&&(c[r.DRAW_FRAMEBUFFER]=ue),!0):!1}function Se(k,ue){let de=d,Ae=!1;if(k){de=u.get(ue),de===void 0&&(de=[],u.set(ue,de));let le=k.textures;if(de.length!==le.length||de[0]!==r.COLOR_ATTACHMENT0){for(let ie=0,Pe=le.length;ie<Pe;ie++)de[ie]=r.COLOR_ATTACHMENT0+ie;de.length=le.length,Ae=!0}}else de[0]!==r.BACK&&(de[0]=r.BACK,Ae=!0);Ae&&r.drawBuffers(de)}function st(k){return p!==k?(r.useProgram(k),p=k,!0):!1}let Ct={[Xi]:r.FUNC_ADD,[Bu]:r.FUNC_SUBTRACT,[Uu]:r.FUNC_REVERSE_SUBTRACT};Ct[Ou]=r.MIN,Ct[zu]=r.MAX;let U={[ku]:r.ZERO,[Vu]:r.ONE,[Hu]:r.SRC_COLOR,[Qo]:r.SRC_ALPHA,[Yu]:r.SRC_ALPHA_SATURATE,[Xu]:r.DST_COLOR,[Wu]:r.DST_ALPHA,[Gu]:r.ONE_MINUS_SRC_COLOR,[ea]:r.ONE_MINUS_SRC_ALPHA,[$u]:r.ONE_MINUS_DST_COLOR,[qu]:r.ONE_MINUS_DST_ALPHA,[Zu]:r.CONSTANT_COLOR,[Ku]:r.ONE_MINUS_CONSTANT_COLOR,[Ju]:r.CONSTANT_ALPHA,[ju]:r.ONE_MINUS_CONSTANT_ALPHA};function ft(k,ue,de,Ae,le,ie,Pe,Je,mt,ct){if(k===Ai){v===!0&&(ye(r.BLEND),v=!1);return}if(v===!1&&(ne(r.BLEND),v=!0),k!==Fu){if(k!==g||ct!==b){if((m!==Xi||y!==Xi)&&(r.blendEquation(r.FUNC_ADD),m=Xi,y=Xi),ct)switch(k){case ps:r.blendFuncSeparate(r.ONE,r.ONE_MINUS_SRC_ALPHA,r.ONE,r.ONE_MINUS_SRC_ALPHA);break;case Hc:r.blendFunc(r.ONE,r.ONE);break;case Gc:r.blendFuncSeparate(r.ZERO,r.ONE_MINUS_SRC_COLOR,r.ZERO,r.ONE);break;case Wc:r.blendFuncSeparate(r.DST_COLOR,r.ONE_MINUS_SRC_ALPHA,r.ZERO,r.ONE);break;default:console.error("THREE.WebGLState: Invalid blending: ",k);break}else switch(k){case ps:r.blendFuncSeparate(r.SRC_ALPHA,r.ONE_MINUS_SRC_ALPHA,r.ONE,r.ONE_MINUS_SRC_ALPHA);break;case Hc:r.blendFuncSeparate(r.SRC_ALPHA,r.ONE,r.ONE,r.ONE);break;case Gc:console.error("THREE.WebGLState: SubtractiveBlending requires material.premultipliedAlpha = true");break;case Wc:console.error("THREE.WebGLState: MultiplyBlending requires material.premultipliedAlpha = true");break;default:console.error("THREE.WebGLState: Invalid blending: ",k);break}_=null,x=null,S=null,M=null,E.set(0,0,0),A=0,g=k,b=ct}return}le=le||ue,ie=ie||de,Pe=Pe||Ae,(ue!==m||le!==y)&&(r.blendEquationSeparate(Ct[ue],Ct[le]),m=ue,y=le),(de!==_||Ae!==x||ie!==S||Pe!==M)&&(r.blendFuncSeparate(U[de],U[Ae],U[ie],U[Pe]),_=de,x=Ae,S=ie,M=Pe),(Je.equals(E)===!1||mt!==A)&&(r.blendColor(Je.r,Je.g,Je.b,mt),E.copy(Je),A=mt),g=k,b=!1}function $e(k,ue){k.side===bn?ye(r.CULL_FACE):ne(r.CULL_FACE);let de=k.side===on;ue&&(de=!de),ke(de),k.blending===ps&&k.transparent===!1?ft(Ai):ft(k.blending,k.blendEquation,k.blendSrc,k.blendDst,k.blendEquationAlpha,k.blendSrcAlpha,k.blendDstAlpha,k.blendColor,k.blendAlpha,k.premultipliedAlpha),o.setFunc(k.depthFunc),o.setTest(k.depthTest),o.setMask(k.depthWrite),s.setMask(k.colorWrite);let Ae=k.stencilWrite;a.setTest(Ae),Ae&&(a.setMask(k.stencilWriteMask),a.setFunc(k.stencilFunc,k.stencilRef,k.stencilFuncMask),a.setOp(k.stencilFail,k.stencilZFail,k.stencilZPass)),Ee(k.polygonOffset,k.polygonOffsetFactor,k.polygonOffsetUnits),k.alphaToCoverage===!0?ne(r.SAMPLE_ALPHA_TO_COVERAGE):ye(r.SAMPLE_ALPHA_TO_COVERAGE)}function ke(k){w!==k&&(k?r.frontFace(r.CW):r.frontFace(r.CCW),w=k)}function be(k){k!==Lu?(ne(r.CULL_FACE),k!==T&&(k===kc?r.cullFace(r.BACK):k===Du?r.cullFace(r.FRONT):r.cullFace(r.FRONT_AND_BACK))):ye(r.CULL_FACE),T=k}function ht(k){k!==F&&(N&&r.lineWidth(k),F=k)}function Ee(k,ue,de){k?(ne(r.POLYGON_OFFSET_FILL),(D!==ue||C!==de)&&(r.polygonOffset(ue,de),D=ue,C=de)):ye(r.POLYGON_OFFSET_FILL)}function Ke(k){k?ne(r.SCISSOR_TEST):ye(r.SCISSOR_TEST)}function yt(k){k===void 0&&(k=r.TEXTURE0+P-1),K!==k&&(r.activeTexture(k),K=k)}function gt(k,ue,de){de===void 0&&(K===null?de=r.TEXTURE0+P-1:de=K);let Ae=ee[de];Ae===void 0&&(Ae={type:void 0,texture:void 0},ee[de]=Ae),(Ae.type!==k||Ae.texture!==ue)&&(K!==de&&(r.activeTexture(de),K=de),r.bindTexture(k,ue||j[k]),Ae.type=k,Ae.texture=ue)}function B(){let k=ee[K];k!==void 0&&k.type!==void 0&&(r.bindTexture(k.type,null),k.type=void 0,k.texture=void 0)}function I(){try{r.compressedTexImage2D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function X(){try{r.compressedTexImage3D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function te(){try{r.texSubImage2D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function se(){try{r.texSubImage3D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function Q(){try{r.compressedTexSubImage2D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function Ue(){try{r.compressedTexSubImage3D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function fe(){try{r.texStorage2D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function Ne(){try{r.texStorage3D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function Fe(){try{r.texImage2D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function he(){try{r.texImage3D(...arguments)}catch(k){console.error("THREE.WebGLState:",k)}}function Me(k){Ge.equals(k)===!1&&(r.scissor(k.x,k.y,k.z,k.w),Ge.copy(k))}function He(k){Ce.equals(k)===!1&&(r.viewport(k.x,k.y,k.z,k.w),Ce.copy(k))}function Be(k,ue){let de=h.get(ue);de===void 0&&(de=new WeakMap,h.set(ue,de));let Ae=de.get(k);Ae===void 0&&(Ae=r.getUniformBlockIndex(ue,k.name),de.set(k,Ae))}function me(k,ue){let Ae=h.get(ue).get(k);l.get(ue)!==Ae&&(r.uniformBlockBinding(ue,Ae,k.__bindingPointIndex),l.set(ue,Ae))}function Qe(){r.disable(r.BLEND),r.disable(r.CULL_FACE),r.disable(r.DEPTH_TEST),r.disable(r.POLYGON_OFFSET_FILL),r.disable(r.SCISSOR_TEST),r.disable(r.STENCIL_TEST),r.disable(r.SAMPLE_ALPHA_TO_COVERAGE),r.blendEquation(r.FUNC_ADD),r.blendFunc(r.ONE,r.ZERO),r.blendFuncSeparate(r.ONE,r.ZERO,r.ONE,r.ZERO),r.blendColor(0,0,0,0),r.colorMask(!0,!0,!0,!0),r.clearColor(0,0,0,0),r.depthMask(!0),r.depthFunc(r.LESS),o.setReversed(!1),r.clearDepth(1),r.stencilMask(4294967295),r.stencilFunc(r.ALWAYS,0,4294967295),r.stencilOp(r.KEEP,r.KEEP,r.KEEP),r.clearStencil(0),r.cullFace(r.BACK),r.frontFace(r.CCW),r.polygonOffset(0,0),r.activeTexture(r.TEXTURE0),r.bindFramebuffer(r.FRAMEBUFFER,null),r.bindFramebuffer(r.DRAW_FRAMEBUFFER,null),r.bindFramebuffer(r.READ_FRAMEBUFFER,null),r.useProgram(null),r.lineWidth(1),r.scissor(0,0,r.canvas.width,r.canvas.height),r.viewport(0,0,r.canvas.width,r.canvas.height),f={},K=null,ee={},c={},u=new WeakMap,d=[],p=null,v=!1,g=null,m=null,_=null,x=null,y=null,S=null,M=null,E=new ot(0,0,0),A=0,b=!1,w=null,T=null,F=null,D=null,C=null,Ge.set(0,0,r.canvas.width,r.canvas.height),Ce.set(0,0,r.canvas.width,r.canvas.height),s.reset(),o.reset(),a.reset()}return{buffers:{color:s,depth:o,stencil:a},enable:ne,disable:ye,bindFramebuffer:De,drawBuffers:Se,useProgram:st,setBlending:ft,setMaterial:$e,setFlipSided:ke,setCullFace:be,setLineWidth:ht,setPolygonOffset:Ee,setScissorTest:Ke,activeTexture:yt,bindTexture:gt,unbindTexture:B,compressedTexImage2D:I,compressedTexImage3D:X,texImage2D:Fe,texImage3D:he,updateUBOMapping:Be,uniformBlockBinding:me,texStorage2D:fe,texStorage3D:Ne,texSubImage2D:te,texSubImage3D:se,compressedTexSubImage2D:Q,compressedTexSubImage3D:Ue,scissor:Me,viewport:He,reset:Qe}}function ix(r,e,t,n,i,s,o){let a=e.has("WEBGL_multisampled_render_to_texture")?e.get("WEBGL_multisampled_render_to_texture"):null,l=typeof navigator>"u"?!1:/OculusBrowser/g.test(navigator.userAgent),h=new et,f=new WeakMap,c,u=new WeakMap,d=!1;try{d=typeof OffscreenCanvas<"u"&&new OffscreenCanvas(1,1).getContext("2d")!==null}catch{}function p(B,I){return d?new OffscreenCanvas(B,I):Fr("canvas")}function v(B,I,X){let te=1,se=gt(B);if((se.width>X||se.height>X)&&(te=X/Math.max(se.width,se.height)),te<1)if(typeof HTMLImageElement<"u"&&B instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&B instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&B instanceof ImageBitmap||typeof VideoFrame<"u"&&B instanceof VideoFrame){let Q=Math.floor(te*se.width),Ue=Math.floor(te*se.height);c===void 0&&(c=p(Q,Ue));let fe=I?p(Q,Ue):c;return fe.width=Q,fe.height=Ue,fe.getContext("2d").drawImage(B,0,0,Q,Ue),console.warn("THREE.WebGLRenderer: Texture has been resized from ("+se.width+"x"+se.height+") to ("+Q+"x"+Ue+")."),fe}else return"data"in B&&console.warn("THREE.WebGLRenderer: Image in DataTexture is too big ("+se.width+"x"+se.height+")."),B;return B}function g(B){return B.generateMipmaps}function m(B){r.generateMipmap(B)}function _(B){return B.isWebGLCubeRenderTarget?r.TEXTURE_CUBE_MAP:B.isWebGL3DRenderTarget?r.TEXTURE_3D:B.isWebGLArrayRenderTarget||B.isCompressedArrayTexture?r.TEXTURE_2D_ARRAY:r.TEXTURE_2D}function x(B,I,X,te,se=!1){if(B!==null){if(r[B]!==void 0)return r[B];console.warn("THREE.WebGLRenderer: Attempt to use non-existing WebGL internal format '"+B+"'")}let Q=I;if(I===r.RED&&(X===r.FLOAT&&(Q=r.R32F),X===r.HALF_FLOAT&&(Q=r.R16F),X===r.UNSIGNED_BYTE&&(Q=r.R8)),I===r.RED_INTEGER&&(X===r.UNSIGNED_BYTE&&(Q=r.R8UI),X===r.UNSIGNED_SHORT&&(Q=r.R16UI),X===r.UNSIGNED_INT&&(Q=r.R32UI),X===r.BYTE&&(Q=r.R8I),X===r.SHORT&&(Q=r.R16I),X===r.INT&&(Q=r.R32I)),I===r.RG&&(X===r.FLOAT&&(Q=r.RG32F),X===r.HALF_FLOAT&&(Q=r.RG16F),X===r.UNSIGNED_BYTE&&(Q=r.RG8)),I===r.RG_INTEGER&&(X===r.UNSIGNED_BYTE&&(Q=r.RG8UI),X===r.UNSIGNED_SHORT&&(Q=r.RG16UI),X===r.UNSIGNED_INT&&(Q=r.RG32UI),X===r.BYTE&&(Q=r.RG8I),X===r.SHORT&&(Q=r.RG16I),X===r.INT&&(Q=r.RG32I)),I===r.RGB_INTEGER&&(X===r.UNSIGNED_BYTE&&(Q=r.RGB8UI),X===r.UNSIGNED_SHORT&&(Q=r.RGB16UI),X===r.UNSIGNED_INT&&(Q=r.RGB32UI),X===r.BYTE&&(Q=r.RGB8I),X===r.SHORT&&(Q=r.RGB16I),X===r.INT&&(Q=r.RGB32I)),I===r.RGBA_INTEGER&&(X===r.UNSIGNED_BYTE&&(Q=r.RGBA8UI),X===r.UNSIGNED_SHORT&&(Q=r.RGBA16UI),X===r.UNSIGNED_INT&&(Q=r.RGBA32UI),X===r.BYTE&&(Q=r.RGBA8I),X===r.SHORT&&(Q=r.RGBA16I),X===r.INT&&(Q=r.RGBA32I)),I===r.RGB&&(X===r.UNSIGNED_INT_5_9_9_9_REV&&(Q=r.RGB9_E5),X===r.UNSIGNED_INT_10F_11F_11F_REV&&(Q=r.R11F_G11F_B10F)),I===r.RGBA){let Ue=se?Lr:lt.getTransfer(te);X===r.FLOAT&&(Q=r.RGBA32F),X===r.HALF_FLOAT&&(Q=r.RGBA16F),X===r.UNSIGNED_BYTE&&(Q=Ue===dt?r.SRGB8_ALPHA8:r.RGBA8),X===r.UNSIGNED_SHORT_4_4_4_4&&(Q=r.RGBA4),X===r.UNSIGNED_SHORT_5_5_5_1&&(Q=r.RGB5_A1)}return(Q===r.R16F||Q===r.R32F||Q===r.RG16F||Q===r.RG32F||Q===r.RGBA16F||Q===r.RGBA32F)&&e.get("EXT_color_buffer_float"),Q}function y(B,I){let X;return B?I===null||I===Qi||I===lr?X=r.DEPTH24_STENCIL8:I===ci?X=r.DEPTH32F_STENCIL8:I===or&&(X=r.DEPTH24_STENCIL8,console.warn("DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.")):I===null||I===Qi||I===lr?X=r.DEPTH_COMPONENT24:I===ci?X=r.DEPTH_COMPONENT32F:I===or&&(X=r.DEPTH_COMPONENT16),X}function S(B,I){return g(B)===!0||B.isFramebufferTexture&&B.minFilter!==Fn&&B.minFilter!==Yn?Math.log2(Math.max(I.width,I.height))+1:B.mipmaps!==void 0&&B.mipmaps.length>0?B.mipmaps.length:B.isCompressedTexture&&Array.isArray(B.image)?I.mipmaps.length:1}function M(B){let I=B.target;I.removeEventListener("dispose",M),A(I),I.isVideoTexture&&f.delete(I)}function E(B){let I=B.target;I.removeEventListener("dispose",E),w(I)}function A(B){let I=n.get(B);if(I.__webglInit===void 0)return;let X=B.source,te=u.get(X);if(te){let se=te[I.__cacheKey];se.usedTimes--,se.usedTimes===0&&b(B),Object.keys(te).length===0&&u.delete(X)}n.remove(B)}function b(B){let I=n.get(B);r.deleteTexture(I.__webglTexture);let X=B.source,te=u.get(X);delete te[I.__cacheKey],o.memory.textures--}function w(B){let I=n.get(B);if(B.depthTexture&&(B.depthTexture.dispose(),n.remove(B.depthTexture)),B.isWebGLCubeRenderTarget)for(let te=0;te<6;te++){if(Array.isArray(I.__webglFramebuffer[te]))for(let se=0;se<I.__webglFramebuffer[te].length;se++)r.deleteFramebuffer(I.__webglFramebuffer[te][se]);else r.deleteFramebuffer(I.__webglFramebuffer[te]);I.__webglDepthbuffer&&r.deleteRenderbuffer(I.__webglDepthbuffer[te])}else{if(Array.isArray(I.__webglFramebuffer))for(let te=0;te<I.__webglFramebuffer.length;te++)r.deleteFramebuffer(I.__webglFramebuffer[te]);else r.deleteFramebuffer(I.__webglFramebuffer);if(I.__webglDepthbuffer&&r.deleteRenderbuffer(I.__webglDepthbuffer),I.__webglMultisampledFramebuffer&&r.deleteFramebuffer(I.__webglMultisampledFramebuffer),I.__webglColorRenderbuffer)for(let te=0;te<I.__webglColorRenderbuffer.length;te++)I.__webglColorRenderbuffer[te]&&r.deleteRenderbuffer(I.__webglColorRenderbuffer[te]);I.__webglDepthRenderbuffer&&r.deleteRenderbuffer(I.__webglDepthRenderbuffer)}let X=B.textures;for(let te=0,se=X.length;te<se;te++){let Q=n.get(X[te]);Q.__webglTexture&&(r.deleteTexture(Q.__webglTexture),o.memory.textures--),n.remove(X[te])}n.remove(B)}let T=0;function F(){T=0}function D(){let B=T;return B>=i.maxTextures&&console.warn("THREE.WebGLTextures: Trying to use "+B+" texture units while this GPU supports only "+i.maxTextures),T+=1,B}function C(B){let I=[];return I.push(B.wrapS),I.push(B.wrapT),I.push(B.wrapR||0),I.push(B.magFilter),I.push(B.minFilter),I.push(B.anisotropy),I.push(B.internalFormat),I.push(B.format),I.push(B.type),I.push(B.generateMipmaps),I.push(B.premultiplyAlpha),I.push(B.flipY),I.push(B.unpackAlignment),I.push(B.colorSpace),I.join()}function P(B,I){let X=n.get(B);if(B.isVideoTexture&&Ke(B),B.isRenderTargetTexture===!1&&B.isExternalTexture!==!0&&B.version>0&&X.__version!==B.version){let te=B.image;if(te===null)console.warn("THREE.WebGLRenderer: Texture marked for update but no image data found.");else if(te.complete===!1)console.warn("THREE.WebGLRenderer: Texture marked for update but image is incomplete");else{j(X,B,I);return}}else B.isExternalTexture&&(X.__webglTexture=B.sourceTexture?B.sourceTexture:null);t.bindTexture(r.TEXTURE_2D,X.__webglTexture,r.TEXTURE0+I)}function N(B,I){let X=n.get(B);if(B.isRenderTargetTexture===!1&&B.version>0&&X.__version!==B.version){j(X,B,I);return}t.bindTexture(r.TEXTURE_2D_ARRAY,X.__webglTexture,r.TEXTURE0+I)}function z(B,I){let X=n.get(B);if(B.isRenderTargetTexture===!1&&B.version>0&&X.__version!==B.version){j(X,B,I);return}t.bindTexture(r.TEXTURE_3D,X.__webglTexture,r.TEXTURE0+I)}function O(B,I){let X=n.get(B);if(B.version>0&&X.__version!==B.version){ne(X,B,I);return}t.bindTexture(r.TEXTURE_CUBE_MAP,X.__webglTexture,r.TEXTURE0+I)}let K={[Ys]:r.REPEAT,[qi]:r.CLAMP_TO_EDGE,[ta]:r.MIRRORED_REPEAT},ee={[Fn]:r.NEAREST,[lf]:r.NEAREST_MIPMAP_NEAREST,[io]:r.NEAREST_MIPMAP_LINEAR,[Yn]:r.LINEAR,[Da]:r.LINEAR_MIPMAP_NEAREST,[ji]:r.LINEAR_MIPMAP_LINEAR},oe={[ff]:r.NEVER,[xf]:r.ALWAYS,[df]:r.LESS,[nh]:r.LEQUAL,[pf]:r.EQUAL,[vf]:r.GEQUAL,[mf]:r.GREATER,[gf]:r.NOTEQUAL};function ae(B,I){if(I.type===ci&&e.has("OES_texture_float_linear")===!1&&(I.magFilter===Yn||I.magFilter===Da||I.magFilter===io||I.magFilter===ji||I.minFilter===Yn||I.minFilter===Da||I.minFilter===io||I.minFilter===ji)&&console.warn("THREE.WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device."),r.texParameteri(B,r.TEXTURE_WRAP_S,K[I.wrapS]),r.texParameteri(B,r.TEXTURE_WRAP_T,K[I.wrapT]),(B===r.TEXTURE_3D||B===r.TEXTURE_2D_ARRAY)&&r.texParameteri(B,r.TEXTURE_WRAP_R,K[I.wrapR]),r.texParameteri(B,r.TEXTURE_MAG_FILTER,ee[I.magFilter]),r.texParameteri(B,r.TEXTURE_MIN_FILTER,ee[I.minFilter]),I.compareFunction&&(r.texParameteri(B,r.TEXTURE_COMPARE_MODE,r.COMPARE_REF_TO_TEXTURE),r.texParameteri(B,r.TEXTURE_COMPARE_FUNC,oe[I.compareFunction])),e.has("EXT_texture_filter_anisotropic")===!0){if(I.magFilter===Fn||I.minFilter!==io&&I.minFilter!==ji||I.type===ci&&e.has("OES_texture_float_linear")===!1)return;if(I.anisotropy>1||n.get(I).__currentAnisotropy){let X=e.get("EXT_texture_filter_anisotropic");r.texParameterf(B,X.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(I.anisotropy,i.getMaxAnisotropy())),n.get(I).__currentAnisotropy=I.anisotropy}}}function Ge(B,I){let X=!1;B.__webglInit===void 0&&(B.__webglInit=!0,I.addEventListener("dispose",M));let te=I.source,se=u.get(te);se===void 0&&(se={},u.set(te,se));let Q=C(I);if(Q!==B.__cacheKey){se[Q]===void 0&&(se[Q]={texture:r.createTexture(),usedTimes:0},o.memory.textures++,X=!0),se[Q].usedTimes++;let Ue=se[B.__cacheKey];Ue!==void 0&&(se[B.__cacheKey].usedTimes--,Ue.usedTimes===0&&b(I)),B.__cacheKey=Q,B.__webglTexture=se[Q].texture}return X}function Ce(B,I,X){return Math.floor(Math.floor(B/X)/I)}function We(B,I,X,te){let Q=B.updateRanges;if(Q.length===0)t.texSubImage2D(r.TEXTURE_2D,0,0,0,I.width,I.height,X,te,I.data);else{Q.sort((he,Me)=>he.start-Me.start);let Ue=0;for(let he=1;he<Q.length;he++){let Me=Q[Ue],He=Q[he],Be=Me.start+Me.count,me=Ce(He.start,I.width,4),Qe=Ce(Me.start,I.width,4);He.start<=Be+1&&me===Qe&&Ce(He.start+He.count-1,I.width,4)===me?Me.count=Math.max(Me.count,He.start+He.count-Me.start):(++Ue,Q[Ue]=He)}Q.length=Ue+1;let fe=r.getParameter(r.UNPACK_ROW_LENGTH),Ne=r.getParameter(r.UNPACK_SKIP_PIXELS),Fe=r.getParameter(r.UNPACK_SKIP_ROWS);r.pixelStorei(r.UNPACK_ROW_LENGTH,I.width);for(let he=0,Me=Q.length;he<Me;he++){let He=Q[he],Be=Math.floor(He.start/4),me=Math.ceil(He.count/4),Qe=Be%I.width,k=Math.floor(Be/I.width),ue=me,de=1;r.pixelStorei(r.UNPACK_SKIP_PIXELS,Qe),r.pixelStorei(r.UNPACK_SKIP_ROWS,k),t.texSubImage2D(r.TEXTURE_2D,0,Qe,k,ue,de,X,te,I.data)}B.clearUpdateRanges(),r.pixelStorei(r.UNPACK_ROW_LENGTH,fe),r.pixelStorei(r.UNPACK_SKIP_PIXELS,Ne),r.pixelStorei(r.UNPACK_SKIP_ROWS,Fe)}}function j(B,I,X){let te=r.TEXTURE_2D;(I.isDataArrayTexture||I.isCompressedArrayTexture)&&(te=r.TEXTURE_2D_ARRAY),I.isData3DTexture&&(te=r.TEXTURE_3D);let se=Ge(B,I),Q=I.source;t.bindTexture(te,B.__webglTexture,r.TEXTURE0+X);let Ue=n.get(Q);if(Q.version!==Ue.__version||se===!0){t.activeTexture(r.TEXTURE0+X);let fe=lt.getPrimaries(lt.workingColorSpace),Ne=I.colorSpace===Ci?null:lt.getPrimaries(I.colorSpace),Fe=I.colorSpace===Ci||fe===Ne?r.NONE:r.BROWSER_DEFAULT_WEBGL;r.pixelStorei(r.UNPACK_FLIP_Y_WEBGL,I.flipY),r.pixelStorei(r.UNPACK_PREMULTIPLY_ALPHA_WEBGL,I.premultiplyAlpha),r.pixelStorei(r.UNPACK_ALIGNMENT,I.unpackAlignment),r.pixelStorei(r.UNPACK_COLORSPACE_CONVERSION_WEBGL,Fe);let he=v(I.image,!1,i.maxTextureSize);he=yt(I,he);let Me=s.convert(I.format,I.colorSpace),He=s.convert(I.type),Be=x(I.internalFormat,Me,He,I.colorSpace,I.isVideoTexture);ae(te,I);let me,Qe=I.mipmaps,k=I.isVideoTexture!==!0,ue=Ue.__version===void 0||se===!0,de=Q.dataReady,Ae=S(I,he);if(I.isDepthTexture)Be=y(I.format===cr,I.type),ue&&(k?t.texStorage2D(r.TEXTURE_2D,1,Be,he.width,he.height):t.texImage2D(r.TEXTURE_2D,0,Be,he.width,he.height,0,Me,He,null));else if(I.isDataTexture)if(Qe.length>0){k&&ue&&t.texStorage2D(r.TEXTURE_2D,Ae,Be,Qe[0].width,Qe[0].height);for(let le=0,ie=Qe.length;le<ie;le++)me=Qe[le],k?de&&t.texSubImage2D(r.TEXTURE_2D,le,0,0,me.width,me.height,Me,He,me.data):t.texImage2D(r.TEXTURE_2D,le,Be,me.width,me.height,0,Me,He,me.data);I.generateMipmaps=!1}else k?(ue&&t.texStorage2D(r.TEXTURE_2D,Ae,Be,he.width,he.height),de&&We(I,he,Me,He)):t.texImage2D(r.TEXTURE_2D,0,Be,he.width,he.height,0,Me,He,he.data);else if(I.isCompressedTexture)if(I.isCompressedArrayTexture){k&&ue&&t.texStorage3D(r.TEXTURE_2D_ARRAY,Ae,Be,Qe[0].width,Qe[0].height,he.depth);for(let le=0,ie=Qe.length;le<ie;le++)if(me=Qe[le],I.format!==Bn)if(Me!==null)if(k){if(de)if(I.layerUpdates.size>0){let Pe=lh(me.width,me.height,I.format,I.type);for(let Je of I.layerUpdates){let mt=me.data.subarray(Je*Pe/me.data.BYTES_PER_ELEMENT,(Je+1)*Pe/me.data.BYTES_PER_ELEMENT);t.compressedTexSubImage3D(r.TEXTURE_2D_ARRAY,le,0,0,Je,me.width,me.height,1,Me,mt)}I.clearLayerUpdates()}else t.compressedTexSubImage3D(r.TEXTURE_2D_ARRAY,le,0,0,0,me.width,me.height,he.depth,Me,me.data)}else t.compressedTexImage3D(r.TEXTURE_2D_ARRAY,le,Be,me.width,me.height,he.depth,0,me.data,0,0);else console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()");else k?de&&t.texSubImage3D(r.TEXTURE_2D_ARRAY,le,0,0,0,me.width,me.height,he.depth,Me,He,me.data):t.texImage3D(r.TEXTURE_2D_ARRAY,le,Be,me.width,me.height,he.depth,0,Me,He,me.data)}else{k&&ue&&t.texStorage2D(r.TEXTURE_2D,Ae,Be,Qe[0].width,Qe[0].height);for(let le=0,ie=Qe.length;le<ie;le++)me=Qe[le],I.format!==Bn?Me!==null?k?de&&t.compressedTexSubImage2D(r.TEXTURE_2D,le,0,0,me.width,me.height,Me,me.data):t.compressedTexImage2D(r.TEXTURE_2D,le,Be,me.width,me.height,0,me.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()"):k?de&&t.texSubImage2D(r.TEXTURE_2D,le,0,0,me.width,me.height,Me,He,me.data):t.texImage2D(r.TEXTURE_2D,le,Be,me.width,me.height,0,Me,He,me.data)}else if(I.isDataArrayTexture)if(k){if(ue&&t.texStorage3D(r.TEXTURE_2D_ARRAY,Ae,Be,he.width,he.height,he.depth),de)if(I.layerUpdates.size>0){let le=lh(he.width,he.height,I.format,I.type);for(let ie of I.layerUpdates){let Pe=he.data.subarray(ie*le/he.data.BYTES_PER_ELEMENT,(ie+1)*le/he.data.BYTES_PER_ELEMENT);t.texSubImage3D(r.TEXTURE_2D_ARRAY,0,0,0,ie,he.width,he.height,1,Me,He,Pe)}I.clearLayerUpdates()}else t.texSubImage3D(r.TEXTURE_2D_ARRAY,0,0,0,0,he.width,he.height,he.depth,Me,He,he.data)}else t.texImage3D(r.TEXTURE_2D_ARRAY,0,Be,he.width,he.height,he.depth,0,Me,He,he.data);else if(I.isData3DTexture)k?(ue&&t.texStorage3D(r.TEXTURE_3D,Ae,Be,he.width,he.height,he.depth),de&&t.texSubImage3D(r.TEXTURE_3D,0,0,0,0,he.width,he.height,he.depth,Me,He,he.data)):t.texImage3D(r.TEXTURE_3D,0,Be,he.width,he.height,he.depth,0,Me,He,he.data);else if(I.isFramebufferTexture){if(ue)if(k)t.texStorage2D(r.TEXTURE_2D,Ae,Be,he.width,he.height);else{let le=he.width,ie=he.height;for(let Pe=0;Pe<Ae;Pe++)t.texImage2D(r.TEXTURE_2D,Pe,Be,le,ie,0,Me,He,null),le>>=1,ie>>=1}}else if(Qe.length>0){if(k&&ue){let le=gt(Qe[0]);t.texStorage2D(r.TEXTURE_2D,Ae,Be,le.width,le.height)}for(let le=0,ie=Qe.length;le<ie;le++)me=Qe[le],k?de&&t.texSubImage2D(r.TEXTURE_2D,le,0,0,Me,He,me):t.texImage2D(r.TEXTURE_2D,le,Be,Me,He,me);I.generateMipmaps=!1}else if(k){if(ue){let le=gt(he);t.texStorage2D(r.TEXTURE_2D,Ae,Be,le.width,le.height)}de&&t.texSubImage2D(r.TEXTURE_2D,0,0,0,Me,He,he)}else t.texImage2D(r.TEXTURE_2D,0,Be,Me,He,he);g(I)&&m(te),Ue.__version=Q.version,I.onUpdate&&I.onUpdate(I)}B.__version=I.version}function ne(B,I,X){if(I.image.length!==6)return;let te=Ge(B,I),se=I.source;t.bindTexture(r.TEXTURE_CUBE_MAP,B.__webglTexture,r.TEXTURE0+X);let Q=n.get(se);if(se.version!==Q.__version||te===!0){t.activeTexture(r.TEXTURE0+X);let Ue=lt.getPrimaries(lt.workingColorSpace),fe=I.colorSpace===Ci?null:lt.getPrimaries(I.colorSpace),Ne=I.colorSpace===Ci||Ue===fe?r.NONE:r.BROWSER_DEFAULT_WEBGL;r.pixelStorei(r.UNPACK_FLIP_Y_WEBGL,I.flipY),r.pixelStorei(r.UNPACK_PREMULTIPLY_ALPHA_WEBGL,I.premultiplyAlpha),r.pixelStorei(r.UNPACK_ALIGNMENT,I.unpackAlignment),r.pixelStorei(r.UNPACK_COLORSPACE_CONVERSION_WEBGL,Ne);let Fe=I.isCompressedTexture||I.image[0].isCompressedTexture,he=I.image[0]&&I.image[0].isDataTexture,Me=[];for(let ie=0;ie<6;ie++)!Fe&&!he?Me[ie]=v(I.image[ie],!0,i.maxCubemapSize):Me[ie]=he?I.image[ie].image:I.image[ie],Me[ie]=yt(I,Me[ie]);let He=Me[0],Be=s.convert(I.format,I.colorSpace),me=s.convert(I.type),Qe=x(I.internalFormat,Be,me,I.colorSpace),k=I.isVideoTexture!==!0,ue=Q.__version===void 0||te===!0,de=se.dataReady,Ae=S(I,He);ae(r.TEXTURE_CUBE_MAP,I);let le;if(Fe){k&&ue&&t.texStorage2D(r.TEXTURE_CUBE_MAP,Ae,Qe,He.width,He.height);for(let ie=0;ie<6;ie++){le=Me[ie].mipmaps;for(let Pe=0;Pe<le.length;Pe++){let Je=le[Pe];I.format!==Bn?Be!==null?k?de&&t.compressedTexSubImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,Pe,0,0,Je.width,Je.height,Be,Je.data):t.compressedTexImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,Pe,Qe,Je.width,Je.height,0,Je.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()"):k?de&&t.texSubImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,Pe,0,0,Je.width,Je.height,Be,me,Je.data):t.texImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,Pe,Qe,Je.width,Je.height,0,Be,me,Je.data)}}}else{if(le=I.mipmaps,k&&ue){le.length>0&&Ae++;let ie=gt(Me[0]);t.texStorage2D(r.TEXTURE_CUBE_MAP,Ae,Qe,ie.width,ie.height)}for(let ie=0;ie<6;ie++)if(he){k?de&&t.texSubImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,0,0,0,Me[ie].width,Me[ie].height,Be,me,Me[ie].data):t.texImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,0,Qe,Me[ie].width,Me[ie].height,0,Be,me,Me[ie].data);for(let Pe=0;Pe<le.length;Pe++){let mt=le[Pe].image[ie].image;k?de&&t.texSubImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,Pe+1,0,0,mt.width,mt.height,Be,me,mt.data):t.texImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,Pe+1,Qe,mt.width,mt.height,0,Be,me,mt.data)}}else{k?de&&t.texSubImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,0,0,0,Be,me,Me[ie]):t.texImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,0,Qe,Be,me,Me[ie]);for(let Pe=0;Pe<le.length;Pe++){let Je=le[Pe];k?de&&t.texSubImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,Pe+1,0,0,Be,me,Je.image[ie]):t.texImage2D(r.TEXTURE_CUBE_MAP_POSITIVE_X+ie,Pe+1,Qe,Be,me,Je.image[ie])}}}g(I)&&m(r.TEXTURE_CUBE_MAP),Q.__version=se.version,I.onUpdate&&I.onUpdate(I)}B.__version=I.version}function ye(B,I,X,te,se,Q){let Ue=s.convert(X.format,X.colorSpace),fe=s.convert(X.type),Ne=x(X.internalFormat,Ue,fe,X.colorSpace),Fe=n.get(I),he=n.get(X);if(he.__renderTarget=I,!Fe.__hasExternalTextures){let Me=Math.max(1,I.width>>Q),He=Math.max(1,I.height>>Q);se===r.TEXTURE_3D||se===r.TEXTURE_2D_ARRAY?t.texImage3D(se,Q,Ne,Me,He,I.depth,0,Ue,fe,null):t.texImage2D(se,Q,Ne,Me,He,0,Ue,fe,null)}t.bindFramebuffer(r.FRAMEBUFFER,B),Ee(I)?a.framebufferTexture2DMultisampleEXT(r.FRAMEBUFFER,te,se,he.__webglTexture,0,ht(I)):(se===r.TEXTURE_2D||se>=r.TEXTURE_CUBE_MAP_POSITIVE_X&&se<=r.TEXTURE_CUBE_MAP_NEGATIVE_Z)&&r.framebufferTexture2D(r.FRAMEBUFFER,te,se,he.__webglTexture,Q),t.bindFramebuffer(r.FRAMEBUFFER,null)}function De(B,I,X){if(r.bindRenderbuffer(r.RENDERBUFFER,B),I.depthBuffer){let te=I.depthTexture,se=te&&te.isDepthTexture?te.type:null,Q=y(I.stencilBuffer,se),Ue=I.stencilBuffer?r.DEPTH_STENCIL_ATTACHMENT:r.DEPTH_ATTACHMENT,fe=ht(I);Ee(I)?a.renderbufferStorageMultisampleEXT(r.RENDERBUFFER,fe,Q,I.width,I.height):X?r.renderbufferStorageMultisample(r.RENDERBUFFER,fe,Q,I.width,I.height):r.renderbufferStorage(r.RENDERBUFFER,Q,I.width,I.height),r.framebufferRenderbuffer(r.FRAMEBUFFER,Ue,r.RENDERBUFFER,B)}else{let te=I.textures;for(let se=0;se<te.length;se++){let Q=te[se],Ue=s.convert(Q.format,Q.colorSpace),fe=s.convert(Q.type),Ne=x(Q.internalFormat,Ue,fe,Q.colorSpace),Fe=ht(I);X&&Ee(I)===!1?r.renderbufferStorageMultisample(r.RENDERBUFFER,Fe,Ne,I.width,I.height):Ee(I)?a.renderbufferStorageMultisampleEXT(r.RENDERBUFFER,Fe,Ne,I.width,I.height):r.renderbufferStorage(r.RENDERBUFFER,Ne,I.width,I.height)}}r.bindRenderbuffer(r.RENDERBUFFER,null)}function Se(B,I){if(I&&I.isWebGLCubeRenderTarget)throw new Error("Depth Texture with cube render targets is not supported");if(t.bindFramebuffer(r.FRAMEBUFFER,B),!(I.depthTexture&&I.depthTexture.isDepthTexture))throw new Error("renderTarget.depthTexture must be an instance of THREE.DepthTexture");let te=n.get(I.depthTexture);te.__renderTarget=I,(!te.__webglTexture||I.depthTexture.image.width!==I.width||I.depthTexture.image.height!==I.height)&&(I.depthTexture.image.width=I.width,I.depthTexture.image.height=I.height,I.depthTexture.needsUpdate=!0),P(I.depthTexture,0);let se=te.__webglTexture,Q=ht(I);if(I.depthTexture.format===Zs)Ee(I)?a.framebufferTexture2DMultisampleEXT(r.FRAMEBUFFER,r.DEPTH_ATTACHMENT,r.TEXTURE_2D,se,0,Q):r.framebufferTexture2D(r.FRAMEBUFFER,r.DEPTH_ATTACHMENT,r.TEXTURE_2D,se,0);else if(I.depthTexture.format===cr)Ee(I)?a.framebufferTexture2DMultisampleEXT(r.FRAMEBUFFER,r.DEPTH_STENCIL_ATTACHMENT,r.TEXTURE_2D,se,0,Q):r.framebufferTexture2D(r.FRAMEBUFFER,r.DEPTH_STENCIL_ATTACHMENT,r.TEXTURE_2D,se,0);else throw new Error("Unknown depthTexture format")}function st(B){let I=n.get(B),X=B.isWebGLCubeRenderTarget===!0;if(I.__boundDepthTexture!==B.depthTexture){let te=B.depthTexture;if(I.__depthDisposeCallback&&I.__depthDisposeCallback(),te){let se=()=>{delete I.__boundDepthTexture,delete I.__depthDisposeCallback,te.removeEventListener("dispose",se)};te.addEventListener("dispose",se),I.__depthDisposeCallback=se}I.__boundDepthTexture=te}if(B.depthTexture&&!I.__autoAllocateDepthBuffer){if(X)throw new Error("target.depthTexture not supported in Cube render targets");let te=B.texture.mipmaps;te&&te.length>0?Se(I.__webglFramebuffer[0],B):Se(I.__webglFramebuffer,B)}else if(X){I.__webglDepthbuffer=[];for(let te=0;te<6;te++)if(t.bindFramebuffer(r.FRAMEBUFFER,I.__webglFramebuffer[te]),I.__webglDepthbuffer[te]===void 0)I.__webglDepthbuffer[te]=r.createRenderbuffer(),De(I.__webglDepthbuffer[te],B,!1);else{let se=B.stencilBuffer?r.DEPTH_STENCIL_ATTACHMENT:r.DEPTH_ATTACHMENT,Q=I.__webglDepthbuffer[te];r.bindRenderbuffer(r.RENDERBUFFER,Q),r.framebufferRenderbuffer(r.FRAMEBUFFER,se,r.RENDERBUFFER,Q)}}else{let te=B.texture.mipmaps;if(te&&te.length>0?t.bindFramebuffer(r.FRAMEBUFFER,I.__webglFramebuffer[0]):t.bindFramebuffer(r.FRAMEBUFFER,I.__webglFramebuffer),I.__webglDepthbuffer===void 0)I.__webglDepthbuffer=r.createRenderbuffer(),De(I.__webglDepthbuffer,B,!1);else{let se=B.stencilBuffer?r.DEPTH_STENCIL_ATTACHMENT:r.DEPTH_ATTACHMENT,Q=I.__webglDepthbuffer;r.bindRenderbuffer(r.RENDERBUFFER,Q),r.framebufferRenderbuffer(r.FRAMEBUFFER,se,r.RENDERBUFFER,Q)}}t.bindFramebuffer(r.FRAMEBUFFER,null)}function Ct(B,I,X){let te=n.get(B);I!==void 0&&ye(te.__webglFramebuffer,B,B.texture,r.COLOR_ATTACHMENT0,r.TEXTURE_2D,0),X!==void 0&&st(B)}function U(B){let I=B.texture,X=n.get(B),te=n.get(I);B.addEventListener("dispose",E);let se=B.textures,Q=B.isWebGLCubeRenderTarget===!0,Ue=se.length>1;if(Ue||(te.__webglTexture===void 0&&(te.__webglTexture=r.createTexture()),te.__version=I.version,o.memory.textures++),Q){X.__webglFramebuffer=[];for(let fe=0;fe<6;fe++)if(I.mipmaps&&I.mipmaps.length>0){X.__webglFramebuffer[fe]=[];for(let Ne=0;Ne<I.mipmaps.length;Ne++)X.__webglFramebuffer[fe][Ne]=r.createFramebuffer()}else X.__webglFramebuffer[fe]=r.createFramebuffer()}else{if(I.mipmaps&&I.mipmaps.length>0){X.__webglFramebuffer=[];for(let fe=0;fe<I.mipmaps.length;fe++)X.__webglFramebuffer[fe]=r.createFramebuffer()}else X.__webglFramebuffer=r.createFramebuffer();if(Ue)for(let fe=0,Ne=se.length;fe<Ne;fe++){let Fe=n.get(se[fe]);Fe.__webglTexture===void 0&&(Fe.__webglTexture=r.createTexture(),o.memory.textures++)}if(B.samples>0&&Ee(B)===!1){X.__webglMultisampledFramebuffer=r.createFramebuffer(),X.__webglColorRenderbuffer=[],t.bindFramebuffer(r.FRAMEBUFFER,X.__webglMultisampledFramebuffer);for(let fe=0;fe<se.length;fe++){let Ne=se[fe];X.__webglColorRenderbuffer[fe]=r.createRenderbuffer(),r.bindRenderbuffer(r.RENDERBUFFER,X.__webglColorRenderbuffer[fe]);let Fe=s.convert(Ne.format,Ne.colorSpace),he=s.convert(Ne.type),Me=x(Ne.internalFormat,Fe,he,Ne.colorSpace,B.isXRRenderTarget===!0),He=ht(B);r.renderbufferStorageMultisample(r.RENDERBUFFER,He,Me,B.width,B.height),r.framebufferRenderbuffer(r.FRAMEBUFFER,r.COLOR_ATTACHMENT0+fe,r.RENDERBUFFER,X.__webglColorRenderbuffer[fe])}r.bindRenderbuffer(r.RENDERBUFFER,null),B.depthBuffer&&(X.__webglDepthRenderbuffer=r.createRenderbuffer(),De(X.__webglDepthRenderbuffer,B,!0)),t.bindFramebuffer(r.FRAMEBUFFER,null)}}if(Q){t.bindTexture(r.TEXTURE_CUBE_MAP,te.__webglTexture),ae(r.TEXTURE_CUBE_MAP,I);for(let fe=0;fe<6;fe++)if(I.mipmaps&&I.mipmaps.length>0)for(let Ne=0;Ne<I.mipmaps.length;Ne++)ye(X.__webglFramebuffer[fe][Ne],B,I,r.COLOR_ATTACHMENT0,r.TEXTURE_CUBE_MAP_POSITIVE_X+fe,Ne);else ye(X.__webglFramebuffer[fe],B,I,r.COLOR_ATTACHMENT0,r.TEXTURE_CUBE_MAP_POSITIVE_X+fe,0);g(I)&&m(r.TEXTURE_CUBE_MAP),t.unbindTexture()}else if(Ue){for(let fe=0,Ne=se.length;fe<Ne;fe++){let Fe=se[fe],he=n.get(Fe),Me=r.TEXTURE_2D;(B.isWebGL3DRenderTarget||B.isWebGLArrayRenderTarget)&&(Me=B.isWebGL3DRenderTarget?r.TEXTURE_3D:r.TEXTURE_2D_ARRAY),t.bindTexture(Me,he.__webglTexture),ae(Me,Fe),ye(X.__webglFramebuffer,B,Fe,r.COLOR_ATTACHMENT0+fe,Me,0),g(Fe)&&m(Me)}t.unbindTexture()}else{let fe=r.TEXTURE_2D;if((B.isWebGL3DRenderTarget||B.isWebGLArrayRenderTarget)&&(fe=B.isWebGL3DRenderTarget?r.TEXTURE_3D:r.TEXTURE_2D_ARRAY),t.bindTexture(fe,te.__webglTexture),ae(fe,I),I.mipmaps&&I.mipmaps.length>0)for(let Ne=0;Ne<I.mipmaps.length;Ne++)ye(X.__webglFramebuffer[Ne],B,I,r.COLOR_ATTACHMENT0,fe,Ne);else ye(X.__webglFramebuffer,B,I,r.COLOR_ATTACHMENT0,fe,0);g(I)&&m(fe),t.unbindTexture()}B.depthBuffer&&st(B)}function ft(B){let I=B.textures;for(let X=0,te=I.length;X<te;X++){let se=I[X];if(g(se)){let Q=_(B),Ue=n.get(se).__webglTexture;t.bindTexture(Q,Ue),m(Q),t.unbindTexture()}}}let $e=[],ke=[];function be(B){if(B.samples>0){if(Ee(B)===!1){let I=B.textures,X=B.width,te=B.height,se=r.COLOR_BUFFER_BIT,Q=B.stencilBuffer?r.DEPTH_STENCIL_ATTACHMENT:r.DEPTH_ATTACHMENT,Ue=n.get(B),fe=I.length>1;if(fe)for(let Fe=0;Fe<I.length;Fe++)t.bindFramebuffer(r.FRAMEBUFFER,Ue.__webglMultisampledFramebuffer),r.framebufferRenderbuffer(r.FRAMEBUFFER,r.COLOR_ATTACHMENT0+Fe,r.RENDERBUFFER,null),t.bindFramebuffer(r.FRAMEBUFFER,Ue.__webglFramebuffer),r.framebufferTexture2D(r.DRAW_FRAMEBUFFER,r.COLOR_ATTACHMENT0+Fe,r.TEXTURE_2D,null,0);t.bindFramebuffer(r.READ_FRAMEBUFFER,Ue.__webglMultisampledFramebuffer);let Ne=B.texture.mipmaps;Ne&&Ne.length>0?t.bindFramebuffer(r.DRAW_FRAMEBUFFER,Ue.__webglFramebuffer[0]):t.bindFramebuffer(r.DRAW_FRAMEBUFFER,Ue.__webglFramebuffer);for(let Fe=0;Fe<I.length;Fe++){if(B.resolveDepthBuffer&&(B.depthBuffer&&(se|=r.DEPTH_BUFFER_BIT),B.stencilBuffer&&B.resolveStencilBuffer&&(se|=r.STENCIL_BUFFER_BIT)),fe){r.framebufferRenderbuffer(r.READ_FRAMEBUFFER,r.COLOR_ATTACHMENT0,r.RENDERBUFFER,Ue.__webglColorRenderbuffer[Fe]);let he=n.get(I[Fe]).__webglTexture;r.framebufferTexture2D(r.DRAW_FRAMEBUFFER,r.COLOR_ATTACHMENT0,r.TEXTURE_2D,he,0)}r.blitFramebuffer(0,0,X,te,0,0,X,te,se,r.NEAREST),l===!0&&($e.length=0,ke.length=0,$e.push(r.COLOR_ATTACHMENT0+Fe),B.depthBuffer&&B.resolveDepthBuffer===!1&&($e.push(Q),ke.push(Q),r.invalidateFramebuffer(r.DRAW_FRAMEBUFFER,ke)),r.invalidateFramebuffer(r.READ_FRAMEBUFFER,$e))}if(t.bindFramebuffer(r.READ_FRAMEBUFFER,null),t.bindFramebuffer(r.DRAW_FRAMEBUFFER,null),fe)for(let Fe=0;Fe<I.length;Fe++){t.bindFramebuffer(r.FRAMEBUFFER,Ue.__webglMultisampledFramebuffer),r.framebufferRenderbuffer(r.FRAMEBUFFER,r.COLOR_ATTACHMENT0+Fe,r.RENDERBUFFER,Ue.__webglColorRenderbuffer[Fe]);let he=n.get(I[Fe]).__webglTexture;t.bindFramebuffer(r.FRAMEBUFFER,Ue.__webglFramebuffer),r.framebufferTexture2D(r.DRAW_FRAMEBUFFER,r.COLOR_ATTACHMENT0+Fe,r.TEXTURE_2D,he,0)}t.bindFramebuffer(r.DRAW_FRAMEBUFFER,Ue.__webglMultisampledFramebuffer)}else if(B.depthBuffer&&B.resolveDepthBuffer===!1&&l){let I=B.stencilBuffer?r.DEPTH_STENCIL_ATTACHMENT:r.DEPTH_ATTACHMENT;r.invalidateFramebuffer(r.DRAW_FRAMEBUFFER,[I])}}}function ht(B){return Math.min(i.maxSamples,B.samples)}function Ee(B){let I=n.get(B);return B.samples>0&&e.has("WEBGL_multisampled_render_to_texture")===!0&&I.__useRenderToTexture!==!1}function Ke(B){let I=o.render.frame;f.get(B)!==I&&(f.set(B,I),B.update())}function yt(B,I){let X=B.colorSpace,te=B.format,se=B.type;return B.isCompressedTexture===!0||B.isVideoTexture===!0||X!==gs&&X!==Ci&&(lt.getTransfer(X)===dt?(te!==Bn||se!==Jn)&&console.warn("THREE.WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType."):console.error("THREE.WebGLTextures: Unsupported texture color space:",X)),I}function gt(B){return typeof HTMLImageElement<"u"&&B instanceof HTMLImageElement?(h.width=B.naturalWidth||B.width,h.height=B.naturalHeight||B.height):typeof VideoFrame<"u"&&B instanceof VideoFrame?(h.width=B.displayWidth,h.height=B.displayHeight):(h.width=B.width,h.height=B.height),h}this.allocateTextureUnit=D,this.resetTextureUnits=F,this.setTexture2D=P,this.setTexture2DArray=N,this.setTexture3D=z,this.setTextureCube=O,this.rebindTextures=Ct,this.setupRenderTarget=U,this.updateRenderTargetMipmap=ft,this.updateMultisampleRenderTarget=be,this.setupDepthRenderbuffer=st,this.setupFrameBufferTexture=ye,this.useMultisampledRTT=Ee}function sx(r,e){function t(n,i=Ci){let s,o=lt.getTransfer(i);if(n===Jn)return r.UNSIGNED_BYTE;if(n===Ba)return r.UNSIGNED_SHORT_4_4_4_4;if(n===Ua)return r.UNSIGNED_SHORT_5_5_5_1;if(n===Zc)return r.UNSIGNED_INT_5_9_9_9_REV;if(n===Kc)return r.UNSIGNED_INT_10F_11F_11F_REV;if(n===$c)return r.BYTE;if(n===Yc)return r.SHORT;if(n===or)return r.UNSIGNED_SHORT;if(n===Fa)return r.INT;if(n===Qi)return r.UNSIGNED_INT;if(n===ci)return r.FLOAT;if(n===ar)return r.HALF_FLOAT;if(n===Jc)return r.ALPHA;if(n===jc)return r.RGB;if(n===Bn)return r.RGBA;if(n===Zs)return r.DEPTH_COMPONENT;if(n===cr)return r.DEPTH_STENCIL;if(n===Qc)return r.RED;if(n===Oa)return r.RED_INTEGER;if(n===eh)return r.RG;if(n===za)return r.RG_INTEGER;if(n===ka)return r.RGBA_INTEGER;if(n===so||n===ro||n===oo||n===ao)if(o===dt)if(s=e.get("WEBGL_compressed_texture_s3tc_srgb"),s!==null){if(n===so)return s.COMPRESSED_SRGB_S3TC_DXT1_EXT;if(n===ro)return s.COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;if(n===oo)return s.COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;if(n===ao)return s.COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT}else return null;else if(s=e.get("WEBGL_compressed_texture_s3tc"),s!==null){if(n===so)return s.COMPRESSED_RGB_S3TC_DXT1_EXT;if(n===ro)return s.COMPRESSED_RGBA_S3TC_DXT1_EXT;if(n===oo)return s.COMPRESSED_RGBA_S3TC_DXT3_EXT;if(n===ao)return s.COMPRESSED_RGBA_S3TC_DXT5_EXT}else return null;if(n===Va||n===Ha||n===Ga||n===Wa)if(s=e.get("WEBGL_compressed_texture_pvrtc"),s!==null){if(n===Va)return s.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;if(n===Ha)return s.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;if(n===Ga)return s.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;if(n===Wa)return s.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG}else return null;if(n===qa||n===Xa||n===$a)if(s=e.get("WEBGL_compressed_texture_etc"),s!==null){if(n===qa||n===Xa)return o===dt?s.COMPRESSED_SRGB8_ETC2:s.COMPRESSED_RGB8_ETC2;if(n===$a)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC:s.COMPRESSED_RGBA8_ETC2_EAC}else return null;if(n===Ya||n===Za||n===Ka||n===Ja||n===ja||n===Qa||n===el||n===tl||n===nl||n===il||n===sl||n===rl||n===ol||n===al)if(s=e.get("WEBGL_compressed_texture_astc"),s!==null){if(n===Ya)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR:s.COMPRESSED_RGBA_ASTC_4x4_KHR;if(n===Za)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR:s.COMPRESSED_RGBA_ASTC_5x4_KHR;if(n===Ka)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR:s.COMPRESSED_RGBA_ASTC_5x5_KHR;if(n===Ja)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR:s.COMPRESSED_RGBA_ASTC_6x5_KHR;if(n===ja)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR:s.COMPRESSED_RGBA_ASTC_6x6_KHR;if(n===Qa)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR:s.COMPRESSED_RGBA_ASTC_8x5_KHR;if(n===el)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR:s.COMPRESSED_RGBA_ASTC_8x6_KHR;if(n===tl)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR:s.COMPRESSED_RGBA_ASTC_8x8_KHR;if(n===nl)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR:s.COMPRESSED_RGBA_ASTC_10x5_KHR;if(n===il)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR:s.COMPRESSED_RGBA_ASTC_10x6_KHR;if(n===sl)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR:s.COMPRESSED_RGBA_ASTC_10x8_KHR;if(n===rl)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR:s.COMPRESSED_RGBA_ASTC_10x10_KHR;if(n===ol)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR:s.COMPRESSED_RGBA_ASTC_12x10_KHR;if(n===al)return o===dt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR:s.COMPRESSED_RGBA_ASTC_12x12_KHR}else return null;if(n===ll||n===cl||n===hl)if(s=e.get("EXT_texture_compression_bptc"),s!==null){if(n===ll)return o===dt?s.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT:s.COMPRESSED_RGBA_BPTC_UNORM_EXT;if(n===cl)return s.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT;if(n===hl)return s.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT}else return null;if(n===ul||n===fl||n===dl||n===pl)if(s=e.get("EXT_texture_compression_rgtc"),s!==null){if(n===ul)return s.COMPRESSED_RED_RGTC1_EXT;if(n===fl)return s.COMPRESSED_SIGNED_RED_RGTC1_EXT;if(n===dl)return s.COMPRESSED_RED_GREEN_RGTC2_EXT;if(n===pl)return s.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT}else return null;return n===lr?r.UNSIGNED_INT_24_8:r[n]!==void 0?r[n]:null}return{convert:t}}var rx=`
void main() {

	gl_Position = vec4( position, 1.0 );

}`,ox=`
uniform sampler2DArray depthColor;
uniform float depthWidth;
uniform float depthHeight;

void main() {

	vec2 coord = vec2( gl_FragCoord.x / depthWidth, gl_FragCoord.y / depthHeight );

	if ( coord.x >= 1.0 ) {

		gl_FragDepth = texture( depthColor, vec3( coord.x - 1.0, coord.y, 1 ) ).r;

	} else {

		gl_FragDepth = texture( depthColor, vec3( coord.x, coord.y, 0 ) ).r;

	}

}`,Mh=class{constructor(){this.texture=null,this.mesh=null,this.depthNear=0,this.depthFar=0}init(e,t){if(this.texture===null){let n=new Xr(e.texture);(e.depthNear!==t.depthNear||e.depthFar!==t.depthFar)&&(this.depthNear=e.depthNear,this.depthFar=e.depthFar),this.texture=n}}getMesh(e){if(this.texture!==null&&this.mesh===null){let t=e.cameras[0].viewport,n=new Kn({vertexShader:rx,fragmentShader:ox,uniforms:{depthColor:{value:this.texture},depthWidth:{value:t.z},depthHeight:{value:t.w}}});this.mesh=new fn(new ys(20,20),n)}return this.mesh}reset(){this.texture=null,this.mesh=null}getDepthTexture(){return this.texture}},Sh=class extends bi{constructor(e,t){super();let n=this,i=null,s=1,o=null,a="local-floor",l=1,h=null,f=null,c=null,u=null,d=null,p=null,v=typeof XRWebGLBinding<"u",g=new Mh,m={},_=t.getContextAttributes(),x=null,y=null,S=[],M=[],E=new et,A=null,b=new Qt;b.viewport=new St;let w=new Qt;w.viewport=new St;let T=[b,w],F=new Sa,D=null,C=null;this.cameraAutoUpdate=!0,this.enabled=!1,this.isPresenting=!1,this.getController=function(j){let ne=S[j];return ne===void 0&&(ne=new er,S[j]=ne),ne.getTargetRaySpace()},this.getControllerGrip=function(j){let ne=S[j];return ne===void 0&&(ne=new er,S[j]=ne),ne.getGripSpace()},this.getHand=function(j){let ne=S[j];return ne===void 0&&(ne=new er,S[j]=ne),ne.getHandSpace()};function P(j){let ne=M.indexOf(j.inputSource);if(ne===-1)return;let ye=S[ne];ye!==void 0&&(ye.update(j.inputSource,j.frame,h||o),ye.dispatchEvent({type:j.type,data:j.inputSource}))}function N(){i.removeEventListener("select",P),i.removeEventListener("selectstart",P),i.removeEventListener("selectend",P),i.removeEventListener("squeeze",P),i.removeEventListener("squeezestart",P),i.removeEventListener("squeezeend",P),i.removeEventListener("end",N),i.removeEventListener("inputsourceschange",z);for(let j=0;j<S.length;j++){let ne=M[j];ne!==null&&(M[j]=null,S[j].disconnect(ne))}D=null,C=null,g.reset();for(let j in m)delete m[j];e.setRenderTarget(x),d=null,u=null,c=null,i=null,y=null,We.stop(),n.isPresenting=!1,e.setPixelRatio(A),e.setSize(E.width,E.height,!1),n.dispatchEvent({type:"sessionend"})}this.setFramebufferScaleFactor=function(j){s=j,n.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change framebuffer scale while presenting.")},this.setReferenceSpaceType=function(j){a=j,n.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change reference space type while presenting.")},this.getReferenceSpace=function(){return h||o},this.setReferenceSpace=function(j){h=j},this.getBaseLayer=function(){return u!==null?u:d},this.getBinding=function(){return c===null&&v&&(c=new XRWebGLBinding(i,t)),c},this.getFrame=function(){return p},this.getSession=function(){return i},this.setSession=async function(j){if(i=j,i!==null){if(x=e.getRenderTarget(),i.addEventListener("select",P),i.addEventListener("selectstart",P),i.addEventListener("selectend",P),i.addEventListener("squeeze",P),i.addEventListener("squeezestart",P),i.addEventListener("squeezeend",P),i.addEventListener("end",N),i.addEventListener("inputsourceschange",z),_.xrCompatible!==!0&&await t.makeXRCompatible(),A=e.getPixelRatio(),e.getSize(E),v&&"createProjectionLayer"in XRWebGLBinding.prototype){let ye=null,De=null,Se=null;_.depth&&(Se=_.stencil?t.DEPTH24_STENCIL8:t.DEPTH_COMPONENT24,ye=_.stencil?cr:Zs,De=_.stencil?lr:Qi);let st={colorFormat:t.RGBA8,depthFormat:Se,scaleFactor:s};c=this.getBinding(),u=c.createProjectionLayer(st),i.updateRenderState({layers:[u]}),e.setPixelRatio(1),e.setSize(u.textureWidth,u.textureHeight,!1),y=new oi(u.textureWidth,u.textureHeight,{format:Bn,type:Jn,depthTexture:new qr(u.textureWidth,u.textureHeight,De,void 0,void 0,void 0,void 0,void 0,void 0,ye),stencilBuffer:_.stencil,colorSpace:e.outputColorSpace,samples:_.antialias?4:0,resolveDepthBuffer:u.ignoreDepthValues===!1,resolveStencilBuffer:u.ignoreDepthValues===!1})}else{let ye={antialias:_.antialias,alpha:!0,depth:_.depth,stencil:_.stencil,framebufferScaleFactor:s};d=new XRWebGLLayer(i,t,ye),i.updateRenderState({baseLayer:d}),e.setPixelRatio(1),e.setSize(d.framebufferWidth,d.framebufferHeight,!1),y=new oi(d.framebufferWidth,d.framebufferHeight,{format:Bn,type:Jn,colorSpace:e.outputColorSpace,stencilBuffer:_.stencil,resolveDepthBuffer:d.ignoreDepthValues===!1,resolveStencilBuffer:d.ignoreDepthValues===!1})}y.isXRRenderTarget=!0,this.setFoveation(l),h=null,o=await i.requestReferenceSpace(a),We.setContext(i),We.start(),n.isPresenting=!0,n.dispatchEvent({type:"sessionstart"})}},this.getEnvironmentBlendMode=function(){if(i!==null)return i.environmentBlendMode},this.getDepthTexture=function(){return g.getDepthTexture()};function z(j){for(let ne=0;ne<j.removed.length;ne++){let ye=j.removed[ne],De=M.indexOf(ye);De>=0&&(M[De]=null,S[De].disconnect(ye))}for(let ne=0;ne<j.added.length;ne++){let ye=j.added[ne],De=M.indexOf(ye);if(De===-1){for(let st=0;st<S.length;st++)if(st>=M.length){M.push(ye),De=st;break}else if(M[st]===null){M[st]=ye,De=st;break}if(De===-1)break}let Se=S[De];Se&&Se.connect(ye)}}let O=new G,K=new G;function ee(j,ne,ye){O.setFromMatrixPosition(ne.matrixWorld),K.setFromMatrixPosition(ye.matrixWorld);let De=O.distanceTo(K),Se=ne.projectionMatrix.elements,st=ye.projectionMatrix.elements,Ct=Se[14]/(Se[10]-1),U=Se[14]/(Se[10]+1),ft=(Se[9]+1)/Se[5],$e=(Se[9]-1)/Se[5],ke=(Se[8]-1)/Se[0],be=(st[8]+1)/st[0],ht=Ct*ke,Ee=Ct*be,Ke=De/(-ke+be),yt=Ke*-ke;if(ne.matrixWorld.decompose(j.position,j.quaternion,j.scale),j.translateX(yt),j.translateZ(Ke),j.matrixWorld.compose(j.position,j.quaternion,j.scale),j.matrixWorldInverse.copy(j.matrixWorld).invert(),Se[10]===-1)j.projectionMatrix.copy(ne.projectionMatrix),j.projectionMatrixInverse.copy(ne.projectionMatrixInverse);else{let gt=Ct+Ke,B=U+Ke,I=ht-yt,X=Ee+(De-yt),te=ft*U/B*gt,se=$e*U/B*gt;j.projectionMatrix.makePerspective(I,X,te,se,gt,B),j.projectionMatrixInverse.copy(j.projectionMatrix).invert()}}function oe(j,ne){ne===null?j.matrixWorld.copy(j.matrix):j.matrixWorld.multiplyMatrices(ne.matrixWorld,j.matrix),j.matrixWorldInverse.copy(j.matrixWorld).invert()}this.updateCamera=function(j){if(i===null)return;let ne=j.near,ye=j.far;g.texture!==null&&(g.depthNear>0&&(ne=g.depthNear),g.depthFar>0&&(ye=g.depthFar)),F.near=w.near=b.near=ne,F.far=w.far=b.far=ye,(D!==F.near||C!==F.far)&&(i.updateRenderState({depthNear:F.near,depthFar:F.far}),D=F.near,C=F.far),F.layers.mask=j.layers.mask|6,b.layers.mask=F.layers.mask&3,w.layers.mask=F.layers.mask&5;let De=j.parent,Se=F.cameras;oe(F,De);for(let st=0;st<Se.length;st++)oe(Se[st],De);Se.length===2?ee(F,b,w):F.projectionMatrix.copy(b.projectionMatrix),ae(j,F,De)};function ae(j,ne,ye){ye===null?j.matrix.copy(ne.matrixWorld):(j.matrix.copy(ye.matrixWorld),j.matrix.invert(),j.matrix.multiply(ne.matrixWorld)),j.matrix.decompose(j.position,j.quaternion,j.scale),j.updateMatrixWorld(!0),j.projectionMatrix.copy(ne.projectionMatrix),j.projectionMatrixInverse.copy(ne.projectionMatrixInverse),j.isPerspectiveCamera&&(j.fov=ia*2*Math.atan(1/j.projectionMatrix.elements[5]),j.zoom=1)}this.getCamera=function(){return F},this.getFoveation=function(){if(!(u===null&&d===null))return l},this.setFoveation=function(j){l=j,u!==null&&(u.fixedFoveation=j),d!==null&&d.fixedFoveation!==void 0&&(d.fixedFoveation=j)},this.hasDepthSensing=function(){return g.texture!==null},this.getDepthSensingMesh=function(){return g.getMesh(F)},this.getCameraTexture=function(j){return m[j]};let Ge=null;function Ce(j,ne){if(f=ne.getViewerPose(h||o),p=ne,f!==null){let ye=f.views;d!==null&&(e.setRenderTargetFramebuffer(y,d.framebuffer),e.setRenderTarget(y));let De=!1;ye.length!==F.cameras.length&&(F.cameras.length=0,De=!0);for(let U=0;U<ye.length;U++){let ft=ye[U],$e=null;if(d!==null)$e=d.getViewport(ft);else{let be=c.getViewSubImage(u,ft);$e=be.viewport,U===0&&(e.setRenderTargetTextures(y,be.colorTexture,be.depthStencilTexture),e.setRenderTarget(y))}let ke=T[U];ke===void 0&&(ke=new Qt,ke.layers.enable(U),ke.viewport=new St,T[U]=ke),ke.matrix.fromArray(ft.transform.matrix),ke.matrix.decompose(ke.position,ke.quaternion,ke.scale),ke.projectionMatrix.fromArray(ft.projectionMatrix),ke.projectionMatrixInverse.copy(ke.projectionMatrix).invert(),ke.viewport.set($e.x,$e.y,$e.width,$e.height),U===0&&(F.matrix.copy(ke.matrix),F.matrix.decompose(F.position,F.quaternion,F.scale)),De===!0&&F.cameras.push(ke)}let Se=i.enabledFeatures;if(Se&&Se.includes("depth-sensing")&&i.depthUsage=="gpu-optimized"&&v){c=n.getBinding();let U=c.getDepthInformation(ye[0]);U&&U.isValid&&U.texture&&g.init(U,i.renderState)}if(Se&&Se.includes("camera-access")&&v){e.state.unbindTexture(),c=n.getBinding();for(let U=0;U<ye.length;U++){let ft=ye[U].camera;if(ft){let $e=m[ft];$e||($e=new Xr,m[ft]=$e);let ke=c.getCameraImage(ft);$e.sourceTexture=ke}}}}for(let ye=0;ye<S.length;ye++){let De=M[ye],Se=S[ye];De!==null&&Se!==void 0&&Se.update(De,ne,h||o)}Ge&&Ge(j,ne),ne.detectedPlanes&&n.dispatchEvent({type:"planesdetected",data:ne}),p=null}let We=new $f;We.setAnimationLoop(Ce),this.setAnimationLoop=function(j){Ge=j},this.dispose=function(){}}},Es=new Zn,ax=new Mt;function lx(r,e){function t(g,m){g.matrixAutoUpdate===!0&&g.updateMatrix(),m.value.copy(g.matrix)}function n(g,m){m.color.getRGB(g.fogColor.value,rh(r)),m.isFog?(g.fogNear.value=m.near,g.fogFar.value=m.far):m.isFogExp2&&(g.fogDensity.value=m.density)}function i(g,m,_,x,y){m.isMeshBasicMaterial||m.isMeshLambertMaterial?s(g,m):m.isMeshToonMaterial?(s(g,m),c(g,m)):m.isMeshPhongMaterial?(s(g,m),f(g,m)):m.isMeshStandardMaterial?(s(g,m),u(g,m),m.isMeshPhysicalMaterial&&d(g,m,y)):m.isMeshMatcapMaterial?(s(g,m),p(g,m)):m.isMeshDepthMaterial?s(g,m):m.isMeshDistanceMaterial?(s(g,m),v(g,m)):m.isMeshNormalMaterial?s(g,m):m.isLineBasicMaterial?(o(g,m),m.isLineDashedMaterial&&a(g,m)):m.isPointsMaterial?l(g,m,_,x):m.isSpriteMaterial?h(g,m):m.isShadowMaterial?(g.color.value.copy(m.color),g.opacity.value=m.opacity):m.isShaderMaterial&&(m.uniformsNeedUpdate=!1)}function s(g,m){g.opacity.value=m.opacity,m.color&&g.diffuse.value.copy(m.color),m.emissive&&g.emissive.value.copy(m.emissive).multiplyScalar(m.emissiveIntensity),m.map&&(g.map.value=m.map,t(m.map,g.mapTransform)),m.alphaMap&&(g.alphaMap.value=m.alphaMap,t(m.alphaMap,g.alphaMapTransform)),m.bumpMap&&(g.bumpMap.value=m.bumpMap,t(m.bumpMap,g.bumpMapTransform),g.bumpScale.value=m.bumpScale,m.side===on&&(g.bumpScale.value*=-1)),m.normalMap&&(g.normalMap.value=m.normalMap,t(m.normalMap,g.normalMapTransform),g.normalScale.value.copy(m.normalScale),m.side===on&&g.normalScale.value.negate()),m.displacementMap&&(g.displacementMap.value=m.displacementMap,t(m.displacementMap,g.displacementMapTransform),g.displacementScale.value=m.displacementScale,g.displacementBias.value=m.displacementBias),m.emissiveMap&&(g.emissiveMap.value=m.emissiveMap,t(m.emissiveMap,g.emissiveMapTransform)),m.specularMap&&(g.specularMap.value=m.specularMap,t(m.specularMap,g.specularMapTransform)),m.alphaTest>0&&(g.alphaTest.value=m.alphaTest);let _=e.get(m),x=_.envMap,y=_.envMapRotation;x&&(g.envMap.value=x,Es.copy(y),Es.x*=-1,Es.y*=-1,Es.z*=-1,x.isCubeTexture&&x.isRenderTargetTexture===!1&&(Es.y*=-1,Es.z*=-1),g.envMapRotation.value.setFromMatrix4(ax.makeRotationFromEuler(Es)),g.flipEnvMap.value=x.isCubeTexture&&x.isRenderTargetTexture===!1?-1:1,g.reflectivity.value=m.reflectivity,g.ior.value=m.ior,g.refractionRatio.value=m.refractionRatio),m.lightMap&&(g.lightMap.value=m.lightMap,g.lightMapIntensity.value=m.lightMapIntensity,t(m.lightMap,g.lightMapTransform)),m.aoMap&&(g.aoMap.value=m.aoMap,g.aoMapIntensity.value=m.aoMapIntensity,t(m.aoMap,g.aoMapTransform))}function o(g,m){g.diffuse.value.copy(m.color),g.opacity.value=m.opacity,m.map&&(g.map.value=m.map,t(m.map,g.mapTransform))}function a(g,m){g.dashSize.value=m.dashSize,g.totalSize.value=m.dashSize+m.gapSize,g.scale.value=m.scale}function l(g,m,_,x){g.diffuse.value.copy(m.color),g.opacity.value=m.opacity,g.size.value=m.size*_,g.scale.value=x*.5,m.map&&(g.map.value=m.map,t(m.map,g.uvTransform)),m.alphaMap&&(g.alphaMap.value=m.alphaMap,t(m.alphaMap,g.alphaMapTransform)),m.alphaTest>0&&(g.alphaTest.value=m.alphaTest)}function h(g,m){g.diffuse.value.copy(m.color),g.opacity.value=m.opacity,g.rotation.value=m.rotation,m.map&&(g.map.value=m.map,t(m.map,g.mapTransform)),m.alphaMap&&(g.alphaMap.value=m.alphaMap,t(m.alphaMap,g.alphaMapTransform)),m.alphaTest>0&&(g.alphaTest.value=m.alphaTest)}function f(g,m){g.specular.value.copy(m.specular),g.shininess.value=Math.max(m.shininess,1e-4)}function c(g,m){m.gradientMap&&(g.gradientMap.value=m.gradientMap)}function u(g,m){g.metalness.value=m.metalness,m.metalnessMap&&(g.metalnessMap.value=m.metalnessMap,t(m.metalnessMap,g.metalnessMapTransform)),g.roughness.value=m.roughness,m.roughnessMap&&(g.roughnessMap.value=m.roughnessMap,t(m.roughnessMap,g.roughnessMapTransform)),m.envMap&&(g.envMapIntensity.value=m.envMapIntensity)}function d(g,m,_){g.ior.value=m.ior,m.sheen>0&&(g.sheenColor.value.copy(m.sheenColor).multiplyScalar(m.sheen),g.sheenRoughness.value=m.sheenRoughness,m.sheenColorMap&&(g.sheenColorMap.value=m.sheenColorMap,t(m.sheenColorMap,g.sheenColorMapTransform)),m.sheenRoughnessMap&&(g.sheenRoughnessMap.value=m.sheenRoughnessMap,t(m.sheenRoughnessMap,g.sheenRoughnessMapTransform))),m.clearcoat>0&&(g.clearcoat.value=m.clearcoat,g.clearcoatRoughness.value=m.clearcoatRoughness,m.clearcoatMap&&(g.clearcoatMap.value=m.clearcoatMap,t(m.clearcoatMap,g.clearcoatMapTransform)),m.clearcoatRoughnessMap&&(g.clearcoatRoughnessMap.value=m.clearcoatRoughnessMap,t(m.clearcoatRoughnessMap,g.clearcoatRoughnessMapTransform)),m.clearcoatNormalMap&&(g.clearcoatNormalMap.value=m.clearcoatNormalMap,t(m.clearcoatNormalMap,g.clearcoatNormalMapTransform),g.clearcoatNormalScale.value.copy(m.clearcoatNormalScale),m.side===on&&g.clearcoatNormalScale.value.negate())),m.dispersion>0&&(g.dispersion.value=m.dispersion),m.iridescence>0&&(g.iridescence.value=m.iridescence,g.iridescenceIOR.value=m.iridescenceIOR,g.iridescenceThicknessMinimum.value=m.iridescenceThicknessRange[0],g.iridescenceThicknessMaximum.value=m.iridescenceThicknessRange[1],m.iridescenceMap&&(g.iridescenceMap.value=m.iridescenceMap,t(m.iridescenceMap,g.iridescenceMapTransform)),m.iridescenceThicknessMap&&(g.iridescenceThicknessMap.value=m.iridescenceThicknessMap,t(m.iridescenceThicknessMap,g.iridescenceThicknessMapTransform))),m.transmission>0&&(g.transmission.value=m.transmission,g.transmissionSamplerMap.value=_.texture,g.transmissionSamplerSize.value.set(_.width,_.height),m.transmissionMap&&(g.transmissionMap.value=m.transmissionMap,t(m.transmissionMap,g.transmissionMapTransform)),g.thickness.value=m.thickness,m.thicknessMap&&(g.thicknessMap.value=m.thicknessMap,t(m.thicknessMap,g.thicknessMapTransform)),g.attenuationDistance.value=m.attenuationDistance,g.attenuationColor.value.copy(m.attenuationColor)),m.anisotropy>0&&(g.anisotropyVector.value.set(m.anisotropy*Math.cos(m.anisotropyRotation),m.anisotropy*Math.sin(m.anisotropyRotation)),m.anisotropyMap&&(g.anisotropyMap.value=m.anisotropyMap,t(m.anisotropyMap,g.anisotropyMapTransform))),g.specularIntensity.value=m.specularIntensity,g.specularColor.value.copy(m.specularColor),m.specularColorMap&&(g.specularColorMap.value=m.specularColorMap,t(m.specularColorMap,g.specularColorMapTransform)),m.specularIntensityMap&&(g.specularIntensityMap.value=m.specularIntensityMap,t(m.specularIntensityMap,g.specularIntensityMapTransform))}function p(g,m){m.matcap&&(g.matcap.value=m.matcap)}function v(g,m){let _=e.get(m).light;g.referencePosition.value.setFromMatrixPosition(_.matrixWorld),g.nearDistance.value=_.shadow.camera.near,g.farDistance.value=_.shadow.camera.far}return{refreshFogUniforms:n,refreshMaterialUniforms:i}}function cx(r,e,t,n){let i={},s={},o=[],a=r.getParameter(r.MAX_UNIFORM_BUFFER_BINDINGS);function l(_,x){let y=x.program;n.uniformBlockBinding(_,y)}function h(_,x){let y=i[_.id];y===void 0&&(p(_),y=f(_),i[_.id]=y,_.addEventListener("dispose",g));let S=x.program;n.updateUBOMapping(_,S);let M=e.render.frame;s[_.id]!==M&&(u(_),s[_.id]=M)}function f(_){let x=c();_.__bindingPointIndex=x;let y=r.createBuffer(),S=_.__size,M=_.usage;return r.bindBuffer(r.UNIFORM_BUFFER,y),r.bufferData(r.UNIFORM_BUFFER,S,M),r.bindBuffer(r.UNIFORM_BUFFER,null),r.bindBufferBase(r.UNIFORM_BUFFER,x,y),y}function c(){for(let _=0;_<a;_++)if(o.indexOf(_)===-1)return o.push(_),_;return console.error("THREE.WebGLRenderer: Maximum number of simultaneously usable uniforms groups reached."),0}function u(_){let x=i[_.id],y=_.uniforms,S=_.__cache;r.bindBuffer(r.UNIFORM_BUFFER,x);for(let M=0,E=y.length;M<E;M++){let A=Array.isArray(y[M])?y[M]:[y[M]];for(let b=0,w=A.length;b<w;b++){let T=A[b];if(d(T,M,b,S)===!0){let F=T.__offset,D=Array.isArray(T.value)?T.value:[T.value],C=0;for(let P=0;P<D.length;P++){let N=D[P],z=v(N);typeof N=="number"||typeof N=="boolean"?(T.__data[0]=N,r.bufferSubData(r.UNIFORM_BUFFER,F+C,T.__data)):N.isMatrix3?(T.__data[0]=N.elements[0],T.__data[1]=N.elements[1],T.__data[2]=N.elements[2],T.__data[3]=0,T.__data[4]=N.elements[3],T.__data[5]=N.elements[4],T.__data[6]=N.elements[5],T.__data[7]=0,T.__data[8]=N.elements[6],T.__data[9]=N.elements[7],T.__data[10]=N.elements[8],T.__data[11]=0):(N.toArray(T.__data,C),C+=z.storage/Float32Array.BYTES_PER_ELEMENT)}r.bufferSubData(r.UNIFORM_BUFFER,F,T.__data)}}}r.bindBuffer(r.UNIFORM_BUFFER,null)}function d(_,x,y,S){let M=_.value,E=x+"_"+y;if(S[E]===void 0)return typeof M=="number"||typeof M=="boolean"?S[E]=M:S[E]=M.clone(),!0;{let A=S[E];if(typeof M=="number"||typeof M=="boolean"){if(A!==M)return S[E]=M,!0}else if(A.equals(M)===!1)return A.copy(M),!0}return!1}function p(_){let x=_.uniforms,y=0,S=16;for(let E=0,A=x.length;E<A;E++){let b=Array.isArray(x[E])?x[E]:[x[E]];for(let w=0,T=b.length;w<T;w++){let F=b[w],D=Array.isArray(F.value)?F.value:[F.value];for(let C=0,P=D.length;C<P;C++){let N=D[C],z=v(N),O=y%S,K=O%z.boundary,ee=O+K;y+=K,ee!==0&&S-ee<z.storage&&(y+=S-ee),F.__data=new Float32Array(z.storage/Float32Array.BYTES_PER_ELEMENT),F.__offset=y,y+=z.storage}}}let M=y%S;return M>0&&(y+=S-M),_.__size=y,_.__cache={},this}function v(_){let x={boundary:0,storage:0};return typeof _=="number"||typeof _=="boolean"?(x.boundary=4,x.storage=4):_.isVector2?(x.boundary=8,x.storage=8):_.isVector3||_.isColor?(x.boundary=16,x.storage=12):_.isVector4?(x.boundary=16,x.storage=16):_.isMatrix3?(x.boundary=48,x.storage=48):_.isMatrix4?(x.boundary=64,x.storage=64):_.isTexture?console.warn("THREE.WebGLRenderer: Texture samplers can not be part of an uniforms group."):console.warn("THREE.WebGLRenderer: Unsupported uniform value type.",_),x}function g(_){let x=_.target;x.removeEventListener("dispose",g);let y=o.indexOf(x.__bindingPointIndex);o.splice(y,1),r.deleteBuffer(i[x.id]),delete i[x.id],delete s[x.id]}function m(){for(let _ in i)r.deleteBuffer(i[_]);o=[],i={},s={}}return{bind:l,update:h,dispose:m}}var yl=class{constructor(e={}){let{canvas:t=yf(),context:n=null,depth:i=!0,stencil:s=!1,alpha:o=!1,antialias:a=!1,premultipliedAlpha:l=!0,preserveDrawingBuffer:h=!1,powerPreference:f="default",failIfMajorPerformanceCaveat:c=!1,reversedDepthBuffer:u=!1}=e;this.isWebGLRenderer=!0;let d;if(n!==null){if(typeof WebGLRenderingContext<"u"&&n instanceof WebGLRenderingContext)throw new Error("THREE.WebGLRenderer: WebGL 1 is not supported since r163.");d=n.getContextAttributes().alpha}else d=o;let p=new Uint32Array(4),v=new Int32Array(4),g=null,m=null,_=[],x=[];this.domElement=t,this.debug={checkShaderErrors:!0,onShaderError:null},this.autoClear=!0,this.autoClearColor=!0,this.autoClearDepth=!0,this.autoClearStencil=!0,this.sortObjects=!0,this.clippingPlanes=[],this.localClippingEnabled=!1,this.toneMapping=Ti,this.toneMappingExposure=1,this.transmissionResolutionScale=1;let y=this,S=!1;this._outputColorSpace=jt;let M=0,E=0,A=null,b=-1,w=null,T=new St,F=new St,D=null,C=new ot(0),P=0,N=t.width,z=t.height,O=1,K=null,ee=null,oe=new St(0,0,N,z),ae=new St(0,0,N,z),Ge=!1,Ce=new tr,We=!1,j=!1,ne=new Mt,ye=new G,De=new St,Se={background:null,fog:null,environment:null,overrideMaterial:null,isScene:!0},st=!1;function Ct(){return A===null?O:1}let U=n;function ft(L,H){return t.getContext(L,H)}try{let L={alpha:!0,depth:i,stencil:s,antialias:a,premultipliedAlpha:l,preserveDrawingBuffer:h,powerPreference:f,failIfMajorPerformanceCaveat:c};if("setAttribute"in t&&t.setAttribute("data-engine",`three.js r${"180"}`),t.addEventListener("webglcontextlost",de,!1),t.addEventListener("webglcontextrestored",Ae,!1),t.addEventListener("webglcontextcreationerror",le,!1),U===null){let H="webgl2";if(U=ft(H,L),U===null)throw ft(H)?new Error("Error creating WebGL context with your selected attributes."):new Error("Error creating WebGL context.")}}catch(L){throw console.error("THREE.WebGLRenderer: "+L.message),L}let $e,ke,be,ht,Ee,Ke,yt,gt,B,I,X,te,se,Q,Ue,fe,Ne,Fe,he,Me,He,Be,me,Qe;function k(){$e=new T0(U),$e.init(),Be=new sx(U,$e),ke=new _0(U,$e,e,Be),be=new nx(U,$e),ke.reversedDepthBuffer&&u&&be.buffers.depth.setReversed(!0),ht=new P0(U),Ee=new Gv,Ke=new ix(U,$e,be,Ee,ke,Be,ht),yt=new S0(y),gt=new A0(y),B=new Bp(U),me=new x0(U,B),I=new C0(U,B,ht,me),X=new N0(U,I,B,ht),he=new I0(U,ke,Ke),fe=new M0(Ee),te=new Hv(y,yt,gt,$e,ke,me,fe),se=new lx(y,Ee),Q=new qv,Ue=new Jv($e),Fe=new v0(y,yt,gt,be,X,d,l),Ne=new ex(y,X,ke),Qe=new cx(U,ht,ke,be),Me=new y0(U,$e,ht),He=new R0(U,$e,ht),ht.programs=te.programs,y.capabilities=ke,y.extensions=$e,y.properties=Ee,y.renderLists=Q,y.shadowMap=Ne,y.state=be,y.info=ht}k();let ue=new Sh(y,U);this.xr=ue,this.getContext=function(){return U},this.getContextAttributes=function(){return U.getContextAttributes()},this.forceContextLoss=function(){let L=$e.get("WEBGL_lose_context");L&&L.loseContext()},this.forceContextRestore=function(){let L=$e.get("WEBGL_lose_context");L&&L.restoreContext()},this.getPixelRatio=function(){return O},this.setPixelRatio=function(L){L!==void 0&&(O=L,this.setSize(N,z,!1))},this.getSize=function(L){return L.set(N,z)},this.setSize=function(L,H,Z=!0){if(ue.isPresenting){console.warn("THREE.WebGLRenderer: Can't change size while VR device is presenting.");return}N=L,z=H,t.width=Math.floor(L*O),t.height=Math.floor(H*O),Z===!0&&(t.style.width=L+"px",t.style.height=H+"px"),this.setViewport(0,0,L,H)},this.getDrawingBufferSize=function(L){return L.set(N*O,z*O).floor()},this.setDrawingBufferSize=function(L,H,Z){N=L,z=H,O=Z,t.width=Math.floor(L*Z),t.height=Math.floor(H*Z),this.setViewport(0,0,L,H)},this.getCurrentViewport=function(L){return L.copy(T)},this.getViewport=function(L){return L.copy(oe)},this.setViewport=function(L,H,Z,J){L.isVector4?oe.set(L.x,L.y,L.z,L.w):oe.set(L,H,Z,J),be.viewport(T.copy(oe).multiplyScalar(O).round())},this.getScissor=function(L){return L.copy(ae)},this.setScissor=function(L,H,Z,J){L.isVector4?ae.set(L.x,L.y,L.z,L.w):ae.set(L,H,Z,J),be.scissor(F.copy(ae).multiplyScalar(O).round())},this.getScissorTest=function(){return Ge},this.setScissorTest=function(L){be.setScissorTest(Ge=L)},this.setOpaqueSort=function(L){K=L},this.setTransparentSort=function(L){ee=L},this.getClearColor=function(L){return L.copy(Fe.getClearColor())},this.setClearColor=function(){Fe.setClearColor(...arguments)},this.getClearAlpha=function(){return Fe.getClearAlpha()},this.setClearAlpha=function(){Fe.setClearAlpha(...arguments)},this.clear=function(L=!0,H=!0,Z=!0){let J=0;if(L){let W=!1;if(A!==null){let ce=A.texture.format;W=ce===ka||ce===za||ce===Oa}if(W){let ce=A.texture.type,_e=ce===Jn||ce===Qi||ce===or||ce===lr||ce===Ba||ce===Ua,Re=Fe.getClearColor(),we=Fe.getClearAlpha(),Ve=Re.r,qe=Re.g,ze=Re.b;_e?(p[0]=Ve,p[1]=qe,p[2]=ze,p[3]=we,U.clearBufferuiv(U.COLOR,0,p)):(v[0]=Ve,v[1]=qe,v[2]=ze,v[3]=we,U.clearBufferiv(U.COLOR,0,v))}else J|=U.COLOR_BUFFER_BIT}H&&(J|=U.DEPTH_BUFFER_BIT),Z&&(J|=U.STENCIL_BUFFER_BIT,this.state.buffers.stencil.setMask(4294967295)),U.clear(J)},this.clearColor=function(){this.clear(!0,!1,!1)},this.clearDepth=function(){this.clear(!1,!0,!1)},this.clearStencil=function(){this.clear(!1,!1,!0)},this.dispose=function(){t.removeEventListener("webglcontextlost",de,!1),t.removeEventListener("webglcontextrestored",Ae,!1),t.removeEventListener("webglcontextcreationerror",le,!1),Fe.dispose(),Q.dispose(),Ue.dispose(),Ee.dispose(),yt.dispose(),gt.dispose(),X.dispose(),me.dispose(),Qe.dispose(),te.dispose(),ue.dispose(),ue.removeEventListener("sessionstart",Wt),ue.removeEventListener("sessionend",ln),Pn.stop()};function de(L){L.preventDefault(),console.log("THREE.WebGLRenderer: Context Lost."),S=!0}function Ae(){console.log("THREE.WebGLRenderer: Context Restored."),S=!1;let L=ht.autoReset,H=Ne.enabled,Z=Ne.autoUpdate,J=Ne.needsUpdate,W=Ne.type;k(),ht.autoReset=L,Ne.enabled=H,Ne.autoUpdate=Z,Ne.needsUpdate=J,Ne.type=W}function le(L){console.error("THREE.WebGLRenderer: A WebGL context could not be created. Reason: ",L.statusMessage)}function ie(L){let H=L.target;H.removeEventListener("dispose",ie),Pe(H)}function Pe(L){Je(L),Ee.remove(L)}function Je(L){let H=Ee.get(L).programs;H!==void 0&&(H.forEach(function(Z){te.releaseProgram(Z)}),L.isShaderMaterial&&te.releaseShaderCache(L))}this.renderBufferDirect=function(L,H,Z,J,W,ce){H===null&&(H=Se);let _e=W.isMesh&&W.matrixWorld.determinant()<0,Re=Oe(L,H,Z,J,W);be.setMaterial(J,_e);let we=Z.index,Ve=1;if(J.wireframe===!0){if(we=I.getWireframeAttribute(Z),we===void 0)return;Ve=2}let qe=Z.drawRange,ze=Z.attributes.position,rt=qe.start*Ve,je=(qe.start+qe.count)*Ve;ce!==null&&(rt=Math.max(rt,ce.start*Ve),je=Math.min(je,(ce.start+ce.count)*Ve)),we!==null?(rt=Math.max(rt,0),je=Math.min(je,we.count)):ze!=null&&(rt=Math.max(rt,0),je=Math.min(je,ze.count));let V=je-rt;if(V<0||V===1/0)return;me.setup(W,J,Re,Z,we);let $,q=Me;if(we!==null&&($=B.get(we),q=He,q.setIndex($)),W.isMesh)J.wireframe===!0?(be.setLineWidth(J.wireframeLinewidth*Ct()),q.setMode(U.LINES)):q.setMode(U.TRIANGLES);else if(W.isLine){let re=J.linewidth;re===void 0&&(re=1),be.setLineWidth(re*Ct()),W.isLineSegments?q.setMode(U.LINES):W.isLineLoop?q.setMode(U.LINE_LOOP):q.setMode(U.LINE_STRIP)}else W.isPoints?q.setMode(U.POINTS):W.isSprite&&q.setMode(U.TRIANGLES);if(W.isBatchedMesh)if(W._multiDrawInstances!==null)Ks("THREE.WebGLRenderer: renderMultiDrawInstances has been deprecated and will be removed in r184. Append to renderMultiDraw arguments and use indirection."),q.renderMultiDrawInstances(W._multiDrawStarts,W._multiDrawCounts,W._multiDrawCount,W._multiDrawInstances);else if($e.get("WEBGL_multi_draw"))q.renderMultiDraw(W._multiDrawStarts,W._multiDrawCounts,W._multiDrawCount);else{let re=W._multiDrawStarts,ge=W._multiDrawCounts,Ie=W._multiDrawCount,At=we?B.get(we).bytesPerElement:1,Hn=Ee.get(J).currentProgram.getUniforms();for(let xn=0;xn<Ie;xn++)Hn.setValue(U,"_gl_DrawID",xn),q.render(re[xn]/At,ge[xn])}else if(W.isInstancedMesh)q.renderInstances(rt,V,W.count);else if(Z.isInstancedBufferGeometry){let re=Z._maxInstanceCount!==void 0?Z._maxInstanceCount:1/0,ge=Math.min(Z.instanceCount,re);q.renderInstances(rt,V,ge)}else q.render(rt,V)};function mt(L,H,Z){L.transparent===!0&&L.side===bn&&L.forceSinglePass===!1?(L.side=on,L.needsUpdate=!0,qt(L,H,Z),L.side=Si,L.needsUpdate=!0,qt(L,H,Z),L.side=bn):qt(L,H,Z)}this.compile=function(L,H,Z=null){Z===null&&(Z=L),m=Ue.get(Z),m.init(H),x.push(m),Z.traverseVisible(function(W){W.isLight&&W.layers.test(H.layers)&&(m.pushLight(W),W.castShadow&&m.pushShadow(W))}),L!==Z&&L.traverseVisible(function(W){W.isLight&&W.layers.test(H.layers)&&(m.pushLight(W),W.castShadow&&m.pushShadow(W))}),m.setupLights();let J=new Set;return L.traverse(function(W){if(!(W.isMesh||W.isPoints||W.isLine||W.isSprite))return;let ce=W.material;if(ce)if(Array.isArray(ce))for(let _e=0;_e<ce.length;_e++){let Re=ce[_e];mt(Re,Z,W),J.add(Re)}else mt(ce,Z,W),J.add(ce)}),m=x.pop(),J},this.compileAsync=function(L,H,Z=null){let J=this.compile(L,H,Z);return new Promise(W=>{function ce(){if(J.forEach(function(_e){Ee.get(_e).currentProgram.isReady()&&J.delete(_e)}),J.size===0){W(L);return}setTimeout(ce,10)}$e.get("KHR_parallel_shader_compile")!==null?ce():setTimeout(ce,10)})};let ct=null;function Y(L){ct&&ct(L)}function Wt(){Pn.stop()}function ln(){Pn.start()}let Pn=new $f;Pn.setAnimationLoop(Y),typeof self<"u"&&Pn.setContext(self),this.setAnimationLoop=function(L){ct=L,ue.setAnimationLoop(L),L===null?Pn.stop():Pn.start()},ue.addEventListener("sessionstart",Wt),ue.addEventListener("sessionend",ln),this.render=function(L,H){if(H!==void 0&&H.isCamera!==!0){console.error("THREE.WebGLRenderer.render: camera is not an instance of THREE.Camera.");return}if(S===!0)return;if(L.matrixWorldAutoUpdate===!0&&L.updateMatrixWorld(),H.parent===null&&H.matrixWorldAutoUpdate===!0&&H.updateMatrixWorld(),ue.enabled===!0&&ue.isPresenting===!0&&(ue.cameraAutoUpdate===!0&&ue.updateCamera(H),H=ue.getCamera()),L.isScene===!0&&L.onBeforeRender(y,L,H,A),m=Ue.get(L,x.length),m.init(H),x.push(m),ne.multiplyMatrices(H.projectionMatrix,H.matrixWorldInverse),Ce.setFromProjectionMatrix(ne,Xn,H.reversedDepth),j=this.localClippingEnabled,We=fe.init(this.clippingPlanes,j),g=Q.get(L,_.length),g.init(),_.push(g),ue.enabled===!0&&ue.isPresenting===!0){let ce=y.xr.getDepthSensingMesh();ce!==null&&pe(ce,H,-1/0,y.sortObjects)}pe(L,H,0,y.sortObjects),g.finish(),y.sortObjects===!0&&g.sort(K,ee),st=ue.enabled===!1||ue.isPresenting===!1||ue.hasDepthSensing()===!1,st&&Fe.addToRenderList(g,L),this.info.render.frame++,We===!0&&fe.beginShadows();let Z=m.state.shadowsArray;Ne.render(Z,L,H),We===!0&&fe.endShadows(),this.info.autoReset===!0&&this.info.reset();let J=g.opaque,W=g.transmissive;if(m.setupLights(),H.isArrayCamera){let ce=H.cameras;if(W.length>0)for(let _e=0,Re=ce.length;_e<Re;_e++){let we=ce[_e];Et(J,W,L,we)}st&&Fe.render(L);for(let _e=0,Re=ce.length;_e<Re;_e++){let we=ce[_e];Ui(g,L,we,we.viewport)}}else W.length>0&&Et(J,W,L,H),st&&Fe.render(L),Ui(g,L,H);A!==null&&E===0&&(Ke.updateMultisampleRenderTarget(A),Ke.updateRenderTargetMipmap(A)),L.isScene===!0&&L.onAfterRender(y,L,H),me.resetDefaultState(),b=-1,w=null,x.pop(),x.length>0?(m=x[x.length-1],We===!0&&fe.setGlobalState(y.clippingPlanes,m.state.camera)):m=null,_.pop(),_.length>0?g=_[_.length-1]:g=null};function pe(L,H,Z,J){if(L.visible===!1)return;if(L.layers.test(H.layers)){if(L.isGroup)Z=L.renderOrder;else if(L.isLOD)L.autoUpdate===!0&&L.update(H);else if(L.isLight)m.pushLight(L),L.castShadow&&m.pushShadow(L);else if(L.isSprite){if(!L.frustumCulled||Ce.intersectsSprite(L)){J&&De.setFromMatrixPosition(L.matrixWorld).applyMatrix4(ne);let _e=X.update(L),Re=L.material;Re.visible&&g.push(L,_e,Re,Z,De.z,null)}}else if((L.isMesh||L.isLine||L.isPoints)&&(!L.frustumCulled||Ce.intersectsObject(L))){let _e=X.update(L),Re=L.material;if(J&&(L.boundingSphere!==void 0?(L.boundingSphere===null&&L.computeBoundingSphere(),De.copy(L.boundingSphere.center)):(_e.boundingSphere===null&&_e.computeBoundingSphere(),De.copy(_e.boundingSphere.center)),De.applyMatrix4(L.matrixWorld).applyMatrix4(ne)),Array.isArray(Re)){let we=_e.groups;for(let Ve=0,qe=we.length;Ve<qe;Ve++){let ze=we[Ve],rt=Re[ze.materialIndex];rt&&rt.visible&&g.push(L,_e,rt,Z,De.z,ze)}}else Re.visible&&g.push(L,_e,Re,Z,De.z,null)}}let ce=L.children;for(let _e=0,Re=ce.length;_e<Re;_e++)pe(ce[_e],H,Z,J)}function Ui(L,H,Z,J){let W=L.opaque,ce=L.transmissive,_e=L.transparent;m.setupLightsView(Z),We===!0&&fe.setGlobalState(y.clippingPlanes,Z),J&&be.viewport(T.copy(J)),W.length>0&&sn(W,H,Z),ce.length>0&&sn(ce,H,Z),_e.length>0&&sn(_e,H,Z),be.buffers.depth.setTest(!0),be.buffers.depth.setMask(!0),be.buffers.color.setMask(!0),be.setPolygonOffset(!1)}function Et(L,H,Z,J){if((Z.isScene===!0?Z.overrideMaterial:null)!==null)return;m.state.transmissionRenderTarget[J.id]===void 0&&(m.state.transmissionRenderTarget[J.id]=new oi(1,1,{generateMipmaps:!0,type:$e.has("EXT_color_buffer_half_float")||$e.has("EXT_color_buffer_float")?ar:Jn,minFilter:ji,samples:4,stencilBuffer:s,resolveDepthBuffer:!1,resolveStencilBuffer:!1,colorSpace:lt.workingColorSpace}));let ce=m.state.transmissionRenderTarget[J.id],_e=J.viewport||T;ce.setSize(_e.z*y.transmissionResolutionScale,_e.w*y.transmissionResolutionScale);let Re=y.getRenderTarget(),we=y.getActiveCubeFace(),Ve=y.getActiveMipmapLevel();y.setRenderTarget(ce),y.getClearColor(C),P=y.getClearAlpha(),P<1&&y.setClearColor(16777215,.5),y.clear(),st&&Fe.render(Z);let qe=y.toneMapping;y.toneMapping=Ti;let ze=J.viewport;if(J.viewport!==void 0&&(J.viewport=void 0),m.setupLightsView(J),We===!0&&fe.setGlobalState(y.clippingPlanes,J),sn(L,Z,J),Ke.updateMultisampleRenderTarget(ce),Ke.updateRenderTargetMipmap(ce),$e.has("WEBGL_multisampled_render_to_texture")===!1){let rt=!1;for(let je=0,V=H.length;je<V;je++){let $=H[je],q=$.object,re=$.geometry,ge=$.material,Ie=$.group;if(ge.side===bn&&q.layers.test(J.layers)){let At=ge.side;ge.side=on,ge.needsUpdate=!0,Ro(q,Z,J,re,ge,Ie),ge.side=At,ge.needsUpdate=!0,rt=!0}}rt===!0&&(Ke.updateMultisampleRenderTarget(ce),Ke.updateRenderTargetMipmap(ce))}y.setRenderTarget(Re,we,Ve),y.setClearColor(C,P),ze!==void 0&&(J.viewport=ze),y.toneMapping=qe}function sn(L,H,Z){let J=H.isScene===!0?H.overrideMaterial:null;for(let W=0,ce=L.length;W<ce;W++){let _e=L[W],Re=_e.object,we=_e.geometry,Ve=_e.group,qe=_e.material;qe.allowOverride===!0&&J!==null&&(qe=J),Re.layers.test(Z.layers)&&Ro(Re,H,Z,we,qe,Ve)}}function Ro(L,H,Z,J,W,ce){L.onBeforeRender(y,H,Z,J,W,ce),L.modelViewMatrix.multiplyMatrices(Z.matrixWorldInverse,L.matrixWorld),L.normalMatrix.getNormalMatrix(L.modelViewMatrix),W.onBeforeRender(y,H,Z,J,L,ce),W.transparent===!0&&W.side===bn&&W.forceSinglePass===!1?(W.side=on,W.needsUpdate=!0,y.renderBufferDirect(Z,H,J,W,L,ce),W.side=Si,W.needsUpdate=!0,y.renderBufferDirect(Z,H,J,W,L,ce),W.side=bn):y.renderBufferDirect(Z,H,J,W,L,ce),L.onAfterRender(y,H,Z,J,W,ce)}function qt(L,H,Z){H.isScene!==!0&&(H=Se);let J=Ee.get(L),W=m.state.lights,ce=m.state.shadowsArray,_e=W.state.version,Re=te.getParameters(L,W.state,ce,H,Z),we=te.getProgramCacheKey(Re),Ve=J.programs;J.environment=L.isMeshStandardMaterial?H.environment:null,J.fog=H.fog,J.envMap=(L.isMeshStandardMaterial?gt:yt).get(L.envMap||J.environment),J.envMapRotation=J.environment!==null&&L.envMap===null?H.environmentRotation:L.envMapRotation,Ve===void 0&&(L.addEventListener("dispose",ie),Ve=new Map,J.programs=Ve);let qe=Ve.get(we);if(qe!==void 0){if(J.currentProgram===qe&&J.lightsStateVersion===_e)return wr(L,Re),qe}else Re.uniforms=te.getUniforms(L),L.onBeforeCompile(Re,y),qe=te.acquireProgram(Re,we),Ve.set(we,qe),J.uniforms=Re.uniforms;let ze=J.uniforms;return(!L.isShaderMaterial&&!L.isRawShaderMaterial||L.clipping===!0)&&(ze.clippingPlanes=fe.uniform),wr(L,Re),J.needsLights=Po(L),J.lightsStateVersion=_e,J.needsLights&&(ze.ambientLightColor.value=W.state.ambient,ze.lightProbe.value=W.state.probe,ze.directionalLights.value=W.state.directional,ze.directionalLightShadows.value=W.state.directionalShadow,ze.spotLights.value=W.state.spot,ze.spotLightShadows.value=W.state.spotShadow,ze.rectAreaLights.value=W.state.rectArea,ze.ltc_1.value=W.state.rectAreaLTC1,ze.ltc_2.value=W.state.rectAreaLTC2,ze.pointLights.value=W.state.point,ze.pointLightShadows.value=W.state.pointShadow,ze.hemisphereLights.value=W.state.hemi,ze.directionalShadowMap.value=W.state.directionalShadowMap,ze.directionalShadowMatrix.value=W.state.directionalShadowMatrix,ze.spotShadowMap.value=W.state.spotShadowMap,ze.spotLightMatrix.value=W.state.spotLightMatrix,ze.spotLightMap.value=W.state.spotLightMap,ze.pointShadowMap.value=W.state.pointShadowMap,ze.pointShadowMatrix.value=W.state.pointShadowMatrix),J.currentProgram=qe,J.uniformsList=null,qe}function br(L){if(L.uniformsList===null){let H=L.currentProgram.getUniforms();L.uniformsList=fr.seqWithValue(H.seq,L.uniforms)}return L.uniformsList}function wr(L,H){let Z=Ee.get(L);Z.outputColorSpace=H.outputColorSpace,Z.batching=H.batching,Z.batchingColor=H.batchingColor,Z.instancing=H.instancing,Z.instancingColor=H.instancingColor,Z.instancingMorph=H.instancingMorph,Z.skinning=H.skinning,Z.morphTargets=H.morphTargets,Z.morphNormals=H.morphNormals,Z.morphColors=H.morphColors,Z.morphTargetsCount=H.morphTargetsCount,Z.numClippingPlanes=H.numClippingPlanes,Z.numIntersection=H.numClipIntersection,Z.vertexAlphas=H.vertexAlphas,Z.vertexTangents=H.vertexTangents,Z.toneMapping=H.toneMapping}function Oe(L,H,Z,J,W){H.isScene!==!0&&(H=Se),Ke.resetTextureUnits();let ce=H.fog,_e=J.isMeshStandardMaterial?H.environment:null,Re=A===null?y.outputColorSpace:A.isXRRenderTarget===!0?A.texture.colorSpace:gs,we=(J.isMeshStandardMaterial?gt:yt).get(J.envMap||_e),Ve=J.vertexColors===!0&&!!Z.attributes.color&&Z.attributes.color.itemSize===4,qe=!!Z.attributes.tangent&&(!!J.normalMap||J.anisotropy>0),ze=!!Z.morphAttributes.position,rt=!!Z.morphAttributes.normal,je=!!Z.morphAttributes.color,V=Ti;J.toneMapped&&(A===null||A.isXRRenderTarget===!0)&&(V=y.toneMapping);let $=Z.morphAttributes.position||Z.morphAttributes.normal||Z.morphAttributes.color,q=$!==void 0?$.length:0,re=Ee.get(J),ge=m.state.lights;if(We===!0&&(j===!0||L!==w)){let rn=L===w&&J.id===b;fe.setState(J,L,rn)}let Ie=!1;J.version===re.__version?(re.needsLights&&re.lightsStateVersion!==ge.state.version||re.outputColorSpace!==Re||W.isBatchedMesh&&re.batching===!1||!W.isBatchedMesh&&re.batching===!0||W.isBatchedMesh&&re.batchingColor===!0&&W.colorTexture===null||W.isBatchedMesh&&re.batchingColor===!1&&W.colorTexture!==null||W.isInstancedMesh&&re.instancing===!1||!W.isInstancedMesh&&re.instancing===!0||W.isSkinnedMesh&&re.skinning===!1||!W.isSkinnedMesh&&re.skinning===!0||W.isInstancedMesh&&re.instancingColor===!0&&W.instanceColor===null||W.isInstancedMesh&&re.instancingColor===!1&&W.instanceColor!==null||W.isInstancedMesh&&re.instancingMorph===!0&&W.morphTexture===null||W.isInstancedMesh&&re.instancingMorph===!1&&W.morphTexture!==null||re.envMap!==we||J.fog===!0&&re.fog!==ce||re.numClippingPlanes!==void 0&&(re.numClippingPlanes!==fe.numPlanes||re.numIntersection!==fe.numIntersection)||re.vertexAlphas!==Ve||re.vertexTangents!==qe||re.morphTargets!==ze||re.morphNormals!==rt||re.morphColors!==je||re.toneMapping!==V||re.morphTargetsCount!==q)&&(Ie=!0):(Ie=!0,re.__version=J.version);let At=re.currentProgram;Ie===!0&&(At=qt(J,H,W));let Hn=!1,xn=!1,Er=!1,_t=At.getUniforms(),In=re.uniforms;if(be.useProgram(At.program)&&(Hn=!0,xn=!0,Er=!0),J.id!==b&&(b=J.id,xn=!0),Hn||w!==L){be.buffers.depth.getReversed()&&L.reversedDepth!==!0&&(L._reversedDepth=!0,L.updateProjectionMatrix()),_t.setValue(U,"projectionMatrix",L.projectionMatrix),_t.setValue(U,"viewMatrix",L.matrixWorldInverse);let cn=_t.map.cameraPosition;cn!==void 0&&cn.setValue(U,ye.setFromMatrixPosition(L.matrixWorld)),ke.logarithmicDepthBuffer&&_t.setValue(U,"logDepthBufFC",2/(Math.log(L.far+1)/Math.LN2)),(J.isMeshPhongMaterial||J.isMeshToonMaterial||J.isMeshLambertMaterial||J.isMeshBasicMaterial||J.isMeshStandardMaterial||J.isShaderMaterial)&&_t.setValue(U,"isOrthographic",L.isOrthographicCamera===!0),w!==L&&(w=L,xn=!0,Er=!0)}if(W.isSkinnedMesh){_t.setOptional(U,W,"bindMatrix"),_t.setOptional(U,W,"bindMatrixInverse");let rn=W.skeleton;rn&&(rn.boneTexture===null&&rn.computeBoneTexture(),_t.setValue(U,"boneTexture",rn.boneTexture,Ke))}W.isBatchedMesh&&(_t.setOptional(U,W,"batchingTexture"),_t.setValue(U,"batchingTexture",W._matricesTexture,Ke),_t.setOptional(U,W,"batchingIdTexture"),_t.setValue(U,"batchingIdTexture",W._indirectTexture,Ke),_t.setOptional(U,W,"batchingColorTexture"),W._colorsTexture!==null&&_t.setValue(U,"batchingColorTexture",W._colorsTexture,Ke));let Nn=Z.morphAttributes;if((Nn.position!==void 0||Nn.normal!==void 0||Nn.color!==void 0)&&he.update(W,Z,At),(xn||re.receiveShadow!==W.receiveShadow)&&(re.receiveShadow=W.receiveShadow,_t.setValue(U,"receiveShadow",W.receiveShadow)),J.isMeshGouraudMaterial&&J.envMap!==null&&(In.envMap.value=we,In.flipEnvMap.value=we.isCubeTexture&&we.isRenderTargetTexture===!1?-1:1),J.isMeshStandardMaterial&&J.envMap===null&&H.environment!==null&&(In.envMapIntensity.value=H.environmentIntensity),xn&&(_t.setValue(U,"toneMappingExposure",y.toneMappingExposure),re.needsLights&&tc(In,Er),ce&&J.fog===!0&&se.refreshFogUniforms(In,ce),se.refreshMaterialUniforms(In,J,O,z,m.state.transmissionRenderTarget[L.id]),fr.upload(U,br(re),In,Ke)),J.isShaderMaterial&&J.uniformsNeedUpdate===!0&&(fr.upload(U,br(re),In,Ke),J.uniformsNeedUpdate=!1),J.isSpriteMaterial&&_t.setValue(U,"center",W.center),_t.setValue(U,"modelViewMatrix",W.modelViewMatrix),_t.setValue(U,"normalMatrix",W.normalMatrix),_t.setValue(U,"modelMatrix",W.matrixWorld),J.isShaderMaterial||J.isRawShaderMaterial){let rn=J.uniformsGroups;for(let cn=0,sc=rn.length;cn<sc;cn++){let ls=rn[cn];Qe.update(ls,At),Qe.bind(ls,At)}}return At}function tc(L,H){L.ambientLightColor.needsUpdate=H,L.lightProbe.needsUpdate=H,L.directionalLights.needsUpdate=H,L.directionalLightShadows.needsUpdate=H,L.pointLights.needsUpdate=H,L.pointLightShadows.needsUpdate=H,L.spotLights.needsUpdate=H,L.spotLightShadows.needsUpdate=H,L.rectAreaLights.needsUpdate=H,L.hemisphereLights.needsUpdate=H}function Po(L){return L.isMeshLambertMaterial||L.isMeshToonMaterial||L.isMeshPhongMaterial||L.isMeshStandardMaterial||L.isShadowMaterial||L.isShaderMaterial&&L.lights===!0}this.getActiveCubeFace=function(){return M},this.getActiveMipmapLevel=function(){return E},this.getRenderTarget=function(){return A},this.setRenderTargetTextures=function(L,H,Z){let J=Ee.get(L);J.__autoAllocateDepthBuffer=L.resolveDepthBuffer===!1,J.__autoAllocateDepthBuffer===!1&&(J.__useRenderToTexture=!1),Ee.get(L.texture).__webglTexture=H,Ee.get(L.depthTexture).__webglTexture=J.__autoAllocateDepthBuffer?void 0:Z,J.__hasExternalTextures=!0},this.setRenderTargetFramebuffer=function(L,H){let Z=Ee.get(L);Z.__webglFramebuffer=H,Z.__useDefaultFramebuffer=H===void 0};let nc=U.createFramebuffer();this.setRenderTarget=function(L,H=0,Z=0){A=L,M=H,E=Z;let J=!0,W=null,ce=!1,_e=!1;if(L){let we=Ee.get(L);if(we.__useDefaultFramebuffer!==void 0)be.bindFramebuffer(U.FRAMEBUFFER,null),J=!1;else if(we.__webglFramebuffer===void 0)Ke.setupRenderTarget(L);else if(we.__hasExternalTextures)Ke.rebindTextures(L,Ee.get(L.texture).__webglTexture,Ee.get(L.depthTexture).__webglTexture);else if(L.depthBuffer){let ze=L.depthTexture;if(we.__boundDepthTexture!==ze){if(ze!==null&&Ee.has(ze)&&(L.width!==ze.image.width||L.height!==ze.image.height))throw new Error("WebGLRenderTarget: Attached DepthTexture is initialized to the incorrect size.");Ke.setupDepthRenderbuffer(L)}}let Ve=L.texture;(Ve.isData3DTexture||Ve.isDataArrayTexture||Ve.isCompressedArrayTexture)&&(_e=!0);let qe=Ee.get(L).__webglFramebuffer;L.isWebGLCubeRenderTarget?(Array.isArray(qe[H])?W=qe[H][Z]:W=qe[H],ce=!0):L.samples>0&&Ke.useMultisampledRTT(L)===!1?W=Ee.get(L).__webglMultisampledFramebuffer:Array.isArray(qe)?W=qe[Z]:W=qe,T.copy(L.viewport),F.copy(L.scissor),D=L.scissorTest}else T.copy(oe).multiplyScalar(O).floor(),F.copy(ae).multiplyScalar(O).floor(),D=Ge;if(Z!==0&&(W=nc),be.bindFramebuffer(U.FRAMEBUFFER,W)&&J&&be.drawBuffers(L,W),be.viewport(T),be.scissor(F),be.setScissorTest(D),ce){let we=Ee.get(L.texture);U.framebufferTexture2D(U.FRAMEBUFFER,U.COLOR_ATTACHMENT0,U.TEXTURE_CUBE_MAP_POSITIVE_X+H,we.__webglTexture,Z)}else if(_e){let we=H;for(let Ve=0;Ve<L.textures.length;Ve++){let qe=Ee.get(L.textures[Ve]);U.framebufferTextureLayer(U.FRAMEBUFFER,U.COLOR_ATTACHMENT0+Ve,qe.__webglTexture,Z,we)}}else if(L!==null&&Z!==0){let we=Ee.get(L.texture);U.framebufferTexture2D(U.FRAMEBUFFER,U.COLOR_ATTACHMENT0,U.TEXTURE_2D,we.__webglTexture,Z)}b=-1},this.readRenderTargetPixels=function(L,H,Z,J,W,ce,_e,Re=0){if(!(L&&L.isWebGLRenderTarget)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");return}let we=Ee.get(L).__webglFramebuffer;if(L.isWebGLCubeRenderTarget&&_e!==void 0&&(we=we[_e]),we){be.bindFramebuffer(U.FRAMEBUFFER,we);try{let Ve=L.textures[Re],qe=Ve.format,ze=Ve.type;if(!ke.textureFormatReadable(qe)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.");return}if(!ke.textureTypeReadable(ze)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.");return}H>=0&&H<=L.width-J&&Z>=0&&Z<=L.height-W&&(L.textures.length>1&&U.readBuffer(U.COLOR_ATTACHMENT0+Re),U.readPixels(H,Z,J,W,Be.convert(qe),Be.convert(ze),ce))}finally{let Ve=A!==null?Ee.get(A).__webglFramebuffer:null;be.bindFramebuffer(U.FRAMEBUFFER,Ve)}}},this.readRenderTargetPixelsAsync=async function(L,H,Z,J,W,ce,_e,Re=0){if(!(L&&L.isWebGLRenderTarget))throw new Error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");let we=Ee.get(L).__webglFramebuffer;if(L.isWebGLCubeRenderTarget&&_e!==void 0&&(we=we[_e]),we)if(H>=0&&H<=L.width-J&&Z>=0&&Z<=L.height-W){be.bindFramebuffer(U.FRAMEBUFFER,we);let Ve=L.textures[Re],qe=Ve.format,ze=Ve.type;if(!ke.textureFormatReadable(qe))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.");if(!ke.textureTypeReadable(ze))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.");let rt=U.createBuffer();U.bindBuffer(U.PIXEL_PACK_BUFFER,rt),U.bufferData(U.PIXEL_PACK_BUFFER,ce.byteLength,U.STREAM_READ),L.textures.length>1&&U.readBuffer(U.COLOR_ATTACHMENT0+Re),U.readPixels(H,Z,J,W,Be.convert(qe),Be.convert(ze),0);let je=A!==null?Ee.get(A).__webglFramebuffer:null;be.bindFramebuffer(U.FRAMEBUFFER,je);let V=U.fenceSync(U.SYNC_GPU_COMMANDS_COMPLETE,0);return U.flush(),await _f(U,V,4),U.bindBuffer(U.PIXEL_PACK_BUFFER,rt),U.getBufferSubData(U.PIXEL_PACK_BUFFER,0,ce),U.deleteBuffer(rt),U.deleteSync(V),ce}else throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.")},this.copyFramebufferToTexture=function(L,H=null,Z=0){let J=Math.pow(2,-Z),W=Math.floor(L.image.width*J),ce=Math.floor(L.image.height*J),_e=H!==null?H.x:0,Re=H!==null?H.y:0;Ke.setTexture2D(L,0),U.copyTexSubImage2D(U.TEXTURE_2D,Z,0,0,_e,Re,W,ce),be.unbindTexture()};let Io=U.createFramebuffer(),ic=U.createFramebuffer();this.copyTextureToTexture=function(L,H,Z=null,J=null,W=0,ce=null){ce===null&&(W!==0?(Ks("WebGLRenderer: copyTextureToTexture function signature has changed to support src and dst mipmap levels."),ce=W,W=0):ce=0);let _e,Re,we,Ve,qe,ze,rt,je,V,$=L.isCompressedTexture?L.mipmaps[ce]:L.image;if(Z!==null)_e=Z.max.x-Z.min.x,Re=Z.max.y-Z.min.y,we=Z.isBox3?Z.max.z-Z.min.z:1,Ve=Z.min.x,qe=Z.min.y,ze=Z.isBox3?Z.min.z:0;else{let Nn=Math.pow(2,-W);_e=Math.floor($.width*Nn),Re=Math.floor($.height*Nn),L.isDataArrayTexture?we=$.depth:L.isData3DTexture?we=Math.floor($.depth*Nn):we=1,Ve=0,qe=0,ze=0}J!==null?(rt=J.x,je=J.y,V=J.z):(rt=0,je=0,V=0);let q=Be.convert(H.format),re=Be.convert(H.type),ge;H.isData3DTexture?(Ke.setTexture3D(H,0),ge=U.TEXTURE_3D):H.isDataArrayTexture||H.isCompressedArrayTexture?(Ke.setTexture2DArray(H,0),ge=U.TEXTURE_2D_ARRAY):(Ke.setTexture2D(H,0),ge=U.TEXTURE_2D),U.pixelStorei(U.UNPACK_FLIP_Y_WEBGL,H.flipY),U.pixelStorei(U.UNPACK_PREMULTIPLY_ALPHA_WEBGL,H.premultiplyAlpha),U.pixelStorei(U.UNPACK_ALIGNMENT,H.unpackAlignment);let Ie=U.getParameter(U.UNPACK_ROW_LENGTH),At=U.getParameter(U.UNPACK_IMAGE_HEIGHT),Hn=U.getParameter(U.UNPACK_SKIP_PIXELS),xn=U.getParameter(U.UNPACK_SKIP_ROWS),Er=U.getParameter(U.UNPACK_SKIP_IMAGES);U.pixelStorei(U.UNPACK_ROW_LENGTH,$.width),U.pixelStorei(U.UNPACK_IMAGE_HEIGHT,$.height),U.pixelStorei(U.UNPACK_SKIP_PIXELS,Ve),U.pixelStorei(U.UNPACK_SKIP_ROWS,qe),U.pixelStorei(U.UNPACK_SKIP_IMAGES,ze);let _t=L.isDataArrayTexture||L.isData3DTexture,In=H.isDataArrayTexture||H.isData3DTexture;if(L.isDepthTexture){let Nn=Ee.get(L),rn=Ee.get(H),cn=Ee.get(Nn.__renderTarget),sc=Ee.get(rn.__renderTarget);be.bindFramebuffer(U.READ_FRAMEBUFFER,cn.__webglFramebuffer),be.bindFramebuffer(U.DRAW_FRAMEBUFFER,sc.__webglFramebuffer);for(let ls=0;ls<we;ls++)_t&&(U.framebufferTextureLayer(U.READ_FRAMEBUFFER,U.COLOR_ATTACHMENT0,Ee.get(L).__webglTexture,W,ze+ls),U.framebufferTextureLayer(U.DRAW_FRAMEBUFFER,U.COLOR_ATTACHMENT0,Ee.get(H).__webglTexture,ce,V+ls)),U.blitFramebuffer(Ve,qe,_e,Re,rt,je,_e,Re,U.DEPTH_BUFFER_BIT,U.NEAREST);be.bindFramebuffer(U.READ_FRAMEBUFFER,null),be.bindFramebuffer(U.DRAW_FRAMEBUFFER,null)}else if(W!==0||L.isRenderTargetTexture||Ee.has(L)){let Nn=Ee.get(L),rn=Ee.get(H);be.bindFramebuffer(U.READ_FRAMEBUFFER,Io),be.bindFramebuffer(U.DRAW_FRAMEBUFFER,ic);for(let cn=0;cn<we;cn++)_t?U.framebufferTextureLayer(U.READ_FRAMEBUFFER,U.COLOR_ATTACHMENT0,Nn.__webglTexture,W,ze+cn):U.framebufferTexture2D(U.READ_FRAMEBUFFER,U.COLOR_ATTACHMENT0,U.TEXTURE_2D,Nn.__webglTexture,W),In?U.framebufferTextureLayer(U.DRAW_FRAMEBUFFER,U.COLOR_ATTACHMENT0,rn.__webglTexture,ce,V+cn):U.framebufferTexture2D(U.DRAW_FRAMEBUFFER,U.COLOR_ATTACHMENT0,U.TEXTURE_2D,rn.__webglTexture,ce),W!==0?U.blitFramebuffer(Ve,qe,_e,Re,rt,je,_e,Re,U.COLOR_BUFFER_BIT,U.NEAREST):In?U.copyTexSubImage3D(ge,ce,rt,je,V+cn,Ve,qe,_e,Re):U.copyTexSubImage2D(ge,ce,rt,je,Ve,qe,_e,Re);be.bindFramebuffer(U.READ_FRAMEBUFFER,null),be.bindFramebuffer(U.DRAW_FRAMEBUFFER,null)}else In?L.isDataTexture||L.isData3DTexture?U.texSubImage3D(ge,ce,rt,je,V,_e,Re,we,q,re,$.data):H.isCompressedArrayTexture?U.compressedTexSubImage3D(ge,ce,rt,je,V,_e,Re,we,q,$.data):U.texSubImage3D(ge,ce,rt,je,V,_e,Re,we,q,re,$):L.isDataTexture?U.texSubImage2D(U.TEXTURE_2D,ce,rt,je,_e,Re,q,re,$.data):L.isCompressedTexture?U.compressedTexSubImage2D(U.TEXTURE_2D,ce,rt,je,$.width,$.height,q,$.data):U.texSubImage2D(U.TEXTURE_2D,ce,rt,je,_e,Re,q,re,$);U.pixelStorei(U.UNPACK_ROW_LENGTH,Ie),U.pixelStorei(U.UNPACK_IMAGE_HEIGHT,At),U.pixelStorei(U.UNPACK_SKIP_PIXELS,Hn),U.pixelStorei(U.UNPACK_SKIP_ROWS,xn),U.pixelStorei(U.UNPACK_SKIP_IMAGES,Er),ce===0&&H.generateMipmaps&&U.generateMipmap(ge),be.unbindTexture()},this.initRenderTarget=function(L){Ee.get(L).__webglFramebuffer===void 0&&Ke.setupRenderTarget(L)},this.initTexture=function(L){L.isCubeTexture?Ke.setTextureCube(L,0):L.isData3DTexture?Ke.setTexture3D(L,0):L.isDataArrayTexture||L.isCompressedArrayTexture?Ke.setTexture2DArray(L,0):Ke.setTexture2D(L,0),be.unbindTexture()},this.resetState=function(){M=0,E=0,A=null,be.reset(),me.reset()},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}get coordinateSystem(){return Xn}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(e){this._outputColorSpace=e;let t=this.getContext();t.drawingBufferColorSpace=lt._getDrawingBufferColorSpace(e),t.unpackColorSpace=lt._getUnpackColorSpace()}};var nu=rc(Ml(),1);var ts=class r{constructor(e){e===void 0&&(e=[0,0,0,0,0,0,0,0,0]),this.elements=e}identity(){let e=this.elements;e[0]=1,e[1]=0,e[2]=0,e[3]=0,e[4]=1,e[5]=0,e[6]=0,e[7]=0,e[8]=1}setZero(){let e=this.elements;e[0]=0,e[1]=0,e[2]=0,e[3]=0,e[4]=0,e[5]=0,e[6]=0,e[7]=0,e[8]=0}setTrace(e){let t=this.elements;t[0]=e.x,t[4]=e.y,t[8]=e.z}getTrace(e){e===void 0&&(e=new R);let t=this.elements;return e.x=t[0],e.y=t[4],e.z=t[8],e}vmult(e,t){t===void 0&&(t=new R);let n=this.elements,i=e.x,s=e.y,o=e.z;return t.x=n[0]*i+n[1]*s+n[2]*o,t.y=n[3]*i+n[4]*s+n[5]*o,t.z=n[6]*i+n[7]*s+n[8]*o,t}smult(e){for(let t=0;t<this.elements.length;t++)this.elements[t]*=e}mmult(e,t){t===void 0&&(t=new r);let n=this.elements,i=e.elements,s=t.elements,o=n[0],a=n[1],l=n[2],h=n[3],f=n[4],c=n[5],u=n[6],d=n[7],p=n[8],v=i[0],g=i[1],m=i[2],_=i[3],x=i[4],y=i[5],S=i[6],M=i[7],E=i[8];return s[0]=o*v+a*_+l*S,s[1]=o*g+a*x+l*M,s[2]=o*m+a*y+l*E,s[3]=h*v+f*_+c*S,s[4]=h*g+f*x+c*M,s[5]=h*m+f*y+c*E,s[6]=u*v+d*_+p*S,s[7]=u*g+d*x+p*M,s[8]=u*m+d*y+p*E,t}scale(e,t){t===void 0&&(t=new r);let n=this.elements,i=t.elements;for(let s=0;s!==3;s++)i[3*s+0]=e.x*n[3*s+0],i[3*s+1]=e.y*n[3*s+1],i[3*s+2]=e.z*n[3*s+2];return t}solve(e,t){t===void 0&&(t=new R);let n=3,i=4,s=[],o,a;for(o=0;o<n*i;o++)s.push(0);for(o=0;o<3;o++)for(a=0;a<3;a++)s[o+i*a]=this.elements[o+3*a];s[3]=e.x,s[7]=e.y,s[11]=e.z;let l=3,h=l,f,c=4,u;do{if(o=h-l,s[o+i*o]===0){for(a=o+1;a<h;a++)if(s[o+i*a]!==0){f=c;do u=c-f,s[u+i*o]+=s[u+i*a];while(--f);break}}if(s[o+i*o]!==0)for(a=o+1;a<h;a++){let d=s[o+i*a]/s[o+i*o];f=c;do u=c-f,s[u+i*a]=u<=o?0:s[u+i*a]-s[u+i*o]*d;while(--f)}}while(--l);if(t.z=s[2*i+3]/s[2*i+2],t.y=(s[1*i+3]-s[1*i+2]*t.z)/s[1*i+1],t.x=(s[0*i+3]-s[0*i+2]*t.z-s[0*i+1]*t.y)/s[0*i+0],isNaN(t.x)||isNaN(t.y)||isNaN(t.z)||t.x===1/0||t.y===1/0||t.z===1/0)throw`Could not solve equation! Got x=[${t.toString()}], b=[${e.toString()}], A=[${this.toString()}]`;return t}e(e,t,n){if(n===void 0)return this.elements[t+3*e];this.elements[t+3*e]=n}copy(e){for(let t=0;t<e.elements.length;t++)this.elements[t]=e.elements[t];return this}toString(){let e="";for(let n=0;n<9;n++)e+=this.elements[n]+",";return e}reverse(e){e===void 0&&(e=new r);let t=3,n=6,i=ux,s,o;for(s=0;s<3;s++)for(o=0;o<3;o++)i[s+n*o]=this.elements[s+3*o];i[3]=1,i[9]=0,i[15]=0,i[4]=0,i[10]=1,i[16]=0,i[5]=0,i[11]=0,i[17]=1;let a=3,l=a,h,f=n,c;do{if(s=l-a,i[s+n*s]===0){for(o=s+1;o<l;o++)if(i[s+n*o]!==0){h=f;do c=f-h,i[c+n*s]+=i[c+n*o];while(--h);break}}if(i[s+n*s]!==0)for(o=s+1;o<l;o++){let u=i[s+n*o]/i[s+n*s];h=f;do c=f-h,i[c+n*o]=c<=s?0:i[c+n*o]-i[c+n*s]*u;while(--h)}}while(--a);s=2;do{o=s-1;do{let u=i[s+n*o]/i[s+n*s];h=n;do c=n-h,i[c+n*o]=i[c+n*o]-i[c+n*s]*u;while(--h)}while(o--)}while(--s);s=2;do{let u=1/i[s+n*s];h=n;do c=n-h,i[c+n*s]=i[c+n*s]*u;while(--h)}while(s--);s=2;do{o=2;do{if(c=i[t+o+n*s],isNaN(c)||c===1/0)throw`Could not reverse! A=[${this.toString()}]`;e.e(s,o,c)}while(o--)}while(s--);return e}setRotationFromQuaternion(e){let t=e.x,n=e.y,i=e.z,s=e.w,o=t+t,a=n+n,l=i+i,h=t*o,f=t*a,c=t*l,u=n*a,d=n*l,p=i*l,v=s*o,g=s*a,m=s*l,_=this.elements;return _[0]=1-(u+p),_[1]=f-m,_[2]=c+g,_[3]=f+m,_[4]=1-(h+p),_[5]=d-v,_[6]=c-g,_[7]=d+v,_[8]=1-(h+u),this}transpose(e){e===void 0&&(e=new r);let t=this.elements,n=e.elements,i;return n[0]=t[0],n[4]=t[4],n[8]=t[8],i=t[1],n[1]=t[3],n[3]=i,i=t[2],n[2]=t[6],n[6]=i,i=t[5],n[5]=t[7],n[7]=i,e}},ux=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],R=class r{constructor(e,t,n){e===void 0&&(e=0),t===void 0&&(t=0),n===void 0&&(n=0),this.x=e,this.y=t,this.z=n}cross(e,t){t===void 0&&(t=new r);let n=e.x,i=e.y,s=e.z,o=this.x,a=this.y,l=this.z;return t.x=a*s-l*i,t.y=l*n-o*s,t.z=o*i-a*n,t}set(e,t,n){return this.x=e,this.y=t,this.z=n,this}setZero(){this.x=this.y=this.z=0}vadd(e,t){if(t)t.x=e.x+this.x,t.y=e.y+this.y,t.z=e.z+this.z;else return new r(this.x+e.x,this.y+e.y,this.z+e.z)}vsub(e,t){if(t)t.x=this.x-e.x,t.y=this.y-e.y,t.z=this.z-e.z;else return new r(this.x-e.x,this.y-e.y,this.z-e.z)}crossmat(){return new ts([0,-this.z,this.y,this.z,0,-this.x,-this.y,this.x,0])}normalize(){let e=this.x,t=this.y,n=this.z,i=Math.sqrt(e*e+t*t+n*n);if(i>0){let s=1/i;this.x*=s,this.y*=s,this.z*=s}else this.x=0,this.y=0,this.z=0;return i}unit(e){e===void 0&&(e=new r);let t=this.x,n=this.y,i=this.z,s=Math.sqrt(t*t+n*n+i*i);return s>0?(s=1/s,e.x=t*s,e.y=n*s,e.z=i*s):(e.x=1,e.y=0,e.z=0),e}length(){let e=this.x,t=this.y,n=this.z;return Math.sqrt(e*e+t*t+n*n)}lengthSquared(){return this.dot(this)}distanceTo(e){let t=this.x,n=this.y,i=this.z,s=e.x,o=e.y,a=e.z;return Math.sqrt((s-t)*(s-t)+(o-n)*(o-n)+(a-i)*(a-i))}distanceSquared(e){let t=this.x,n=this.y,i=this.z,s=e.x,o=e.y,a=e.z;return(s-t)*(s-t)+(o-n)*(o-n)+(a-i)*(a-i)}scale(e,t){t===void 0&&(t=new r);let n=this.x,i=this.y,s=this.z;return t.x=e*n,t.y=e*i,t.z=e*s,t}vmul(e,t){return t===void 0&&(t=new r),t.x=e.x*this.x,t.y=e.y*this.y,t.z=e.z*this.z,t}addScaledVector(e,t,n){return n===void 0&&(n=new r),n.x=this.x+e*t.x,n.y=this.y+e*t.y,n.z=this.z+e*t.z,n}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z}isZero(){return this.x===0&&this.y===0&&this.z===0}negate(e){return e===void 0&&(e=new r),e.x=-this.x,e.y=-this.y,e.z=-this.z,e}tangents(e,t){let n=this.length();if(n>0){let i=fx,s=1/n;i.set(this.x*s,this.y*s,this.z*s);let o=dx;Math.abs(i.x)<.9?(o.set(1,0,0),i.cross(o,e)):(o.set(0,1,0),i.cross(o,e)),i.cross(e,t)}else e.set(1,0,0),t.set(0,1,0)}toString(){return`${this.x},${this.y},${this.z}`}toArray(){return[this.x,this.y,this.z]}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this}lerp(e,t,n){let i=this.x,s=this.y,o=this.z;n.x=i+(e.x-i)*t,n.y=s+(e.y-s)*t,n.z=o+(e.z-o)*t}almostEquals(e,t){return t===void 0&&(t=1e-6),!(Math.abs(this.x-e.x)>t||Math.abs(this.y-e.y)>t||Math.abs(this.z-e.z)>t)}almostZero(e){return e===void 0&&(e=1e-6),!(Math.abs(this.x)>e||Math.abs(this.y)>e||Math.abs(this.z)>e)}isAntiparallelTo(e,t){return this.negate(jf),jf.almostEquals(e,t)}clone(){return new r(this.x,this.y,this.z)}};R.ZERO=new R(0,0,0);R.UNIT_X=new R(1,0,0);R.UNIT_Y=new R(0,1,0);R.UNIT_Z=new R(0,0,1);var fx=new R,dx=new R,jf=new R,wn=class r{constructor(e){e===void 0&&(e={}),this.lowerBound=new R,this.upperBound=new R,e.lowerBound&&this.lowerBound.copy(e.lowerBound),e.upperBound&&this.upperBound.copy(e.upperBound)}setFromPoints(e,t,n,i){let s=this.lowerBound,o=this.upperBound,a=n;s.copy(e[0]),a&&a.vmult(s,s),o.copy(s);for(let l=1;l<e.length;l++){let h=e[l];a&&(a.vmult(h,Qf),h=Qf),h.x>o.x&&(o.x=h.x),h.x<s.x&&(s.x=h.x),h.y>o.y&&(o.y=h.y),h.y<s.y&&(s.y=h.y),h.z>o.z&&(o.z=h.z),h.z<s.z&&(s.z=h.z)}return t&&(t.vadd(s,s),t.vadd(o,o)),i&&(s.x-=i,s.y-=i,s.z-=i,o.x+=i,o.y+=i,o.z+=i),this}copy(e){return this.lowerBound.copy(e.lowerBound),this.upperBound.copy(e.upperBound),this}clone(){return new r().copy(this)}extend(e){this.lowerBound.x=Math.min(this.lowerBound.x,e.lowerBound.x),this.upperBound.x=Math.max(this.upperBound.x,e.upperBound.x),this.lowerBound.y=Math.min(this.lowerBound.y,e.lowerBound.y),this.upperBound.y=Math.max(this.upperBound.y,e.upperBound.y),this.lowerBound.z=Math.min(this.lowerBound.z,e.lowerBound.z),this.upperBound.z=Math.max(this.upperBound.z,e.upperBound.z)}overlaps(e){let t=this.lowerBound,n=this.upperBound,i=e.lowerBound,s=e.upperBound,o=i.x<=n.x&&n.x<=s.x||t.x<=s.x&&s.x<=n.x,a=i.y<=n.y&&n.y<=s.y||t.y<=s.y&&s.y<=n.y,l=i.z<=n.z&&n.z<=s.z||t.z<=s.z&&s.z<=n.z;return o&&a&&l}volume(){let e=this.lowerBound,t=this.upperBound;return(t.x-e.x)*(t.y-e.y)*(t.z-e.z)}contains(e){let t=this.lowerBound,n=this.upperBound,i=e.lowerBound,s=e.upperBound;return t.x<=i.x&&n.x>=s.x&&t.y<=i.y&&n.y>=s.y&&t.z<=i.z&&n.z>=s.z}getCorners(e,t,n,i,s,o,a,l){let h=this.lowerBound,f=this.upperBound;e.copy(h),t.set(f.x,h.y,h.z),n.set(f.x,f.y,h.z),i.set(h.x,f.y,f.z),s.set(f.x,h.y,f.z),o.set(h.x,f.y,h.z),a.set(h.x,h.y,f.z),l.copy(f)}toLocalFrame(e,t){let n=ed,i=n[0],s=n[1],o=n[2],a=n[3],l=n[4],h=n[5],f=n[6],c=n[7];this.getCorners(i,s,o,a,l,h,f,c);for(let u=0;u!==8;u++){let d=n[u];e.pointToLocal(d,d)}return t.setFromPoints(n)}toWorldFrame(e,t){let n=ed,i=n[0],s=n[1],o=n[2],a=n[3],l=n[4],h=n[5],f=n[6],c=n[7];this.getCorners(i,s,o,a,l,h,f,c);for(let u=0;u!==8;u++){let d=n[u];e.pointToWorld(d,d)}return t.setFromPoints(n)}overlapsRay(e){let{direction:t,from:n}=e,i=1/t.x,s=1/t.y,o=1/t.z,a=(this.lowerBound.x-n.x)*i,l=(this.upperBound.x-n.x)*i,h=(this.lowerBound.y-n.y)*s,f=(this.upperBound.y-n.y)*s,c=(this.lowerBound.z-n.z)*o,u=(this.upperBound.z-n.z)*o,d=Math.max(Math.max(Math.min(a,l),Math.min(h,f)),Math.min(c,u)),p=Math.min(Math.min(Math.max(a,l),Math.max(h,f)),Math.max(c,u));return!(p<0||d>p)}},Qf=new R,ed=[new R,new R,new R,new R,new R,new R,new R,new R],Tl=class{constructor(){this.matrix=[]}get(e,t){let{index:n}=e,{index:i}=t;if(i>n){let s=i;i=n,n=s}return this.matrix[(n*(n+1)>>1)+i-1]}set(e,t,n){let{index:i}=e,{index:s}=t;if(s>i){let o=s;s=i,i=o}this.matrix[(i*(i+1)>>1)+s-1]=n?1:0}reset(){for(let e=0,t=this.matrix.length;e!==t;e++)this.matrix[e]=0}setNumObjects(e){this.matrix.length=e*(e-1)>>1}},Cl=class{addEventListener(e,t){this._listeners===void 0&&(this._listeners={});let n=this._listeners;return n[e]===void 0&&(n[e]=[]),n[e].includes(t)||n[e].push(t),this}hasEventListener(e,t){if(this._listeners===void 0)return!1;let n=this._listeners;return!!(n[e]!==void 0&&n[e].includes(t))}hasAnyEventListener(e){return this._listeners===void 0?!1:this._listeners[e]!==void 0}removeEventListener(e,t){if(this._listeners===void 0)return this;let n=this._listeners;if(n[e]===void 0)return this;let i=n[e].indexOf(t);return i!==-1&&n[e].splice(i,1),this}dispatchEvent(e){if(this._listeners===void 0)return this;let n=this._listeners[e.type];if(n!==void 0){e.target=this;for(let i=0,s=n.length;i<s;i++)n[i].call(this,e)}return this}},Pt=class r{constructor(e,t,n,i){e===void 0&&(e=0),t===void 0&&(t=0),n===void 0&&(n=0),i===void 0&&(i=1),this.x=e,this.y=t,this.z=n,this.w=i}set(e,t,n,i){return this.x=e,this.y=t,this.z=n,this.w=i,this}toString(){return`${this.x},${this.y},${this.z},${this.w}`}toArray(){return[this.x,this.y,this.z,this.w]}setFromAxisAngle(e,t){let n=Math.sin(t*.5);return this.x=e.x*n,this.y=e.y*n,this.z=e.z*n,this.w=Math.cos(t*.5),this}toAxisAngle(e){e===void 0&&(e=new R),this.normalize();let t=2*Math.acos(this.w),n=Math.sqrt(1-this.w*this.w);return n<.001?(e.x=this.x,e.y=this.y,e.z=this.z):(e.x=this.x/n,e.y=this.y/n,e.z=this.z/n),[e,t]}setFromVectors(e,t){if(e.isAntiparallelTo(t)){let n=px,i=mx;e.tangents(n,i),this.setFromAxisAngle(n,Math.PI)}else{let n=e.cross(t);this.x=n.x,this.y=n.y,this.z=n.z,this.w=Math.sqrt(e.length()**2*t.length()**2)+e.dot(t),this.normalize()}return this}mult(e,t){t===void 0&&(t=new r);let n=this.x,i=this.y,s=this.z,o=this.w,a=e.x,l=e.y,h=e.z,f=e.w;return t.x=n*f+o*a+i*h-s*l,t.y=i*f+o*l+s*a-n*h,t.z=s*f+o*h+n*l-i*a,t.w=o*f-n*a-i*l-s*h,t}inverse(e){e===void 0&&(e=new r);let t=this.x,n=this.y,i=this.z,s=this.w;this.conjugate(e);let o=1/(t*t+n*n+i*i+s*s);return e.x*=o,e.y*=o,e.z*=o,e.w*=o,e}conjugate(e){return e===void 0&&(e=new r),e.x=-this.x,e.y=-this.y,e.z=-this.z,e.w=this.w,e}normalize(){let e=Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w);return e===0?(this.x=0,this.y=0,this.z=0,this.w=0):(e=1/e,this.x*=e,this.y*=e,this.z*=e,this.w*=e),this}normalizeFast(){let e=(3-(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w))/2;return e===0?(this.x=0,this.y=0,this.z=0,this.w=0):(this.x*=e,this.y*=e,this.z*=e,this.w*=e),this}vmult(e,t){t===void 0&&(t=new R);let n=e.x,i=e.y,s=e.z,o=this.x,a=this.y,l=this.z,h=this.w,f=h*n+a*s-l*i,c=h*i+l*n-o*s,u=h*s+o*i-a*n,d=-o*n-a*i-l*s;return t.x=f*h+d*-o+c*-l-u*-a,t.y=c*h+d*-a+u*-o-f*-l,t.z=u*h+d*-l+f*-a-c*-o,t}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this.w=e.w,this}toEuler(e,t){t===void 0&&(t="YZX");let n,i,s,o=this.x,a=this.y,l=this.z,h=this.w;switch(t){case"YZX":let f=o*a+l*h;if(f>.499&&(n=2*Math.atan2(o,h),i=Math.PI/2,s=0),f<-.499&&(n=-2*Math.atan2(o,h),i=-Math.PI/2,s=0),n===void 0){let c=o*o,u=a*a,d=l*l;n=Math.atan2(2*a*h-2*o*l,1-2*u-2*d),i=Math.asin(2*f),s=Math.atan2(2*o*h-2*a*l,1-2*c-2*d)}break;default:throw new Error(`Euler order ${t} not supported yet.`)}e.y=n,e.z=i,e.x=s}setFromEuler(e,t,n,i){i===void 0&&(i="XYZ");let s=Math.cos(e/2),o=Math.cos(t/2),a=Math.cos(n/2),l=Math.sin(e/2),h=Math.sin(t/2),f=Math.sin(n/2);return i==="XYZ"?(this.x=l*o*a+s*h*f,this.y=s*h*a-l*o*f,this.z=s*o*f+l*h*a,this.w=s*o*a-l*h*f):i==="YXZ"?(this.x=l*o*a+s*h*f,this.y=s*h*a-l*o*f,this.z=s*o*f-l*h*a,this.w=s*o*a+l*h*f):i==="ZXY"?(this.x=l*o*a-s*h*f,this.y=s*h*a+l*o*f,this.z=s*o*f+l*h*a,this.w=s*o*a-l*h*f):i==="ZYX"?(this.x=l*o*a-s*h*f,this.y=s*h*a+l*o*f,this.z=s*o*f-l*h*a,this.w=s*o*a+l*h*f):i==="YZX"?(this.x=l*o*a+s*h*f,this.y=s*h*a+l*o*f,this.z=s*o*f-l*h*a,this.w=s*o*a-l*h*f):i==="XZY"&&(this.x=l*o*a-s*h*f,this.y=s*h*a-l*o*f,this.z=s*o*f+l*h*a,this.w=s*o*a+l*h*f),this}clone(){return new r(this.x,this.y,this.z,this.w)}slerp(e,t,n){n===void 0&&(n=new r);let i=this.x,s=this.y,o=this.z,a=this.w,l=e.x,h=e.y,f=e.z,c=e.w,u,d,p,v,g;return d=i*l+s*h+o*f+a*c,d<0&&(d=-d,l=-l,h=-h,f=-f,c=-c),1-d>1e-6?(u=Math.acos(d),p=Math.sin(u),v=Math.sin((1-t)*u)/p,g=Math.sin(t*u)/p):(v=1-t,g=t),n.x=v*i+g*l,n.y=v*s+g*h,n.z=v*o+g*f,n.w=v*a+g*c,n}integrate(e,t,n,i){i===void 0&&(i=new r);let s=e.x*n.x,o=e.y*n.y,a=e.z*n.z,l=this.x,h=this.y,f=this.z,c=this.w,u=t*.5;return i.x+=u*(s*c+o*f-a*h),i.y+=u*(o*c+a*l-s*f),i.z+=u*(a*c+s*h-o*l),i.w+=u*(-s*l-o*h-a*f),i}},px=new R,mx=new R,gx={SPHERE:1,PLANE:2,BOX:4,COMPOUND:8,CONVEXPOLYHEDRON:16,HEIGHTFIELD:32,PARTICLE:64,CYLINDER:128,TRIMESH:256},Te=class r{constructor(e){e===void 0&&(e={}),this.id=r.idCounter++,this.type=e.type||0,this.boundingSphereRadius=0,this.collisionResponse=e.collisionResponse?e.collisionResponse:!0,this.collisionFilterGroup=e.collisionFilterGroup!==void 0?e.collisionFilterGroup:1,this.collisionFilterMask=e.collisionFilterMask!==void 0?e.collisionFilterMask:-1,this.material=e.material?e.material:null,this.body=null}updateBoundingSphereRadius(){throw`computeBoundingSphereRadius() not implemented for shape type ${this.type}`}volume(){throw`volume() not implemented for shape type ${this.type}`}calculateLocalInertia(e,t){throw`calculateLocalInertia() not implemented for shape type ${this.type}`}calculateWorldAABB(e,t,n,i){throw`calculateWorldAABB() not implemented for shape type ${this.type}`}};Te.idCounter=0;Te.types=gx;var ut=class r{constructor(e){e===void 0&&(e={}),this.position=new R,this.quaternion=new Pt,e.position&&this.position.copy(e.position),e.quaternion&&this.quaternion.copy(e.quaternion)}pointToLocal(e,t){return r.pointToLocalFrame(this.position,this.quaternion,e,t)}pointToWorld(e,t){return r.pointToWorldFrame(this.position,this.quaternion,e,t)}vectorToWorldFrame(e,t){return t===void 0&&(t=new R),this.quaternion.vmult(e,t),t}static pointToLocalFrame(e,t,n,i){return i===void 0&&(i=new R),n.vsub(e,i),t.conjugate(td),td.vmult(i,i),i}static pointToWorldFrame(e,t,n,i){return i===void 0&&(i=new R),t.vmult(n,i),i.vadd(e,i),i}static vectorToWorldFrame(e,t,n){return n===void 0&&(n=new R),e.vmult(t,n),n}static vectorToLocalFrame(e,t,n,i){return i===void 0&&(i=new R),t.w*=-1,t.vmult(n,i),t.w*=-1,i}},td=new Pt,Rl=class r extends Te{constructor(e){e===void 0&&(e={});let{vertices:t=[],faces:n=[],normals:i=[],axes:s,boundingSphereRadius:o}=e;super({type:Te.types.CONVEXPOLYHEDRON}),this.vertices=t,this.faces=n,this.faceNormals=i,this.faceNormals.length===0&&this.computeNormals(),o?this.boundingSphereRadius=o:this.updateBoundingSphereRadius(),this.worldVertices=[],this.worldVerticesNeedsUpdate=!0,this.worldFaceNormals=[],this.worldFaceNormalsNeedsUpdate=!0,this.uniqueAxes=s?s.slice():null,this.uniqueEdges=[],this.computeEdges()}computeEdges(){let e=this.faces,t=this.vertices,n=this.uniqueEdges;n.length=0;let i=new R;for(let s=0;s!==e.length;s++){let o=e[s],a=o.length;for(let l=0;l!==a;l++){let h=(l+1)%a;t[o[l]].vsub(t[o[h]],i),i.normalize();let f=!1;for(let c=0;c!==n.length;c++)if(n[c].almostEquals(i)||n[c].almostEquals(i)){f=!0;break}f||n.push(i.clone())}}}computeNormals(){this.faceNormals.length=this.faces.length;for(let e=0;e<this.faces.length;e++){for(let i=0;i<this.faces[e].length;i++)if(!this.vertices[this.faces[e][i]])throw new Error(`Vertex ${this.faces[e][i]} not found!`);let t=this.faceNormals[e]||new R;this.getFaceNormal(e,t),t.negate(t),this.faceNormals[e]=t;let n=this.vertices[this.faces[e][0]];if(t.dot(n)<0){console.error(`.faceNormals[${e}] = Vec3(${t.toString()}) looks like it points into the shape? The vertices follow. Make sure they are ordered CCW around the normal, using the right hand rule.`);for(let i=0;i<this.faces[e].length;i++)console.warn(`.vertices[${this.faces[e][i]}] = Vec3(${this.vertices[this.faces[e][i]].toString()})`)}}}getFaceNormal(e,t){let n=this.faces[e],i=this.vertices[n[0]],s=this.vertices[n[1]],o=this.vertices[n[2]];r.computeNormal(i,s,o,t)}static computeNormal(e,t,n,i){let s=new R,o=new R;t.vsub(e,o),n.vsub(t,s),s.cross(o,i),i.isZero()||i.normalize()}clipAgainstHull(e,t,n,i,s,o,a,l,h){let f=new R,c=-1,u=-Number.MAX_VALUE;for(let p=0;p<n.faces.length;p++){f.copy(n.faceNormals[p]),s.vmult(f,f);let v=f.dot(o);v>u&&(u=v,c=p)}let d=[];for(let p=0;p<n.faces[c].length;p++){let v=n.vertices[n.faces[c][p]],g=new R;g.copy(v),s.vmult(g,g),i.vadd(g,g),d.push(g)}c>=0&&this.clipFaceAgainstHull(o,e,t,d,a,l,h)}findSeparatingAxis(e,t,n,i,s,o,a,l){let h=new R,f=new R,c=new R,u=new R,d=new R,p=new R,v=Number.MAX_VALUE,g=this;if(g.uniqueAxes)for(let m=0;m!==g.uniqueAxes.length;m++){n.vmult(g.uniqueAxes[m],h);let _=g.testSepAxis(h,e,t,n,i,s);if(_===!1)return!1;_<v&&(v=_,o.copy(h))}else{let m=a?a.length:g.faces.length;for(let _=0;_<m;_++){let x=a?a[_]:_;h.copy(g.faceNormals[x]),n.vmult(h,h);let y=g.testSepAxis(h,e,t,n,i,s);if(y===!1)return!1;y<v&&(v=y,o.copy(h))}}if(e.uniqueAxes)for(let m=0;m!==e.uniqueAxes.length;m++){s.vmult(e.uniqueAxes[m],f);let _=g.testSepAxis(f,e,t,n,i,s);if(_===!1)return!1;_<v&&(v=_,o.copy(f))}else{let m=l?l.length:e.faces.length;for(let _=0;_<m;_++){let x=l?l[_]:_;f.copy(e.faceNormals[x]),s.vmult(f,f);let y=g.testSepAxis(f,e,t,n,i,s);if(y===!1)return!1;y<v&&(v=y,o.copy(f))}}for(let m=0;m!==g.uniqueEdges.length;m++){n.vmult(g.uniqueEdges[m],u);for(let _=0;_!==e.uniqueEdges.length;_++)if(s.vmult(e.uniqueEdges[_],d),u.cross(d,p),!p.almostZero()){p.normalize();let x=g.testSepAxis(p,e,t,n,i,s);if(x===!1)return!1;x<v&&(v=x,o.copy(p))}}return i.vsub(t,c),c.dot(o)>0&&o.negate(o),!0}testSepAxis(e,t,n,i,s,o){let a=this;r.project(a,e,n,i,Eh),r.project(t,e,s,o,Ah);let l=Eh[0],h=Eh[1],f=Ah[0],c=Ah[1];if(l<c||f<h)return!1;let u=l-c,d=f-h;return u<d?u:d}calculateLocalInertia(e,t){let n=new R,i=new R;this.computeLocalAABB(i,n);let s=n.x-i.x,o=n.y-i.y,a=n.z-i.z;t.x=1/12*e*(2*o*2*o+2*a*2*a),t.y=1/12*e*(2*s*2*s+2*a*2*a),t.z=1/12*e*(2*o*2*o+2*s*2*s)}getPlaneConstantOfFace(e){let t=this.faces[e],n=this.faceNormals[e],i=this.vertices[t[0]];return-n.dot(i)}clipFaceAgainstHull(e,t,n,i,s,o,a){let l=new R,h=new R,f=new R,c=new R,u=new R,d=new R,p=new R,v=new R,g=this,m=[],_=i,x=m,y=-1,S=Number.MAX_VALUE;for(let w=0;w<g.faces.length;w++){l.copy(g.faceNormals[w]),n.vmult(l,l);let T=l.dot(e);T<S&&(S=T,y=w)}if(y<0)return;let M=g.faces[y];M.connectedFaces=[];for(let w=0;w<g.faces.length;w++)for(let T=0;T<g.faces[w].length;T++)M.indexOf(g.faces[w][T])!==-1&&w!==y&&M.connectedFaces.indexOf(w)===-1&&M.connectedFaces.push(w);let E=M.length;for(let w=0;w<E;w++){let T=g.vertices[M[w]],F=g.vertices[M[(w+1)%E]];T.vsub(F,h),f.copy(h),n.vmult(f,f),t.vadd(f,f),c.copy(this.faceNormals[y]),n.vmult(c,c),t.vadd(c,c),f.cross(c,u),u.negate(u),d.copy(T),n.vmult(d,d),t.vadd(d,d);let D=M.connectedFaces[w];p.copy(this.faceNormals[D]);let C=this.getPlaneConstantOfFace(D);v.copy(p),n.vmult(v,v);let P=C-v.dot(t);for(this.clipFaceAgainstPlane(_,x,v,P);_.length;)_.shift();for(;x.length;)_.push(x.shift())}p.copy(this.faceNormals[y]);let A=this.getPlaneConstantOfFace(y);v.copy(p),n.vmult(v,v);let b=A-v.dot(t);for(let w=0;w<_.length;w++){let T=v.dot(_[w])+b;if(T<=s&&(console.log(`clamped: depth=${T} to minDist=${s}`),T=s),T<=o){let F=_[w];if(T<=1e-6){let D={point:F,normal:v,depth:T};a.push(D)}}}}clipFaceAgainstPlane(e,t,n,i){let s,o,a=e.length;if(a<2)return t;let l=e[e.length-1],h=e[0];s=n.dot(l)+i;for(let f=0;f<a;f++){if(h=e[f],o=n.dot(h)+i,s<0)if(o<0){let c=new R;c.copy(h),t.push(c)}else{let c=new R;l.lerp(h,s/(s-o),c),t.push(c)}else if(o<0){let c=new R;l.lerp(h,s/(s-o),c),t.push(c),t.push(h)}l=h,s=o}return t}computeWorldVertices(e,t){for(;this.worldVertices.length<this.vertices.length;)this.worldVertices.push(new R);let n=this.vertices,i=this.worldVertices;for(let s=0;s!==this.vertices.length;s++)t.vmult(n[s],i[s]),e.vadd(i[s],i[s]);this.worldVerticesNeedsUpdate=!1}computeLocalAABB(e,t){let n=this.vertices;e.set(Number.MAX_VALUE,Number.MAX_VALUE,Number.MAX_VALUE),t.set(-Number.MAX_VALUE,-Number.MAX_VALUE,-Number.MAX_VALUE);for(let i=0;i<this.vertices.length;i++){let s=n[i];s.x<e.x?e.x=s.x:s.x>t.x&&(t.x=s.x),s.y<e.y?e.y=s.y:s.y>t.y&&(t.y=s.y),s.z<e.z?e.z=s.z:s.z>t.z&&(t.z=s.z)}}computeWorldFaceNormals(e){let t=this.faceNormals.length;for(;this.worldFaceNormals.length<t;)this.worldFaceNormals.push(new R);let n=this.faceNormals,i=this.worldFaceNormals;for(let s=0;s!==t;s++)e.vmult(n[s],i[s]);this.worldFaceNormalsNeedsUpdate=!1}updateBoundingSphereRadius(){let e=0,t=this.vertices;for(let n=0;n!==t.length;n++){let i=t[n].lengthSquared();i>e&&(e=i)}this.boundingSphereRadius=Math.sqrt(e)}calculateWorldAABB(e,t,n,i){let s=this.vertices,o,a,l,h,f,c,u=new R;for(let d=0;d<s.length;d++){u.copy(s[d]),t.vmult(u,u),e.vadd(u,u);let p=u;(o===void 0||p.x<o)&&(o=p.x),(h===void 0||p.x>h)&&(h=p.x),(a===void 0||p.y<a)&&(a=p.y),(f===void 0||p.y>f)&&(f=p.y),(l===void 0||p.z<l)&&(l=p.z),(c===void 0||p.z>c)&&(c=p.z)}n.set(o,a,l),i.set(h,f,c)}volume(){return 4*Math.PI*this.boundingSphereRadius/3}getAveragePointLocal(e){e===void 0&&(e=new R);let t=this.vertices;for(let n=0;n<t.length;n++)e.vadd(t[n],e);return e.scale(1/t.length,e),e}transformAllPoints(e,t){let n=this.vertices.length,i=this.vertices;if(t){for(let s=0;s<n;s++){let o=i[s];t.vmult(o,o)}for(let s=0;s<this.faceNormals.length;s++){let o=this.faceNormals[s];t.vmult(o,o)}}if(e)for(let s=0;s<n;s++){let o=i[s];o.vadd(e,o)}}pointIsInside(e){let t=this.vertices,n=this.faces,i=this.faceNormals,s=null,o=new R;this.getAveragePointLocal(o);for(let a=0;a<this.faces.length;a++){let l=i[a],h=t[n[a][0]],f=new R;e.vsub(h,f);let c=l.dot(f),u=new R;o.vsub(h,u);let d=l.dot(u);if(c<0&&d>0||c>0&&d<0)return!1}return s?1:-1}static project(e,t,n,i,s){let o=e.vertices.length,a=xx,l=0,h=0,f=yx,c=e.vertices;f.setZero(),ut.vectorToLocalFrame(n,i,t,a),ut.pointToLocalFrame(n,i,f,f);let u=f.dot(a);h=l=c[0].dot(a);for(let d=1;d<o;d++){let p=c[d].dot(a);p>l&&(l=p),p<h&&(h=p)}if(h-=u,l-=u,h>l){let d=h;h=l,l=d}s[0]=l,s[1]=h}},Eh=[],Ah=[],vx=new R,xx=new R,yx=new R,On=class r extends Te{constructor(e){super({type:Te.types.BOX}),this.halfExtents=e,this.convexPolyhedronRepresentation=null,this.updateConvexPolyhedronRepresentation(),this.updateBoundingSphereRadius()}updateConvexPolyhedronRepresentation(){let e=this.halfExtents.x,t=this.halfExtents.y,n=this.halfExtents.z,i=R,s=[new i(-e,-t,-n),new i(e,-t,-n),new i(e,t,-n),new i(-e,t,-n),new i(-e,-t,n),new i(e,-t,n),new i(e,t,n),new i(-e,t,n)],o=[[3,2,1,0],[4,5,6,7],[5,4,0,1],[2,3,7,6],[0,4,7,3],[1,2,6,5]],a=[new i(0,0,1),new i(0,1,0),new i(1,0,0)],l=new Rl({vertices:s,faces:o,axes:a});this.convexPolyhedronRepresentation=l,l.material=this.material}calculateLocalInertia(e,t){return t===void 0&&(t=new R),r.calculateInertia(this.halfExtents,e,t),t}static calculateInertia(e,t,n){let i=e;n.x=1/12*t*(2*i.y*2*i.y+2*i.z*2*i.z),n.y=1/12*t*(2*i.x*2*i.x+2*i.z*2*i.z),n.z=1/12*t*(2*i.y*2*i.y+2*i.x*2*i.x)}getSideNormals(e,t){let n=e,i=this.halfExtents;if(n[0].set(i.x,0,0),n[1].set(0,i.y,0),n[2].set(0,0,i.z),n[3].set(-i.x,0,0),n[4].set(0,-i.y,0),n[5].set(0,0,-i.z),t!==void 0)for(let s=0;s!==n.length;s++)t.vmult(n[s],n[s]);return n}volume(){return 8*this.halfExtents.x*this.halfExtents.y*this.halfExtents.z}updateBoundingSphereRadius(){this.boundingSphereRadius=this.halfExtents.length()}forEachWorldCorner(e,t,n){let i=this.halfExtents,s=[[i.x,i.y,i.z],[-i.x,i.y,i.z],[-i.x,-i.y,i.z],[-i.x,-i.y,-i.z],[i.x,-i.y,-i.z],[i.x,i.y,-i.z],[-i.x,i.y,-i.z],[i.x,-i.y,i.z]];for(let o=0;o<s.length;o++)es.set(s[o][0],s[o][1],s[o][2]),t.vmult(es,es),e.vadd(es,es),n(es.x,es.y,es.z)}calculateWorldAABB(e,t,n,i){let s=this.halfExtents;ui[0].set(s.x,s.y,s.z),ui[1].set(-s.x,s.y,s.z),ui[2].set(-s.x,-s.y,s.z),ui[3].set(-s.x,-s.y,-s.z),ui[4].set(s.x,-s.y,-s.z),ui[5].set(s.x,s.y,-s.z),ui[6].set(-s.x,s.y,-s.z),ui[7].set(s.x,-s.y,s.z);let o=ui[0];t.vmult(o,o),e.vadd(o,o),i.copy(o),n.copy(o);for(let a=1;a<8;a++){let l=ui[a];t.vmult(l,l),e.vadd(l,l);let h=l.x,f=l.y,c=l.z;h>i.x&&(i.x=h),f>i.y&&(i.y=f),c>i.z&&(i.z=c),h<n.x&&(n.x=h),f<n.y&&(n.y=f),c<n.z&&(n.z=c)}}},es=new R,ui=[new R,new R,new R,new R,new R,new R,new R,new R],kh={DYNAMIC:1,STATIC:2,KINEMATIC:4},Vh={AWAKE:0,SLEEPY:1,SLEEPING:2},Xe=class r extends Cl{constructor(e){e===void 0&&(e={}),super(),this.id=r.idCounter++,this.index=-1,this.world=null,this.vlambda=new R,this.collisionFilterGroup=typeof e.collisionFilterGroup=="number"?e.collisionFilterGroup:1,this.collisionFilterMask=typeof e.collisionFilterMask=="number"?e.collisionFilterMask:-1,this.collisionResponse=typeof e.collisionResponse=="boolean"?e.collisionResponse:!0,this.position=new R,this.previousPosition=new R,this.interpolatedPosition=new R,this.initPosition=new R,e.position&&(this.position.copy(e.position),this.previousPosition.copy(e.position),this.interpolatedPosition.copy(e.position),this.initPosition.copy(e.position)),this.velocity=new R,e.velocity&&this.velocity.copy(e.velocity),this.initVelocity=new R,this.force=new R;let t=typeof e.mass=="number"?e.mass:0;this.mass=t,this.invMass=t>0?1/t:0,this.material=e.material||null,this.linearDamping=typeof e.linearDamping=="number"?e.linearDamping:.01,this.type=t<=0?r.STATIC:r.DYNAMIC,typeof e.type==typeof r.STATIC&&(this.type=e.type),this.allowSleep=typeof e.allowSleep<"u"?e.allowSleep:!0,this.sleepState=r.AWAKE,this.sleepSpeedLimit=typeof e.sleepSpeedLimit<"u"?e.sleepSpeedLimit:.1,this.sleepTimeLimit=typeof e.sleepTimeLimit<"u"?e.sleepTimeLimit:1,this.timeLastSleepy=0,this.wakeUpAfterNarrowphase=!1,this.torque=new R,this.quaternion=new Pt,this.initQuaternion=new Pt,this.previousQuaternion=new Pt,this.interpolatedQuaternion=new Pt,e.quaternion&&(this.quaternion.copy(e.quaternion),this.initQuaternion.copy(e.quaternion),this.previousQuaternion.copy(e.quaternion),this.interpolatedQuaternion.copy(e.quaternion)),this.angularVelocity=new R,e.angularVelocity&&this.angularVelocity.copy(e.angularVelocity),this.initAngularVelocity=new R,this.shapes=[],this.shapeOffsets=[],this.shapeOrientations=[],this.inertia=new R,this.invInertia=new R,this.invInertiaWorld=new ts,this.invMassSolve=0,this.invInertiaSolve=new R,this.invInertiaWorldSolve=new ts,this.fixedRotation=typeof e.fixedRotation<"u"?e.fixedRotation:!1,this.angularDamping=typeof e.angularDamping<"u"?e.angularDamping:.01,this.linearFactor=new R(1,1,1),e.linearFactor&&this.linearFactor.copy(e.linearFactor),this.angularFactor=new R(1,1,1),e.angularFactor&&this.angularFactor.copy(e.angularFactor),this.aabb=new wn,this.aabbNeedsUpdate=!0,this.boundingRadius=0,this.wlambda=new R,this.isTrigger=!!e.isTrigger,e.shape&&this.addShape(e.shape),this.updateMassProperties()}wakeUp(){let e=this.sleepState;this.sleepState=r.AWAKE,this.wakeUpAfterNarrowphase=!1,e===r.SLEEPING&&this.dispatchEvent(r.wakeupEvent)}sleep(){this.sleepState=r.SLEEPING,this.velocity.set(0,0,0),this.angularVelocity.set(0,0,0),this.wakeUpAfterNarrowphase=!1}sleepTick(e){if(this.allowSleep){let t=this.sleepState,n=this.velocity.lengthSquared()+this.angularVelocity.lengthSquared(),i=this.sleepSpeedLimit**2;t===r.AWAKE&&n<i?(this.sleepState=r.SLEEPY,this.timeLastSleepy=e,this.dispatchEvent(r.sleepyEvent)):t===r.SLEEPY&&n>i?this.wakeUp():t===r.SLEEPY&&e-this.timeLastSleepy>this.sleepTimeLimit&&(this.sleep(),this.dispatchEvent(r.sleepEvent))}}updateSolveMassProperties(){this.sleepState===r.SLEEPING||this.type===r.KINEMATIC?(this.invMassSolve=0,this.invInertiaSolve.setZero(),this.invInertiaWorldSolve.setZero()):(this.invMassSolve=this.invMass,this.invInertiaSolve.copy(this.invInertia),this.invInertiaWorldSolve.copy(this.invInertiaWorld))}pointToLocalFrame(e,t){return t===void 0&&(t=new R),e.vsub(this.position,t),this.quaternion.conjugate().vmult(t,t),t}vectorToLocalFrame(e,t){return t===void 0&&(t=new R),this.quaternion.conjugate().vmult(e,t),t}pointToWorldFrame(e,t){return t===void 0&&(t=new R),this.quaternion.vmult(e,t),t.vadd(this.position,t),t}vectorToWorldFrame(e,t){return t===void 0&&(t=new R),this.quaternion.vmult(e,t),t}addShape(e,t,n){let i=new R,s=new Pt;return t&&i.copy(t),n&&s.copy(n),this.shapes.push(e),this.shapeOffsets.push(i),this.shapeOrientations.push(s),this.updateMassProperties(),this.updateBoundingRadius(),this.aabbNeedsUpdate=!0,e.body=this,this}removeShape(e){let t=this.shapes.indexOf(e);return t===-1?(console.warn("Shape does not belong to the body"),this):(this.shapes.splice(t,1),this.shapeOffsets.splice(t,1),this.shapeOrientations.splice(t,1),this.updateMassProperties(),this.updateBoundingRadius(),this.aabbNeedsUpdate=!0,e.body=null,this)}updateBoundingRadius(){let e=this.shapes,t=this.shapeOffsets,n=e.length,i=0;for(let s=0;s!==n;s++){let o=e[s];o.updateBoundingSphereRadius();let a=t[s].length(),l=o.boundingSphereRadius;a+l>i&&(i=a+l)}this.boundingRadius=i}updateAABB(){let e=this.shapes,t=this.shapeOffsets,n=this.shapeOrientations,i=e.length,s=_x,o=Mx,a=this.quaternion,l=this.aabb,h=Sx;for(let f=0;f!==i;f++){let c=e[f];a.vmult(t[f],s),s.vadd(this.position,s),a.mult(n[f],o),c.calculateWorldAABB(s,o,h.lowerBound,h.upperBound),f===0?l.copy(h):l.extend(h)}this.aabbNeedsUpdate=!1}updateInertiaWorld(e){let t=this.invInertia;if(!(t.x===t.y&&t.y===t.z&&!e)){let n=bx,i=wx;n.setRotationFromQuaternion(this.quaternion),n.transpose(i),n.scale(t,n),n.mmult(i,this.invInertiaWorld)}}applyForce(e,t){if(t===void 0&&(t=new R),this.type!==r.DYNAMIC)return;this.sleepState===r.SLEEPING&&this.wakeUp();let n=Ax;t.cross(e,n),this.force.vadd(e,this.force),this.torque.vadd(n,this.torque)}applyLocalForce(e,t){if(t===void 0&&(t=new R),this.type!==r.DYNAMIC)return;let n=Tx,i=Cx;this.vectorToWorldFrame(e,n),this.vectorToWorldFrame(t,i),this.applyForce(n,i)}applyTorque(e){this.type===r.DYNAMIC&&(this.sleepState===r.SLEEPING&&this.wakeUp(),this.torque.vadd(e,this.torque))}applyImpulse(e,t){if(t===void 0&&(t=new R),this.type!==r.DYNAMIC)return;this.sleepState===r.SLEEPING&&this.wakeUp();let n=t,i=Rx;i.copy(e),i.scale(this.invMass,i),this.velocity.vadd(i,this.velocity);let s=Px;n.cross(e,s),this.invInertiaWorld.vmult(s,s),this.angularVelocity.vadd(s,this.angularVelocity)}applyLocalImpulse(e,t){if(t===void 0&&(t=new R),this.type!==r.DYNAMIC)return;let n=Ix,i=Nx;this.vectorToWorldFrame(e,n),this.vectorToWorldFrame(t,i),this.applyImpulse(n,i)}updateMassProperties(){let e=Lx;this.invMass=this.mass>0?1/this.mass:0;let t=this.inertia,n=this.fixedRotation;this.updateAABB(),e.set((this.aabb.upperBound.x-this.aabb.lowerBound.x)/2,(this.aabb.upperBound.y-this.aabb.lowerBound.y)/2,(this.aabb.upperBound.z-this.aabb.lowerBound.z)/2),On.calculateInertia(e,this.mass,t),this.invInertia.set(t.x>0&&!n?1/t.x:0,t.y>0&&!n?1/t.y:0,t.z>0&&!n?1/t.z:0),this.updateInertiaWorld(!0)}getVelocityAtWorldPoint(e,t){let n=new R;return e.vsub(this.position,n),this.angularVelocity.cross(n,t),this.velocity.vadd(t,t),t}integrate(e,t,n){if(this.previousPosition.copy(this.position),this.previousQuaternion.copy(this.quaternion),!(this.type===r.DYNAMIC||this.type===r.KINEMATIC)||this.sleepState===r.SLEEPING)return;let i=this.velocity,s=this.angularVelocity,o=this.position,a=this.force,l=this.torque,h=this.quaternion,f=this.invMass,c=this.invInertiaWorld,u=this.linearFactor,d=f*e;i.x+=a.x*d*u.x,i.y+=a.y*d*u.y,i.z+=a.z*d*u.z;let p=c.elements,v=this.angularFactor,g=l.x*v.x,m=l.y*v.y,_=l.z*v.z;s.x+=e*(p[0]*g+p[1]*m+p[2]*_),s.y+=e*(p[3]*g+p[4]*m+p[5]*_),s.z+=e*(p[6]*g+p[7]*m+p[8]*_),o.x+=i.x*e,o.y+=i.y*e,o.z+=i.z*e,h.integrate(this.angularVelocity,e,this.angularFactor,h),t&&(n?h.normalizeFast():h.normalize()),this.aabbNeedsUpdate=!0,this.updateInertiaWorld()}};Xe.idCounter=0;Xe.COLLIDE_EVENT_NAME="collide";Xe.DYNAMIC=kh.DYNAMIC;Xe.STATIC=kh.STATIC;Xe.KINEMATIC=kh.KINEMATIC;Xe.AWAKE=Vh.AWAKE;Xe.SLEEPY=Vh.SLEEPY;Xe.SLEEPING=Vh.SLEEPING;Xe.wakeupEvent={type:"wakeup"};Xe.sleepyEvent={type:"sleepy"};Xe.sleepEvent={type:"sleep"};var _x=new R,Mx=new Pt,Sx=new wn,bx=new ts,wx=new ts,Ex=new ts,Ax=new R,Tx=new R,Cx=new R,Rx=new R,Px=new R,Ix=new R,Nx=new R,Lx=new R,Pl=class{constructor(){this.world=null,this.useBoundingBoxes=!1,this.dirty=!0}collisionPairs(e,t,n){throw new Error("collisionPairs not implemented for this BroadPhase class!")}needBroadphaseCollision(e,t){return!((e.collisionFilterGroup&t.collisionFilterMask)===0||(t.collisionFilterGroup&e.collisionFilterMask)===0||((e.type&Xe.STATIC)!==0||e.sleepState===Xe.SLEEPING)&&((t.type&Xe.STATIC)!==0||t.sleepState===Xe.SLEEPING))}intersectionTest(e,t,n,i){this.useBoundingBoxes?this.doBoundingBoxBroadphase(e,t,n,i):this.doBoundingSphereBroadphase(e,t,n,i)}doBoundingSphereBroadphase(e,t,n,i){let s=Dx;t.position.vsub(e.position,s);let o=(e.boundingRadius+t.boundingRadius)**2;s.lengthSquared()<o&&(n.push(e),i.push(t))}doBoundingBoxBroadphase(e,t,n,i){e.aabbNeedsUpdate&&e.updateAABB(),t.aabbNeedsUpdate&&t.updateAABB(),e.aabb.overlaps(t.aabb)&&(n.push(e),i.push(t))}makePairsUnique(e,t){let n=Fx,i=Bx,s=Ux,o=e.length;for(let a=0;a!==o;a++)i[a]=e[a],s[a]=t[a];e.length=0,t.length=0;for(let a=0;a!==o;a++){let l=i[a].id,h=s[a].id,f=l<h?`${l},${h}`:`${h},${l}`;n[f]=a,n.keys.push(f)}for(let a=0;a!==n.keys.length;a++){let l=n.keys.pop(),h=n[l];e.push(i[h]),t.push(s[h]),delete n[l]}}setWorld(e){}static boundingSphereCheck(e,t){let n=new R;e.position.vsub(t.position,n);let i=e.shapes[0],s=t.shapes[0];return Math.pow(i.boundingSphereRadius+s.boundingSphereRadius,2)>n.lengthSquared()}aabbQuery(e,t,n){return console.warn(".aabbQuery is not implemented in this Broadphase subclass."),[]}},Dx=new R;new R;new Pt;new R;var Fx={keys:[]},Bx=[],Ux=[];new R;var U1=new R;new R;var Ih=class extends Pl{constructor(){super()}collisionPairs(e,t,n){let i=e.bodies,s=i.length,o,a;for(let l=0;l!==s;l++)for(let h=0;h!==l;h++)o=i[l],a=i[h],this.needBroadphaseCollision(o,a)&&this.intersectionTest(o,a,t,n)}aabbQuery(e,t,n){n===void 0&&(n=[]);for(let i=0;i<e.bodies.length;i++){let s=e.bodies[i];s.aabbNeedsUpdate&&s.updateAABB(),s.aabb.overlaps(t)&&n.push(s)}return n}},gr=class{constructor(){this.rayFromWorld=new R,this.rayToWorld=new R,this.hitNormalWorld=new R,this.hitPointWorld=new R,this.hasHit=!1,this.shape=null,this.body=null,this.hitFaceIndex=-1,this.distance=-1,this.shouldStop=!1}reset(){this.rayFromWorld.setZero(),this.rayToWorld.setZero(),this.hitNormalWorld.setZero(),this.hitPointWorld.setZero(),this.hasHit=!1,this.shape=null,this.body=null,this.hitFaceIndex=-1,this.distance=-1,this.shouldStop=!1}abort(){this.shouldStop=!0}set(e,t,n,i,s,o,a){this.rayFromWorld.copy(e),this.rayToWorld.copy(t),this.hitNormalWorld.copy(n),this.hitPointWorld.copy(i),this.shape=s,this.body=o,this.distance=a}},dd,pd,md,gd,vd,xd,yd,Hh={CLOSEST:1,ANY:2,ALL:4};dd=Te.types.SPHERE;pd=Te.types.PLANE;md=Te.types.BOX;gd=Te.types.CYLINDER;vd=Te.types.CONVEXPOLYHEDRON;xd=Te.types.HEIGHTFIELD;yd=Te.types.TRIMESH;var Un=class r{get[dd](){return this._intersectSphere}get[pd](){return this._intersectPlane}get[md](){return this._intersectBox}get[gd](){return this._intersectConvex}get[vd](){return this._intersectConvex}get[xd](){return this._intersectHeightfield}get[yd](){return this._intersectTrimesh}constructor(e,t){e===void 0&&(e=new R),t===void 0&&(t=new R),this.from=e.clone(),this.to=t.clone(),this.direction=new R,this.precision=1e-4,this.checkCollisionResponse=!0,this.skipBackfaces=!1,this.collisionFilterMask=-1,this.collisionFilterGroup=-1,this.mode=r.ANY,this.result=new gr,this.hasHit=!1,this.callback=n=>{}}intersectWorld(e,t){return this.mode=t.mode||r.ANY,this.result=t.result||new gr,this.skipBackfaces=!!t.skipBackfaces,this.collisionFilterMask=typeof t.collisionFilterMask<"u"?t.collisionFilterMask:-1,this.collisionFilterGroup=typeof t.collisionFilterGroup<"u"?t.collisionFilterGroup:-1,this.checkCollisionResponse=typeof t.checkCollisionResponse<"u"?t.checkCollisionResponse:!0,t.from&&this.from.copy(t.from),t.to&&this.to.copy(t.to),this.callback=t.callback||(()=>{}),this.hasHit=!1,this.result.reset(),this.updateDirection(),this.getAABB(nd),Th.length=0,e.broadphase.aabbQuery(e,nd,Th),this.intersectBodies(Th),this.hasHit}intersectBody(e,t){t&&(this.result=t,this.updateDirection());let n=this.checkCollisionResponse;if(n&&!e.collisionResponse||(this.collisionFilterGroup&e.collisionFilterMask)===0||(e.collisionFilterGroup&this.collisionFilterMask)===0)return;let i=Ox,s=zx;for(let o=0,a=e.shapes.length;o<a;o++){let l=e.shapes[o];if(!(n&&!l.collisionResponse)&&(e.quaternion.mult(e.shapeOrientations[o],s),e.quaternion.vmult(e.shapeOffsets[o],i),i.vadd(e.position,i),this.intersectShape(l,s,i,e),this.result.shouldStop))break}}intersectBodies(e,t){t&&(this.result=t,this.updateDirection());for(let n=0,i=e.length;!this.result.shouldStop&&n<i;n++)this.intersectBody(e[n])}updateDirection(){this.to.vsub(this.from,this.direction),this.direction.normalize()}intersectShape(e,t,n,i){let s=this.from;if(ty(s,this.direction,n)>e.boundingSphereRadius)return;let a=this[e.type];a&&a.call(this,e,t,n,i,e)}_intersectBox(e,t,n,i,s){return this._intersectConvex(e.convexPolyhedronRepresentation,t,n,i,s)}_intersectPlane(e,t,n,i,s){let o=this.from,a=this.to,l=this.direction,h=new R(0,0,1);t.vmult(h,h);let f=new R;o.vsub(n,f);let c=f.dot(h);a.vsub(n,f);let u=f.dot(h);if(c*u>0||o.distanceTo(a)<c)return;let d=h.dot(l);if(Math.abs(d)<this.precision)return;let p=new R,v=new R,g=new R;o.vsub(n,p);let m=-h.dot(p)/d;l.scale(m,v),o.vadd(v,g),this.reportIntersection(h,g,s,i,-1)}getAABB(e){let{lowerBound:t,upperBound:n}=e,i=this.to,s=this.from;t.x=Math.min(i.x,s.x),t.y=Math.min(i.y,s.y),t.z=Math.min(i.z,s.z),n.x=Math.max(i.x,s.x),n.y=Math.max(i.y,s.y),n.z=Math.max(i.z,s.z)}_intersectHeightfield(e,t,n,i,s){e.data,e.elementSize;let o=kx;o.from.copy(this.from),o.to.copy(this.to),ut.pointToLocalFrame(n,t,o.from,o.from),ut.pointToLocalFrame(n,t,o.to,o.to),o.updateDirection();let a=Vx,l,h,f,c;l=h=0,f=c=e.data.length-1;let u=new wn;o.getAABB(u),e.getIndexOfPosition(u.lowerBound.x,u.lowerBound.y,a,!0),l=Math.max(l,a[0]),h=Math.max(h,a[1]),e.getIndexOfPosition(u.upperBound.x,u.upperBound.y,a,!0),f=Math.min(f,a[0]+1),c=Math.min(c,a[1]+1);for(let d=l;d<f;d++)for(let p=h;p<c;p++){if(this.result.shouldStop)return;if(e.getAabbAtIndex(d,p,u),!!u.overlapsRay(o)){if(e.getConvexTrianglePillar(d,p,!1),ut.pointToWorldFrame(n,t,e.pillarOffset,Sl),this._intersectConvex(e.pillarConvex,t,Sl,i,s,id),this.result.shouldStop)return;e.getConvexTrianglePillar(d,p,!0),ut.pointToWorldFrame(n,t,e.pillarOffset,Sl),this._intersectConvex(e.pillarConvex,t,Sl,i,s,id)}}}_intersectSphere(e,t,n,i,s){let o=this.from,a=this.to,l=e.radius,h=(a.x-o.x)**2+(a.y-o.y)**2+(a.z-o.z)**2,f=2*((a.x-o.x)*(o.x-n.x)+(a.y-o.y)*(o.y-n.y)+(a.z-o.z)*(o.z-n.z)),c=(o.x-n.x)**2+(o.y-n.y)**2+(o.z-n.z)**2-l**2,u=f**2-4*h*c,d=Hx,p=Gx;if(!(u<0))if(u===0)o.lerp(a,u,d),d.vsub(n,p),p.normalize(),this.reportIntersection(p,d,s,i,-1);else{let v=(-f-Math.sqrt(u))/(2*h),g=(-f+Math.sqrt(u))/(2*h);if(v>=0&&v<=1&&(o.lerp(a,v,d),d.vsub(n,p),p.normalize(),this.reportIntersection(p,d,s,i,-1)),this.result.shouldStop)return;g>=0&&g<=1&&(o.lerp(a,g,d),d.vsub(n,p),p.normalize(),this.reportIntersection(p,d,s,i,-1))}}_intersectConvex(e,t,n,i,s,o){let a=Wx,l=sd,h=o&&o.faceList||null,f=e.faces,c=e.vertices,u=e.faceNormals,d=this.direction,p=this.from,v=this.to,g=p.distanceTo(v),m=h?h.length:f.length,_=this.result;for(let x=0;!_.shouldStop&&x<m;x++){let y=h?h[x]:x,S=f[y],M=u[y],E=t,A=n;l.copy(c[S[0]]),E.vmult(l,l),l.vadd(A,l),l.vsub(p,l),E.vmult(M,a);let b=d.dot(a);if(Math.abs(b)<this.precision)continue;let w=a.dot(l)/b;if(!(w<0)){d.scale(w,dn),dn.vadd(p,dn),jn.copy(c[S[0]]),E.vmult(jn,jn),A.vadd(jn,jn);for(let T=1;!_.shouldStop&&T<S.length-1;T++){fi.copy(c[S[T]]),di.copy(c[S[T+1]]),E.vmult(fi,fi),E.vmult(di,di),A.vadd(fi,fi),A.vadd(di,di);let F=dn.distanceTo(p);!(r.pointInTriangle(dn,jn,fi,di)||r.pointInTriangle(dn,fi,jn,di))||F>g||this.reportIntersection(a,dn,s,i,y)}}}}_intersectTrimesh(e,t,n,i,s,o){let a=$x,l=Qx,h=ey,f=sd,c=Yx,u=Zx,d=Kx,p=jx,v=Jx,g=e.indices;e.vertices;let m=this.from,_=this.to,x=this.direction;h.position.copy(n),h.quaternion.copy(t),ut.vectorToLocalFrame(n,t,x,c),ut.pointToLocalFrame(n,t,m,u),ut.pointToLocalFrame(n,t,_,d),d.x*=e.scale.x,d.y*=e.scale.y,d.z*=e.scale.z,u.x*=e.scale.x,u.y*=e.scale.y,u.z*=e.scale.z,d.vsub(u,c),c.normalize();let y=u.distanceSquared(d);e.tree.rayQuery(this,h,l);for(let S=0,M=l.length;!this.result.shouldStop&&S!==M;S++){let E=l[S];e.getNormal(E,a),e.getVertex(g[E*3],jn),jn.vsub(u,f);let A=c.dot(a),b=a.dot(f)/A;if(b<0)continue;c.scale(b,dn),dn.vadd(u,dn),e.getVertex(g[E*3+1],fi),e.getVertex(g[E*3+2],di);let w=dn.distanceSquared(u);!(r.pointInTriangle(dn,fi,jn,di)||r.pointInTriangle(dn,jn,fi,di))||w>y||(ut.vectorToWorldFrame(t,a,v),ut.pointToWorldFrame(n,t,dn,p),this.reportIntersection(v,p,s,i,E))}l.length=0}reportIntersection(e,t,n,i,s){let o=this.from,a=this.to,l=o.distanceTo(t),h=this.result;if(!(this.skipBackfaces&&e.dot(this.direction)>0))switch(h.hitFaceIndex=typeof s<"u"?s:-1,this.mode){case r.ALL:this.hasHit=!0,h.set(o,a,e,t,n,i,l),h.hasHit=!0,this.callback(h);break;case r.CLOSEST:(l<h.distance||!h.hasHit)&&(this.hasHit=!0,h.hasHit=!0,h.set(o,a,e,t,n,i,l));break;case r.ANY:this.hasHit=!0,h.hasHit=!0,h.set(o,a,e,t,n,i,l),h.shouldStop=!0;break}}static pointInTriangle(e,t,n,i){i.vsub(t,Rs),n.vsub(t,uo),e.vsub(t,Ch);let s=Rs.dot(Rs),o=Rs.dot(uo),a=Rs.dot(Ch),l=uo.dot(uo),h=uo.dot(Ch),f,c;return(f=l*a-o*h)>=0&&(c=s*h-o*a)>=0&&f+c<s*l-o*o}};Un.CLOSEST=Hh.CLOSEST;Un.ANY=Hh.ANY;Un.ALL=Hh.ALL;var nd=new wn,Th=[],uo=new R,Ch=new R,Ox=new R,zx=new Pt,dn=new R,jn=new R,fi=new R,di=new R;new R;new gr;var id={faceList:[0]},Sl=new R,kx=new Un,Vx=[],Hx=new R,Gx=new R,Wx=new R,qx=new R,Xx=new R,sd=new R,$x=new R,Yx=new R,Zx=new R,Kx=new R,Jx=new R,jx=new R;new wn;var Qx=[],ey=new ut,Rs=new R,bl=new R;function ty(r,e,t){t.vsub(r,Rs);let n=Rs.dot(e);return e.scale(n,bl),bl.vadd(r,bl),t.distanceTo(bl)}var ns=class r extends Pl{static checkBounds(e,t,n){let i,s;n===0?(i=e.position.x,s=t.position.x):n===1?(i=e.position.y,s=t.position.y):n===2&&(i=e.position.z,s=t.position.z);let o=e.boundingRadius,a=t.boundingRadius,l=i+o;return s-a<l}static insertionSortX(e){for(let t=1,n=e.length;t<n;t++){let i=e[t],s;for(s=t-1;s>=0&&!(e[s].aabb.lowerBound.x<=i.aabb.lowerBound.x);s--)e[s+1]=e[s];e[s+1]=i}return e}static insertionSortY(e){for(let t=1,n=e.length;t<n;t++){let i=e[t],s;for(s=t-1;s>=0&&!(e[s].aabb.lowerBound.y<=i.aabb.lowerBound.y);s--)e[s+1]=e[s];e[s+1]=i}return e}static insertionSortZ(e){for(let t=1,n=e.length;t<n;t++){let i=e[t],s;for(s=t-1;s>=0&&!(e[s].aabb.lowerBound.z<=i.aabb.lowerBound.z);s--)e[s+1]=e[s];e[s+1]=i}return e}constructor(e){super(),this.axisList=[],this.world=null,this.axisIndex=0;let t=this.axisList;this._addBodyHandler=n=>{t.push(n.body)},this._removeBodyHandler=n=>{let i=t.indexOf(n.body);i!==-1&&t.splice(i,1)},e&&this.setWorld(e)}setWorld(e){this.axisList.length=0;for(let t=0;t<e.bodies.length;t++)this.axisList.push(e.bodies[t]);e.removeEventListener("addBody",this._addBodyHandler),e.removeEventListener("removeBody",this._removeBodyHandler),e.addEventListener("addBody",this._addBodyHandler),e.addEventListener("removeBody",this._removeBodyHandler),this.world=e,this.dirty=!0}collisionPairs(e,t,n){let i=this.axisList,s=i.length,o=this.axisIndex,a,l;for(this.dirty&&(this.sortList(),this.dirty=!1),a=0;a!==s;a++){let h=i[a];for(l=a+1;l<s;l++){let f=i[l];if(this.needBroadphaseCollision(h,f)){if(!r.checkBounds(h,f,o))break;this.intersectionTest(h,f,t,n)}}}}sortList(){let e=this.axisList,t=this.axisIndex,n=e.length;for(let i=0;i!==n;i++){let s=e[i];s.aabbNeedsUpdate&&s.updateAABB()}t===0?r.insertionSortX(e):t===1?r.insertionSortY(e):t===2&&r.insertionSortZ(e)}autoDetectAxis(){let e=0,t=0,n=0,i=0,s=0,o=0,a=this.axisList,l=a.length,h=1/l;for(let d=0;d!==l;d++){let p=a[d],v=p.position.x;e+=v,t+=v*v;let g=p.position.y;n+=g,i+=g*g;let m=p.position.z;s+=m,o+=m*m}let f=t-e*e*h,c=i-n*n*h,u=o-s*s*h;f>c?f>u?this.axisIndex=0:this.axisIndex=2:c>u?this.axisIndex=1:this.axisIndex=2}aabbQuery(e,t,n){n===void 0&&(n=[]),this.dirty&&(this.sortList(),this.dirty=!1);let i=this.axisIndex,s="x";i===1&&(s="y"),i===2&&(s="z");let o=this.axisList;t.lowerBound[s],t.upperBound[s];for(let a=0;a<o.length;a++){let l=o[a];l.aabbNeedsUpdate&&l.updateAABB(),l.aabb.overlaps(t)&&n.push(l)}return n}},Il=class{static defaults(e,t){e===void 0&&(e={});for(let n in t)n in e||(e[n]=t[n]);return e}},Nh=class r{constructor(e,t,n){n===void 0&&(n={}),n=Il.defaults(n,{collideConnected:!0,wakeUpBodies:!0}),this.equations=[],this.bodyA=e,this.bodyB=t,this.id=r.idCounter++,this.collideConnected=n.collideConnected,n.wakeUpBodies&&(e&&e.wakeUp(),t&&t.wakeUp())}update(){throw new Error("method update() not implmemented in this Constraint subclass!")}enable(){let e=this.equations;for(let t=0;t<e.length;t++)e[t].enabled=!0}disable(){let e=this.equations;for(let t=0;t<e.length;t++)e[t].enabled=!1}};Nh.idCounter=0;var Nl=class{constructor(){this.spatial=new R,this.rotational=new R}multiplyElement(e){return e.spatial.dot(this.spatial)+e.rotational.dot(this.rotational)}multiplyVectors(e,t){return e.dot(this.spatial)+t.dot(this.rotational)}},go=class r{constructor(e,t,n,i){n===void 0&&(n=-1e6),i===void 0&&(i=1e6),this.id=r.idCounter++,this.minForce=n,this.maxForce=i,this.bi=e,this.bj=t,this.a=0,this.b=0,this.eps=0,this.jacobianElementA=new Nl,this.jacobianElementB=new Nl,this.enabled=!0,this.multiplier=0,this.setSpookParams(1e7,4,1/60)}setSpookParams(e,t,n){let i=t,s=e,o=n;this.a=4/(o*(1+4*i)),this.b=4*i/(1+4*i),this.eps=4/(o*o*s*(1+4*i))}computeB(e,t,n){let i=this.computeGW(),s=this.computeGq(),o=this.computeGiMf();return-s*e-i*t-o*n}computeGq(){let e=this.jacobianElementA,t=this.jacobianElementB,n=this.bi,i=this.bj,s=n.position,o=i.position;return e.spatial.dot(s)+t.spatial.dot(o)}computeGW(){let e=this.jacobianElementA,t=this.jacobianElementB,n=this.bi,i=this.bj,s=n.velocity,o=i.velocity,a=n.angularVelocity,l=i.angularVelocity;return e.multiplyVectors(s,a)+t.multiplyVectors(o,l)}computeGWlambda(){let e=this.jacobianElementA,t=this.jacobianElementB,n=this.bi,i=this.bj,s=n.vlambda,o=i.vlambda,a=n.wlambda,l=i.wlambda;return e.multiplyVectors(s,a)+t.multiplyVectors(o,l)}computeGiMf(){let e=this.jacobianElementA,t=this.jacobianElementB,n=this.bi,i=this.bj,s=n.force,o=n.torque,a=i.force,l=i.torque,h=n.invMassSolve,f=i.invMassSolve;return s.scale(h,rd),a.scale(f,od),n.invInertiaWorldSolve.vmult(o,ad),i.invInertiaWorldSolve.vmult(l,ld),e.multiplyVectors(rd,ad)+t.multiplyVectors(od,ld)}computeGiMGt(){let e=this.jacobianElementA,t=this.jacobianElementB,n=this.bi,i=this.bj,s=n.invMassSolve,o=i.invMassSolve,a=n.invInertiaWorldSolve,l=i.invInertiaWorldSolve,h=s+o;return a.vmult(e.rotational,wl),h+=wl.dot(e.rotational),l.vmult(t.rotational,wl),h+=wl.dot(t.rotational),h}addToWlambda(e){let t=this.jacobianElementA,n=this.jacobianElementB,i=this.bi,s=this.bj,o=ny;i.vlambda.addScaledVector(i.invMassSolve*e,t.spatial,i.vlambda),s.vlambda.addScaledVector(s.invMassSolve*e,n.spatial,s.vlambda),i.invInertiaWorldSolve.vmult(t.rotational,o),i.wlambda.addScaledVector(e,o,i.wlambda),s.invInertiaWorldSolve.vmult(n.rotational,o),s.wlambda.addScaledVector(e,o,s.wlambda)}computeC(){return this.computeGiMGt()+this.eps}};go.idCounter=0;var rd=new R,od=new R,ad=new R,ld=new R,wl=new R,ny=new R,Lh=class extends go{constructor(e,t,n){n===void 0&&(n=1e6),super(e,t,0,n),this.restitution=0,this.ri=new R,this.rj=new R,this.ni=new R}computeB(e){let t=this.a,n=this.b,i=this.bi,s=this.bj,o=this.ri,a=this.rj,l=iy,h=sy,f=i.velocity,c=i.angularVelocity;i.force,i.torque;let u=s.velocity,d=s.angularVelocity;s.force,s.torque;let p=ry,v=this.jacobianElementA,g=this.jacobianElementB,m=this.ni;o.cross(m,l),a.cross(m,h),m.negate(v.spatial),l.negate(v.rotational),g.spatial.copy(m),g.rotational.copy(h),p.copy(s.position),p.vadd(a,p),p.vsub(i.position,p),p.vsub(o,p);let _=m.dot(p),x=this.restitution+1,y=x*u.dot(m)-x*f.dot(m)+d.dot(h)-c.dot(l),S=this.computeGiMf();return-_*t-y*n-e*S}getImpactVelocityAlongNormal(){let e=oy,t=ay,n=ly,i=cy,s=hy;return this.bi.position.vadd(this.ri,n),this.bj.position.vadd(this.rj,i),this.bi.getVelocityAtWorldPoint(n,e),this.bj.getVelocityAtWorldPoint(i,t),e.vsub(t,s),this.ni.dot(s)}},iy=new R,sy=new R,ry=new R,oy=new R,ay=new R,ly=new R,cy=new R,hy=new R;var O1=new R,z1=new R;var k1=new R,V1=new R;new R;new R;var H1=new R,G1=new R;var W1=new R,q1=new R,Ll=class extends go{constructor(e,t,n){super(e,t,-n,n),this.ri=new R,this.rj=new R,this.t=new R}computeB(e){this.a;let t=this.b;this.bi,this.bj;let n=this.ri,i=this.rj,s=uy,o=fy,a=this.t;n.cross(a,s),i.cross(a,o);let l=this.jacobianElementA,h=this.jacobianElementB;a.negate(l.spatial),s.negate(l.rotational),h.spatial.copy(a),h.rotational.copy(o);let f=this.computeGW(),c=this.computeGiMf();return-f*t-e*c}},uy=new R,fy=new R,an=class r{constructor(e,t,n){n=Il.defaults(n,{friction:.3,restitution:.3,contactEquationStiffness:1e7,contactEquationRelaxation:3,frictionEquationStiffness:1e7,frictionEquationRelaxation:3}),this.id=r.idCounter++,this.materials=[e,t],this.friction=n.friction,this.restitution=n.restitution,this.contactEquationStiffness=n.contactEquationStiffness,this.contactEquationRelaxation=n.contactEquationRelaxation,this.frictionEquationStiffness=n.frictionEquationStiffness,this.frictionEquationRelaxation=n.frictionEquationRelaxation}};an.idCounter=0;var kt=class r{constructor(e){e===void 0&&(e={});let t="";typeof e=="string"&&(t=e,e={}),this.name=t,this.id=r.idCounter++,this.friction=typeof e.friction<"u"?e.friction:-1,this.restitution=typeof e.restitution<"u"?e.restitution:-1}};kt.idCounter=0;var X1=new R,$1=new R,Y1=new R,Z1=new R,K1=new R,J1=new R,j1=new R,Q1=new R,ew=new R,tw=new R,nw=new R;var iw=new R,sw=new R;new R;new R;new R;var rw=new R,ow=new R,aw=new R;new Un;new R;var lw=new R,cw=new R,hw=[new R(1,0,0),new R(0,1,0),new R(0,0,1)],uw=new R;var fw=new R,dw=new R,pw=new R;var mw=new R,gw=new R,vw=new R,xw=new R;var yw=new R,_w=new R,Mw=new R;var Qn=class extends Te{constructor(e){if(super({type:Te.types.SPHERE}),this.radius=e!==void 0?e:1,this.radius<0)throw new Error("The sphere radius cannot be negative.");this.updateBoundingSphereRadius()}calculateLocalInertia(e,t){t===void 0&&(t=new R);let n=2*e*this.radius*this.radius/5;return t.x=n,t.y=n,t.z=n,t}volume(){return 4*Math.PI*Math.pow(this.radius,3)/3}updateBoundingSphereRadius(){this.boundingSphereRadius=this.radius}calculateWorldAABB(e,t,n,i){let s=this.radius,o=["x","y","z"];for(let a=0;a<o.length;a++){let l=o[a];n[l]=e[l]-s,i[l]=e[l]+s}}};var Sw=new R,bw=new R;var ww=new R,Ew=new R,Aw=new R,Tw=new R,Cw=new R,Rw=new R,Pw=new R,Dl=class extends Rl{constructor(e,t,n,i){if(e===void 0&&(e=1),t===void 0&&(t=1),n===void 0&&(n=1),i===void 0&&(i=8),e<0)throw new Error("The cylinder radiusTop cannot be negative.");if(t<0)throw new Error("The cylinder radiusBottom cannot be negative.");let s=i,o=[],a=[],l=[],h=[],f=[],c=Math.cos,u=Math.sin;o.push(new R(-t*u(0),-n*.5,t*c(0))),h.push(0),o.push(new R(-e*u(0),n*.5,e*c(0))),f.push(1);for(let p=0;p<s;p++){let v=2*Math.PI/s*(p+1),g=2*Math.PI/s*(p+.5);p<s-1?(o.push(new R(-t*u(v),-n*.5,t*c(v))),h.push(2*p+2),o.push(new R(-e*u(v),n*.5,e*c(v))),f.push(2*p+3),l.push([2*p,2*p+1,2*p+3,2*p+2])):l.push([2*p,2*p+1,1,0]),(s%2===1||p<s/2)&&a.push(new R(-u(g),0,c(g)))}l.push(h),a.push(new R(0,1,0));let d=[];for(let p=0;p<f.length;p++)d.push(f[f.length-p-1]);l.push(d),super({vertices:o,faces:l,axes:a}),this.type=Te.types.CYLINDER,this.radiusTop=e,this.radiusBottom=t,this.height=n,this.numSegments=i}};var Iw=new R;var Nw=new R,Lw=new R,Dw=new R,Fw=new R,Bw=new R,Uw=new R,Ow=new R,zw=new R,kw=new R;var Vw=new R,Hw=new wn;var Gw=new R,Ww=new wn,qw=new R,Xw=new R,$w=new R,Yw=new R,Zw=new R,Kw=new R,Jw=new R,jw=new wn,Qw=new R,eE=new ut,tE=new wn,Dh=class{constructor(){this.equations=[]}solve(e,t){return 0}addEquation(e){e.enabled&&!e.bi.isTrigger&&!e.bj.isTrigger&&this.equations.push(e)}removeEquation(e){let t=this.equations,n=t.indexOf(e);n!==-1&&t.splice(n,1)}removeAllEquations(){this.equations.length=0}},Fh=class extends Dh{constructor(){super(),this.iterations=10,this.tolerance=1e-7}solve(e,t){let n=0,i=this.iterations,s=this.tolerance*this.tolerance,o=this.equations,a=o.length,l=t.bodies,h=l.length,f=e,c,u,d,p,v,g;if(a!==0)for(let y=0;y!==h;y++)l[y].updateSolveMassProperties();let m=py,_=my,x=dy;m.length=a,_.length=a,x.length=a;for(let y=0;y!==a;y++){let S=o[y];x[y]=0,_[y]=S.computeB(f),m[y]=1/S.computeC()}if(a!==0){for(let M=0;M!==h;M++){let E=l[M],A=E.vlambda,b=E.wlambda;A.set(0,0,0),b.set(0,0,0)}for(n=0;n!==i;n++){p=0;for(let M=0;M!==a;M++){let E=o[M];c=_[M],u=m[M],g=x[M],v=E.computeGWlambda(),d=u*(c-v-E.eps*g),g+d<E.minForce?d=E.minForce-g:g+d>E.maxForce&&(d=E.maxForce-g),x[M]+=d,p+=d>0?d:-d,E.addToWlambda(d)}if(p*p<s)break}for(let M=0;M!==h;M++){let E=l[M],A=E.velocity,b=E.angularVelocity;E.vlambda.vmul(E.linearFactor,E.vlambda),A.vadd(E.vlambda,A),E.wlambda.vmul(E.angularFactor,E.wlambda),b.vadd(E.wlambda,b)}let y=o.length,S=1/f;for(;y--;)o[y].multiplier=x[y]*S}return n}},dy=[],py=[],my=[];var nE=Xe.STATIC;var Bh=class{constructor(){this.objects=[],this.type=Object}release(){let e=arguments.length;for(let t=0;t!==e;t++)this.objects.push(t<0||arguments.length<=t?void 0:arguments[t]);return this}get(){return this.objects.length===0?this.constructObject():this.objects.pop()}constructObject(){throw new Error("constructObject() not implemented in this Pool subclass yet!")}resize(e){let t=this.objects;for(;t.length>e;)t.pop();for(;t.length<e;)t.push(this.constructObject());return this}},Uh=class extends Bh{constructor(){super(...arguments),this.type=R}constructObject(){return new R}},xt={sphereSphere:Te.types.SPHERE,spherePlane:Te.types.SPHERE|Te.types.PLANE,boxBox:Te.types.BOX|Te.types.BOX,sphereBox:Te.types.SPHERE|Te.types.BOX,planeBox:Te.types.PLANE|Te.types.BOX,convexConvex:Te.types.CONVEXPOLYHEDRON,sphereConvex:Te.types.SPHERE|Te.types.CONVEXPOLYHEDRON,planeConvex:Te.types.PLANE|Te.types.CONVEXPOLYHEDRON,boxConvex:Te.types.BOX|Te.types.CONVEXPOLYHEDRON,sphereHeightfield:Te.types.SPHERE|Te.types.HEIGHTFIELD,boxHeightfield:Te.types.BOX|Te.types.HEIGHTFIELD,convexHeightfield:Te.types.CONVEXPOLYHEDRON|Te.types.HEIGHTFIELD,sphereParticle:Te.types.PARTICLE|Te.types.SPHERE,planeParticle:Te.types.PLANE|Te.types.PARTICLE,boxParticle:Te.types.BOX|Te.types.PARTICLE,convexParticle:Te.types.PARTICLE|Te.types.CONVEXPOLYHEDRON,cylinderCylinder:Te.types.CYLINDER,sphereCylinder:Te.types.SPHERE|Te.types.CYLINDER,planeCylinder:Te.types.PLANE|Te.types.CYLINDER,boxCylinder:Te.types.BOX|Te.types.CYLINDER,convexCylinder:Te.types.CONVEXPOLYHEDRON|Te.types.CYLINDER,heightfieldCylinder:Te.types.HEIGHTFIELD|Te.types.CYLINDER,particleCylinder:Te.types.PARTICLE|Te.types.CYLINDER,sphereTrimesh:Te.types.SPHERE|Te.types.TRIMESH,planeTrimesh:Te.types.PLANE|Te.types.TRIMESH},Oh=class{get[xt.sphereSphere](){return this.sphereSphere}get[xt.spherePlane](){return this.spherePlane}get[xt.boxBox](){return this.boxBox}get[xt.sphereBox](){return this.sphereBox}get[xt.planeBox](){return this.planeBox}get[xt.convexConvex](){return this.convexConvex}get[xt.sphereConvex](){return this.sphereConvex}get[xt.planeConvex](){return this.planeConvex}get[xt.boxConvex](){return this.boxConvex}get[xt.sphereHeightfield](){return this.sphereHeightfield}get[xt.boxHeightfield](){return this.boxHeightfield}get[xt.convexHeightfield](){return this.convexHeightfield}get[xt.sphereParticle](){return this.sphereParticle}get[xt.planeParticle](){return this.planeParticle}get[xt.boxParticle](){return this.boxParticle}get[xt.convexParticle](){return this.convexParticle}get[xt.cylinderCylinder](){return this.convexConvex}get[xt.sphereCylinder](){return this.sphereConvex}get[xt.planeCylinder](){return this.planeConvex}get[xt.boxCylinder](){return this.boxConvex}get[xt.convexCylinder](){return this.convexConvex}get[xt.heightfieldCylinder](){return this.heightfieldCylinder}get[xt.particleCylinder](){return this.particleCylinder}get[xt.sphereTrimesh](){return this.sphereTrimesh}get[xt.planeTrimesh](){return this.planeTrimesh}constructor(e){this.contactPointPool=[],this.frictionEquationPool=[],this.result=[],this.frictionResult=[],this.v3pool=new Uh,this.world=e,this.currentContactMaterial=e.defaultContactMaterial,this.enableFrictionReduction=!1}createContactEquation(e,t,n,i,s,o){let a;this.contactPointPool.length?(a=this.contactPointPool.pop(),a.bi=e,a.bj=t):a=new Lh(e,t),a.enabled=e.collisionResponse&&t.collisionResponse&&n.collisionResponse&&i.collisionResponse;let l=this.currentContactMaterial;a.restitution=l.restitution,a.setSpookParams(l.contactEquationStiffness,l.contactEquationRelaxation,this.world.dt);let h=n.material||e.material,f=i.material||t.material;return h&&f&&h.restitution>=0&&f.restitution>=0&&(a.restitution=h.restitution*f.restitution),a.si=s||n,a.sj=o||i,a}createFrictionEquationsFromContact(e,t){let n=e.bi,i=e.bj,s=e.si,o=e.sj,a=this.world,l=this.currentContactMaterial,h=l.friction,f=s.material||n.material,c=o.material||i.material;if(f&&c&&f.friction>=0&&c.friction>=0&&(h=f.friction*c.friction),h>0){let u=h*(a.frictionGravity||a.gravity).length(),d=n.invMass+i.invMass;d>0&&(d=1/d);let p=this.frictionEquationPool,v=p.length?p.pop():new Ll(n,i,u*d),g=p.length?p.pop():new Ll(n,i,u*d);return v.bi=g.bi=n,v.bj=g.bj=i,v.minForce=g.minForce=-u*d,v.maxForce=g.maxForce=u*d,v.ri.copy(e.ri),v.rj.copy(e.rj),g.ri.copy(e.ri),g.rj.copy(e.rj),e.ni.tangents(v.t,g.t),v.setSpookParams(l.frictionEquationStiffness,l.frictionEquationRelaxation,a.dt),g.setSpookParams(l.frictionEquationStiffness,l.frictionEquationRelaxation,a.dt),v.enabled=g.enabled=e.enabled,t.push(v,g),!0}return!1}createFrictionFromAverage(e){let t=this.result[this.result.length-1];if(!this.createFrictionEquationsFromContact(t,this.frictionResult)||e===1)return;let n=this.frictionResult[this.frictionResult.length-2],i=this.frictionResult[this.frictionResult.length-1];Cs.setZero(),pr.setZero(),mr.setZero();let s=t.bi;t.bj;for(let a=0;a!==e;a++)t=this.result[this.result.length-1-a],t.bi!==s?(Cs.vadd(t.ni,Cs),pr.vadd(t.ri,pr),mr.vadd(t.rj,mr)):(Cs.vsub(t.ni,Cs),pr.vadd(t.rj,pr),mr.vadd(t.ri,mr));let o=1/e;pr.scale(o,n.ri),mr.scale(o,n.rj),i.ri.copy(n.ri),i.rj.copy(n.rj),Cs.normalize(),Cs.tangents(n.t,i.t)}getContacts(e,t,n,i,s,o,a){this.contactPointPool=s,this.frictionEquationPool=a,this.result=i,this.frictionResult=o;let l=xy,h=yy,f=gy,c=vy;for(let u=0,d=e.length;u!==d;u++){let p=e[u],v=t[u],g=null;p.material&&v.material&&(g=n.getContactMaterial(p.material,v.material)||null);let m=p.type&Xe.KINEMATIC&&v.type&Xe.STATIC||p.type&Xe.STATIC&&v.type&Xe.KINEMATIC||p.type&Xe.KINEMATIC&&v.type&Xe.KINEMATIC;for(let _=0;_<p.shapes.length;_++){p.quaternion.mult(p.shapeOrientations[_],l),p.quaternion.vmult(p.shapeOffsets[_],f),f.vadd(p.position,f);let x=p.shapes[_];for(let y=0;y<v.shapes.length;y++){v.quaternion.mult(v.shapeOrientations[y],h),v.quaternion.vmult(v.shapeOffsets[y],c),c.vadd(v.position,c);let S=v.shapes[y];if(!(x.collisionFilterMask&S.collisionFilterGroup&&S.collisionFilterMask&x.collisionFilterGroup)||f.distanceTo(c)>x.boundingSphereRadius+S.boundingSphereRadius)continue;let M=null;x.material&&S.material&&(M=n.getContactMaterial(x.material,S.material)||null),this.currentContactMaterial=M||g||n.defaultContactMaterial;let E=x.type|S.type,A=this[E];if(A){let b=!1;x.type<S.type?b=A.call(this,x,S,f,c,l,h,p,v,x,S,m):b=A.call(this,S,x,c,f,h,l,v,p,x,S,m),b&&m&&(n.shapeOverlapKeeper.set(x.id,S.id),n.bodyOverlapKeeper.set(p.id,v.id))}}}}}sphereSphere(e,t,n,i,s,o,a,l,h,f,c){if(c)return n.distanceSquared(i)<(e.radius+t.radius)**2;let u=this.createContactEquation(a,l,e,t,h,f);i.vsub(n,u.ni),u.ni.normalize(),u.ri.copy(u.ni),u.rj.copy(u.ni),u.ri.scale(e.radius,u.ri),u.rj.scale(-t.radius,u.rj),u.ri.vadd(n,u.ri),u.ri.vsub(a.position,u.ri),u.rj.vadd(i,u.rj),u.rj.vsub(l.position,u.rj),this.result.push(u),this.createFrictionEquationsFromContact(u,this.frictionResult)}spherePlane(e,t,n,i,s,o,a,l,h,f,c){let u=this.createContactEquation(a,l,e,t,h,f);if(u.ni.set(0,0,1),o.vmult(u.ni,u.ni),u.ni.negate(u.ni),u.ni.normalize(),u.ni.scale(e.radius,u.ri),n.vsub(i,El),u.ni.scale(u.ni.dot(El),cd),El.vsub(cd,u.rj),-El.dot(u.ni)<=e.radius){if(c)return!0;let d=u.ri,p=u.rj;d.vadd(n,d),d.vsub(a.position,d),p.vadd(i,p),p.vsub(l.position,p),this.result.push(u),this.createFrictionEquationsFromContact(u,this.frictionResult)}}boxBox(e,t,n,i,s,o,a,l,h,f,c){return e.convexPolyhedronRepresentation.material=e.material,t.convexPolyhedronRepresentation.material=t.material,e.convexPolyhedronRepresentation.collisionResponse=e.collisionResponse,t.convexPolyhedronRepresentation.collisionResponse=t.collisionResponse,this.convexConvex(e.convexPolyhedronRepresentation,t.convexPolyhedronRepresentation,n,i,s,o,a,l,e,t,c)}sphereBox(e,t,n,i,s,o,a,l,h,f,c){let u=this.v3pool,d=qy;n.vsub(i,Al),t.getSideNormals(d,o);let p=e.radius,v=!1,g=$y,m=Yy,_=Zy,x=null,y=0,S=0,M=0,E=null;for(let N=0,z=d.length;N!==z&&v===!1;N++){let O=Hy;O.copy(d[N]);let K=O.length();O.normalize();let ee=Al.dot(O);if(ee<K+p&&ee>0){let oe=Gy,ae=Wy;oe.copy(d[(N+1)%3]),ae.copy(d[(N+2)%3]);let Ge=oe.length(),Ce=ae.length();oe.normalize(),ae.normalize();let We=Al.dot(oe),j=Al.dot(ae);if(We<Ge&&We>-Ge&&j<Ce&&j>-Ce){let ne=Math.abs(ee-K-p);if((E===null||ne<E)&&(E=ne,S=We,M=j,x=K,g.copy(O),m.copy(oe),_.copy(ae),y++,c))return!0}}}if(y){v=!0;let N=this.createContactEquation(a,l,e,t,h,f);g.scale(-p,N.ri),N.ni.copy(g),N.ni.negate(N.ni),g.scale(x,g),m.scale(S,m),g.vadd(m,g),_.scale(M,_),g.vadd(_,N.rj),N.ri.vadd(n,N.ri),N.ri.vsub(a.position,N.ri),N.rj.vadd(i,N.rj),N.rj.vsub(l.position,N.rj),this.result.push(N),this.createFrictionEquationsFromContact(N,this.frictionResult)}let A=u.get(),b=Xy;for(let N=0;N!==2&&!v;N++)for(let z=0;z!==2&&!v;z++)for(let O=0;O!==2&&!v;O++)if(A.set(0,0,0),N?A.vadd(d[0],A):A.vsub(d[0],A),z?A.vadd(d[1],A):A.vsub(d[1],A),O?A.vadd(d[2],A):A.vsub(d[2],A),i.vadd(A,b),b.vsub(n,b),b.lengthSquared()<p*p){if(c)return!0;v=!0;let K=this.createContactEquation(a,l,e,t,h,f);K.ri.copy(b),K.ri.normalize(),K.ni.copy(K.ri),K.ri.scale(p,K.ri),K.rj.copy(A),K.ri.vadd(n,K.ri),K.ri.vsub(a.position,K.ri),K.rj.vadd(i,K.rj),K.rj.vsub(l.position,K.rj),this.result.push(K),this.createFrictionEquationsFromContact(K,this.frictionResult)}u.release(A),A=null;let w=u.get(),T=u.get(),F=u.get(),D=u.get(),C=u.get(),P=d.length;for(let N=0;N!==P&&!v;N++)for(let z=0;z!==P&&!v;z++)if(N%3!==z%3){d[z].cross(d[N],w),w.normalize(),d[N].vadd(d[z],T),F.copy(n),F.vsub(T,F),F.vsub(i,F);let O=F.dot(w);w.scale(O,D);let K=0;for(;K===N%3||K===z%3;)K++;C.copy(n),C.vsub(D,C),C.vsub(T,C),C.vsub(i,C);let ee=Math.abs(O),oe=C.length();if(ee<d[K].length()&&oe<p){if(c)return!0;v=!0;let ae=this.createContactEquation(a,l,e,t,h,f);T.vadd(D,ae.rj),ae.rj.copy(ae.rj),C.negate(ae.ni),ae.ni.normalize(),ae.ri.copy(ae.rj),ae.ri.vadd(i,ae.ri),ae.ri.vsub(n,ae.ri),ae.ri.normalize(),ae.ri.scale(p,ae.ri),ae.ri.vadd(n,ae.ri),ae.ri.vsub(a.position,ae.ri),ae.rj.vadd(i,ae.rj),ae.rj.vsub(l.position,ae.rj),this.result.push(ae),this.createFrictionEquationsFromContact(ae,this.frictionResult)}}u.release(w,T,F,D,C)}planeBox(e,t,n,i,s,o,a,l,h,f,c){return t.convexPolyhedronRepresentation.material=t.material,t.convexPolyhedronRepresentation.collisionResponse=t.collisionResponse,t.convexPolyhedronRepresentation.id=t.id,this.planeConvex(e,t.convexPolyhedronRepresentation,n,i,s,o,a,l,e,t,c)}convexConvex(e,t,n,i,s,o,a,l,h,f,c,u,d){let p=h_;if(!(n.distanceTo(i)>e.boundingSphereRadius+t.boundingSphereRadius)&&e.findSeparatingAxis(t,n,s,i,o,p,u,d)){let v=[],g=u_;e.clipAgainstHull(n,s,t,i,o,p,-100,100,v);let m=0;for(let _=0;_!==v.length;_++){if(c)return!0;let x=this.createContactEquation(a,l,e,t,h,f),y=x.ri,S=x.rj;p.negate(x.ni),v[_].normal.negate(g),g.scale(v[_].depth,g),v[_].point.vadd(g,y),S.copy(v[_].point),y.vsub(n,y),S.vsub(i,S),y.vadd(n,y),y.vsub(a.position,y),S.vadd(i,S),S.vsub(l.position,S),this.result.push(x),m++,this.enableFrictionReduction||this.createFrictionEquationsFromContact(x,this.frictionResult)}this.enableFrictionReduction&&m&&this.createFrictionFromAverage(m)}}sphereConvex(e,t,n,i,s,o,a,l,h,f,c){let u=this.v3pool;n.vsub(i,Ky);let d=t.faceNormals,p=t.faces,v=t.vertices,g=e.radius,m=!1;for(let _=0;_!==v.length;_++){let x=v[_],y=e_;o.vmult(x,y),i.vadd(y,y);let S=Qy;if(y.vsub(n,S),S.lengthSquared()<g*g){if(c)return!0;m=!0;let M=this.createContactEquation(a,l,e,t,h,f);M.ri.copy(S),M.ri.normalize(),M.ni.copy(M.ri),M.ri.scale(g,M.ri),y.vsub(i,M.rj),M.ri.vadd(n,M.ri),M.ri.vsub(a.position,M.ri),M.rj.vadd(i,M.rj),M.rj.vsub(l.position,M.rj),this.result.push(M),this.createFrictionEquationsFromContact(M,this.frictionResult);return}}for(let _=0,x=p.length;_!==x&&m===!1;_++){let y=d[_],S=p[_],M=t_;o.vmult(y,M);let E=n_;o.vmult(v[S[0]],E),E.vadd(i,E);let A=i_;M.scale(-g,A),n.vadd(A,A);let b=s_;A.vsub(E,b);let w=b.dot(M),T=r_;if(n.vsub(E,T),w<0&&T.dot(M)>0){let F=[];for(let D=0,C=S.length;D!==C;D++){let P=u.get();o.vmult(v[S[D]],P),i.vadd(P,P),F.push(P)}if(Vy(F,M,n)){if(c)return!0;m=!0;let D=this.createContactEquation(a,l,e,t,h,f);M.scale(-g,D.ri),M.negate(D.ni);let C=u.get();M.scale(-w,C);let P=u.get();M.scale(-g,P),n.vsub(i,D.rj),D.rj.vadd(P,D.rj),D.rj.vadd(C,D.rj),D.rj.vadd(i,D.rj),D.rj.vsub(l.position,D.rj),D.ri.vadd(n,D.ri),D.ri.vsub(a.position,D.ri),u.release(C),u.release(P),this.result.push(D),this.createFrictionEquationsFromContact(D,this.frictionResult);for(let N=0,z=F.length;N!==z;N++)u.release(F[N]);return}else for(let D=0;D!==S.length;D++){let C=u.get(),P=u.get();o.vmult(v[S[(D+1)%S.length]],C),o.vmult(v[S[(D+2)%S.length]],P),i.vadd(C,C),i.vadd(P,P);let N=Jy;P.vsub(C,N);let z=jy;N.unit(z);let O=u.get(),K=u.get();n.vsub(C,K);let ee=K.dot(z);z.scale(ee,O),O.vadd(C,O);let oe=u.get();if(O.vsub(n,oe),ee>0&&ee*ee<N.lengthSquared()&&oe.lengthSquared()<g*g){if(c)return!0;let ae=this.createContactEquation(a,l,e,t,h,f);O.vsub(i,ae.rj),O.vsub(n,ae.ni),ae.ni.normalize(),ae.ni.scale(g,ae.ri),ae.rj.vadd(i,ae.rj),ae.rj.vsub(l.position,ae.rj),ae.ri.vadd(n,ae.ri),ae.ri.vsub(a.position,ae.ri),this.result.push(ae),this.createFrictionEquationsFromContact(ae,this.frictionResult);for(let Ge=0,Ce=F.length;Ge!==Ce;Ge++)u.release(F[Ge]);u.release(C),u.release(P),u.release(O),u.release(oe),u.release(K);return}u.release(C),u.release(P),u.release(O),u.release(oe),u.release(K)}for(let D=0,C=F.length;D!==C;D++)u.release(F[D])}}}planeConvex(e,t,n,i,s,o,a,l,h,f,c){let u=o_,d=a_;d.set(0,0,1),s.vmult(d,d);let p=0,v=l_;for(let g=0;g!==t.vertices.length;g++)if(u.copy(t.vertices[g]),o.vmult(u,u),i.vadd(u,u),u.vsub(n,v),d.dot(v)<=0){if(c)return!0;let _=this.createContactEquation(a,l,e,t,h,f),x=c_;d.scale(d.dot(v),x),u.vsub(x,x),x.vsub(n,_.ri),_.ni.copy(d),u.vsub(i,_.rj),_.ri.vadd(n,_.ri),_.ri.vsub(a.position,_.ri),_.rj.vadd(i,_.rj),_.rj.vsub(l.position,_.rj),this.result.push(_),p++,this.enableFrictionReduction||this.createFrictionEquationsFromContact(_,this.frictionResult)}this.enableFrictionReduction&&p&&this.createFrictionFromAverage(p)}boxConvex(e,t,n,i,s,o,a,l,h,f,c){return e.convexPolyhedronRepresentation.material=e.material,e.convexPolyhedronRepresentation.collisionResponse=e.collisionResponse,this.convexConvex(e.convexPolyhedronRepresentation,t,n,i,s,o,a,l,e,t,c)}sphereHeightfield(e,t,n,i,s,o,a,l,h,f,c){let u=t.data,d=e.radius,p=t.elementSize,v=b_,g=S_;ut.pointToLocalFrame(i,o,n,g);let m=Math.floor((g.x-d)/p)-1,_=Math.ceil((g.x+d)/p)+1,x=Math.floor((g.y-d)/p)-1,y=Math.ceil((g.y+d)/p)+1;if(_<0||y<0||m>u.length||x>u[0].length)return;m<0&&(m=0),_<0&&(_=0),x<0&&(x=0),y<0&&(y=0),m>=u.length&&(m=u.length-1),_>=u.length&&(_=u.length-1),y>=u[0].length&&(y=u[0].length-1),x>=u[0].length&&(x=u[0].length-1);let S=[];t.getRectMinMax(m,x,_,y,S);let M=S[0],E=S[1];if(g.z-d>E||g.z+d<M)return;let A=this.result;for(let b=m;b<_;b++)for(let w=x;w<y;w++){let T=A.length,F=!1;if(t.getConvexTrianglePillar(b,w,!1),ut.pointToWorldFrame(i,o,t.pillarOffset,v),n.distanceTo(v)<t.pillarConvex.boundingSphereRadius+e.boundingSphereRadius&&(F=this.sphereConvex(e,t.pillarConvex,n,v,s,o,a,l,e,t,c)),c&&F||(t.getConvexTrianglePillar(b,w,!0),ut.pointToWorldFrame(i,o,t.pillarOffset,v),n.distanceTo(v)<t.pillarConvex.boundingSphereRadius+e.boundingSphereRadius&&(F=this.sphereConvex(e,t.pillarConvex,n,v,s,o,a,l,e,t,c)),c&&F))return!0;if(A.length-T>2)return}}boxHeightfield(e,t,n,i,s,o,a,l,h,f,c){return e.convexPolyhedronRepresentation.material=e.material,e.convexPolyhedronRepresentation.collisionResponse=e.collisionResponse,this.convexHeightfield(e.convexPolyhedronRepresentation,t,n,i,s,o,a,l,e,t,c)}convexHeightfield(e,t,n,i,s,o,a,l,h,f,c){let u=t.data,d=t.elementSize,p=e.boundingSphereRadius,v=__,g=M_,m=y_;ut.pointToLocalFrame(i,o,n,m);let _=Math.floor((m.x-p)/d)-1,x=Math.ceil((m.x+p)/d)+1,y=Math.floor((m.y-p)/d)-1,S=Math.ceil((m.y+p)/d)+1;if(x<0||S<0||_>u.length||y>u[0].length)return;_<0&&(_=0),x<0&&(x=0),y<0&&(y=0),S<0&&(S=0),_>=u.length&&(_=u.length-1),x>=u.length&&(x=u.length-1),S>=u[0].length&&(S=u[0].length-1),y>=u[0].length&&(y=u[0].length-1);let M=[];t.getRectMinMax(_,y,x,S,M);let E=M[0],A=M[1];if(!(m.z-p>A||m.z+p<E))for(let b=_;b<x;b++)for(let w=y;w<S;w++){let T=!1;if(t.getConvexTrianglePillar(b,w,!1),ut.pointToWorldFrame(i,o,t.pillarOffset,v),n.distanceTo(v)<t.pillarConvex.boundingSphereRadius+e.boundingSphereRadius&&(T=this.convexConvex(e,t.pillarConvex,n,v,s,o,a,l,null,null,c,g,null)),c&&T||(t.getConvexTrianglePillar(b,w,!0),ut.pointToWorldFrame(i,o,t.pillarOffset,v),n.distanceTo(v)<t.pillarConvex.boundingSphereRadius+e.boundingSphereRadius&&(T=this.convexConvex(e,t.pillarConvex,n,v,s,o,a,l,null,null,c,g,null)),c&&T))return!0}}sphereParticle(e,t,n,i,s,o,a,l,h,f,c){let u=m_;if(u.set(0,0,1),i.vsub(n,u),u.lengthSquared()<=e.radius*e.radius){if(c)return!0;let p=this.createContactEquation(l,a,t,e,h,f);u.normalize(),p.rj.copy(u),p.rj.scale(e.radius,p.rj),p.ni.copy(u),p.ni.negate(p.ni),p.ri.set(0,0,0),this.result.push(p),this.createFrictionEquationsFromContact(p,this.frictionResult)}}planeParticle(e,t,n,i,s,o,a,l,h,f,c){let u=f_;u.set(0,0,1),a.quaternion.vmult(u,u);let d=d_;if(i.vsub(a.position,d),u.dot(d)<=0){if(c)return!0;let v=this.createContactEquation(l,a,t,e,h,f);v.ni.copy(u),v.ni.negate(v.ni),v.ri.set(0,0,0);let g=p_;u.scale(u.dot(i),g),i.vsub(g,g),v.rj.copy(g),this.result.push(v),this.createFrictionEquationsFromContact(v,this.frictionResult)}}boxParticle(e,t,n,i,s,o,a,l,h,f,c){return e.convexPolyhedronRepresentation.material=e.material,e.convexPolyhedronRepresentation.collisionResponse=e.collisionResponse,this.convexParticle(e.convexPolyhedronRepresentation,t,n,i,s,o,a,l,e,t,c)}convexParticle(e,t,n,i,s,o,a,l,h,f,c){let u=-1,d=v_,p=x_,v=null,g=g_;if(g.copy(i),g.vsub(n,g),s.conjugate(hd),hd.vmult(g,g),e.pointIsInside(g)){e.worldVerticesNeedsUpdate&&e.computeWorldVertices(n,s),e.worldFaceNormalsNeedsUpdate&&e.computeWorldFaceNormals(s);for(let m=0,_=e.faces.length;m!==_;m++){let x=[e.worldVertices[e.faces[m][0]]],y=e.worldFaceNormals[m];i.vsub(x[0],ud);let S=-y.dot(ud);if(v===null||Math.abs(S)<Math.abs(v)){if(c)return!0;v=S,u=m,d.copy(y)}}if(u!==-1){let m=this.createContactEquation(l,a,t,e,h,f);d.scale(v,p),p.vadd(i,p),p.vsub(n,p),m.rj.copy(p),d.negate(m.ni),m.ri.set(0,0,0);let _=m.ri,x=m.rj;_.vadd(i,_),_.vsub(l.position,_),x.vadd(n,x),x.vsub(a.position,x),this.result.push(m),this.createFrictionEquationsFromContact(m,this.frictionResult)}else console.warn("Point found inside convex, but did not find penetrating face!")}}heightfieldCylinder(e,t,n,i,s,o,a,l,h,f,c){return this.convexHeightfield(t,e,i,n,o,s,l,a,h,f,c)}particleCylinder(e,t,n,i,s,o,a,l,h,f,c){return this.convexParticle(t,e,i,n,o,s,l,a,h,f,c)}sphereTrimesh(e,t,n,i,s,o,a,l,h,f,c){let u=Ty,d=Cy,p=Ry,v=Py,g=Iy,m=Ny,_=By,x=Ay,y=wy,S=Uy;ut.pointToLocalFrame(i,o,n,g);let M=e.radius;_.lowerBound.set(g.x-M,g.y-M,g.z-M),_.upperBound.set(g.x+M,g.y+M,g.z+M),t.getTrianglesInAABB(_,S);let E=Ey,A=e.radius*e.radius;for(let D=0;D<S.length;D++)for(let C=0;C<3;C++)if(t.getVertex(t.indices[S[D]*3+C],E),E.vsub(g,y),y.lengthSquared()<=A){if(x.copy(E),ut.pointToWorldFrame(i,o,x,E),E.vsub(n,y),c)return!0;let P=this.createContactEquation(a,l,e,t,h,f);P.ni.copy(y),P.ni.normalize(),P.ri.copy(P.ni),P.ri.scale(e.radius,P.ri),P.ri.vadd(n,P.ri),P.ri.vsub(a.position,P.ri),P.rj.copy(E),P.rj.vsub(l.position,P.rj),this.result.push(P),this.createFrictionEquationsFromContact(P,this.frictionResult)}for(let D=0;D<S.length;D++)for(let C=0;C<3;C++){t.getVertex(t.indices[S[D]*3+C],u),t.getVertex(t.indices[S[D]*3+(C+1)%3],d),d.vsub(u,p),g.vsub(d,m);let P=m.dot(p);g.vsub(u,m);let N=m.dot(p);if(N>0&&P<0&&(g.vsub(u,m),v.copy(p),v.normalize(),N=m.dot(v),v.scale(N,m),m.vadd(u,m),m.distanceTo(g)<e.radius)){if(c)return!0;let O=this.createContactEquation(a,l,e,t,h,f);m.vsub(g,O.ni),O.ni.normalize(),O.ni.scale(e.radius,O.ri),O.ri.vadd(n,O.ri),O.ri.vsub(a.position,O.ri),ut.pointToWorldFrame(i,o,m,m),m.vsub(l.position,O.rj),ut.vectorToWorldFrame(o,O.ni,O.ni),ut.vectorToWorldFrame(o,O.ri,O.ri),this.result.push(O),this.createFrictionEquationsFromContact(O,this.frictionResult)}}let b=Ly,w=Dy,T=Fy,F=by;for(let D=0,C=S.length;D!==C;D++){t.getTriangleVertices(S[D],b,w,T),t.getNormal(S[D],F),g.vsub(b,m);let P=m.dot(F);if(F.scale(P,m),g.vsub(m,m),P=m.distanceTo(g),Un.pointInTriangle(m,b,w,T)&&P<e.radius){if(c)return!0;let N=this.createContactEquation(a,l,e,t,h,f);m.vsub(g,N.ni),N.ni.normalize(),N.ni.scale(e.radius,N.ri),N.ri.vadd(n,N.ri),N.ri.vsub(a.position,N.ri),ut.pointToWorldFrame(i,o,m,m),m.vsub(l.position,N.rj),ut.vectorToWorldFrame(o,N.ni,N.ni),ut.vectorToWorldFrame(o,N.ri,N.ri),this.result.push(N),this.createFrictionEquationsFromContact(N,this.frictionResult)}}S.length=0}planeTrimesh(e,t,n,i,s,o,a,l,h,f,c){let u=new R,d=_y;d.set(0,0,1),s.vmult(d,d);for(let p=0;p<t.vertices.length/3;p++){t.getVertex(p,u);let v=new R;v.copy(u),ut.pointToWorldFrame(i,o,v,u);let g=My;if(u.vsub(n,g),d.dot(g)<=0){if(c)return!0;let _=this.createContactEquation(a,l,e,t,h,f);_.ni.copy(d);let x=Sy;d.scale(g.dot(d),x),u.vsub(x,x),_.ri.copy(x),_.ri.vsub(a.position,_.ri),_.rj.copy(u),_.rj.vsub(l.position,_.rj),this.result.push(_),this.createFrictionEquationsFromContact(_,this.frictionResult)}}}},Cs=new R,pr=new R,mr=new R,gy=new R,vy=new R,xy=new Pt,yy=new Pt,_y=new R,My=new R,Sy=new R,by=new R,wy=new R;new R;var Ey=new R,Ay=new R,Ty=new R,Cy=new R,Ry=new R,Py=new R,Iy=new R,Ny=new R,Ly=new R,Dy=new R,Fy=new R,By=new wn,Uy=[],El=new R,cd=new R,Oy=new R,zy=new R,ky=new R;function Vy(r,e,t){let n=null,i=r.length;for(let s=0;s!==i;s++){let o=r[s],a=Oy;r[(s+1)%i].vsub(o,a);let l=zy;a.cross(e,l);let h=ky;t.vsub(o,h);let f=l.dot(h);if(n===null||f>0&&n===!0||f<=0&&n===!1){n===null&&(n=f>0);continue}else return!1}return!0}var Al=new R,Hy=new R,Gy=new R,Wy=new R,qy=[new R,new R,new R,new R,new R,new R],Xy=new R,$y=new R,Yy=new R,Zy=new R,Ky=new R,Jy=new R,jy=new R,Qy=new R,e_=new R,t_=new R,n_=new R,i_=new R,s_=new R,r_=new R;new R;new R;var o_=new R,a_=new R,l_=new R,c_=new R,h_=new R,u_=new R,f_=new R,d_=new R,p_=new R,m_=new R,hd=new Pt,g_=new R;new R;var v_=new R,ud=new R,x_=new R,y_=new R,__=new R,M_=[0],S_=new R,b_=new R,Fl=class{constructor(){this.current=[],this.previous=[]}getKey(e,t){if(t<e){let n=t;t=e,e=n}return e<<16|t}set(e,t){let n=this.getKey(e,t),i=this.current,s=0;for(;n>i[s];)s++;if(n!==i[s]){for(let o=i.length-1;o>=s;o--)i[o+1]=i[o];i[s]=n}}tick(){let e=this.current;this.current=this.previous,this.previous=e,this.current.length=0}getDiff(e,t){let n=this.current,i=this.previous,s=n.length,o=i.length,a=0;for(let l=0;l<s;l++){let h=!1,f=n[l];for(;f>i[a];)a++;h=f===i[a],h||fd(e,f)}a=0;for(let l=0;l<o;l++){let h=!1,f=i[l];for(;f>n[a];)a++;h=n[a]===f,h||fd(t,f)}}};function fd(r,e){r.push((e&4294901760)>>16,e&65535)}var Rh=(r,e)=>r<e?`${r}-${e}`:`${e}-${r}`,zh=class{constructor(){this.data={keys:[]}}get(e,t){let n=Rh(e,t);return this.data[n]}set(e,t,n){let i=Rh(e,t);this.get(e,t)||this.data.keys.push(i),this.data[i]=n}delete(e,t){let n=Rh(e,t),i=this.data.keys.indexOf(n);i!==-1&&this.data.keys.splice(i,1),delete this.data[n]}reset(){let e=this.data,t=e.keys;for(;t.length>0;){let n=t.pop();delete e[n]}}},is=class extends Cl{constructor(e){e===void 0&&(e={}),super(),this.dt=-1,this.allowSleep=!!e.allowSleep,this.contacts=[],this.frictionEquations=[],this.quatNormalizeSkip=e.quatNormalizeSkip!==void 0?e.quatNormalizeSkip:0,this.quatNormalizeFast=e.quatNormalizeFast!==void 0?e.quatNormalizeFast:!1,this.time=0,this.stepnumber=0,this.default_dt=1/60,this.nextId=0,this.gravity=new R,e.gravity&&this.gravity.copy(e.gravity),e.frictionGravity&&(this.frictionGravity=new R,this.frictionGravity.copy(e.frictionGravity)),this.broadphase=e.broadphase!==void 0?e.broadphase:new Ih,this.bodies=[],this.hasActiveBodies=!1,this.solver=e.solver!==void 0?e.solver:new Fh,this.constraints=[],this.narrowphase=new Oh(this),this.collisionMatrix=new Tl,this.collisionMatrixPrevious=new Tl,this.bodyOverlapKeeper=new Fl,this.shapeOverlapKeeper=new Fl,this.contactmaterials=[],this.contactMaterialTable=new zh,this.defaultMaterial=new kt("default"),this.defaultContactMaterial=new an(this.defaultMaterial,this.defaultMaterial,{friction:.3,restitution:0}),this.doProfiling=!1,this.profile={solve:0,makeContactConstraints:0,broadphase:0,integrate:0,narrowphase:0},this.accumulator=0,this.subsystems=[],this.addBodyEvent={type:"addBody",body:null},this.removeBodyEvent={type:"removeBody",body:null},this.idToBodyMap={},this.broadphase.setWorld(this)}getContactMaterial(e,t){return this.contactMaterialTable.get(e.id,t.id)}collisionMatrixTick(){let e=this.collisionMatrixPrevious;this.collisionMatrixPrevious=this.collisionMatrix,this.collisionMatrix=e,this.collisionMatrix.reset(),this.bodyOverlapKeeper.tick(),this.shapeOverlapKeeper.tick()}addConstraint(e){this.constraints.push(e)}removeConstraint(e){let t=this.constraints.indexOf(e);t!==-1&&this.constraints.splice(t,1)}rayTest(e,t,n){n instanceof gr?this.raycastClosest(e,t,{skipBackfaces:!0},n):this.raycastAll(e,t,{skipBackfaces:!0},n)}raycastAll(e,t,n,i){return n===void 0&&(n={}),n.mode=Un.ALL,n.from=e,n.to=t,n.callback=i,Ph.intersectWorld(this,n)}raycastAny(e,t,n,i){return n===void 0&&(n={}),n.mode=Un.ANY,n.from=e,n.to=t,n.result=i,Ph.intersectWorld(this,n)}raycastClosest(e,t,n,i){return n===void 0&&(n={}),n.mode=Un.CLOSEST,n.from=e,n.to=t,n.result=i,Ph.intersectWorld(this,n)}addBody(e){this.bodies.includes(e)||(e.index=this.bodies.length,this.bodies.push(e),e.world=this,e.initPosition.copy(e.position),e.initVelocity.copy(e.velocity),e.timeLastSleepy=this.time,e instanceof Xe&&(e.initAngularVelocity.copy(e.angularVelocity),e.initQuaternion.copy(e.quaternion)),this.collisionMatrix.setNumObjects(this.bodies.length),this.addBodyEvent.body=e,this.idToBodyMap[e.id]=e,this.dispatchEvent(this.addBodyEvent))}removeBody(e){e.world=null;let t=this.bodies.length-1,n=this.bodies,i=n.indexOf(e);if(i!==-1){n.splice(i,1);for(let s=0;s!==n.length;s++)n[s].index=s;this.collisionMatrix.setNumObjects(t),this.removeBodyEvent.body=e,delete this.idToBodyMap[e.id],this.dispatchEvent(this.removeBodyEvent)}}getBodyById(e){return this.idToBodyMap[e]}getShapeById(e){let t=this.bodies;for(let n=0;n<t.length;n++){let i=t[n].shapes;for(let s=0;s<i.length;s++){let o=i[s];if(o.id===e)return o}}return null}addContactMaterial(e){this.contactmaterials.push(e),this.contactMaterialTable.set(e.materials[0].id,e.materials[1].id,e)}removeContactMaterial(e){let t=this.contactmaterials.indexOf(e);t!==-1&&(this.contactmaterials.splice(t,1),this.contactMaterialTable.delete(e.materials[0].id,e.materials[1].id))}fixedStep(e,t){e===void 0&&(e=1/60),t===void 0&&(t=10);let n=Bt.now()/1e3;if(!this.lastCallTime)this.step(e,void 0,t);else{let i=n-this.lastCallTime;this.step(e,i,t)}this.lastCallTime=n}step(e,t,n){if(n===void 0&&(n=10),t===void 0)this.internalStep(e),this.time+=e;else{this.accumulator+=t;let i=Bt.now(),s=0;for(;this.accumulator>=e&&s<n&&(this.internalStep(e),this.accumulator-=e,s++,!(Bt.now()-i>e*1e3)););this.accumulator=this.accumulator%e;let o=this.accumulator/e;for(let a=0;a!==this.bodies.length;a++){let l=this.bodies[a];l.previousPosition.lerp(l.position,o,l.interpolatedPosition),l.previousQuaternion.slerp(l.quaternion,o,l.interpolatedQuaternion),l.previousQuaternion.normalize()}this.time+=t}}internalStep(e){this.dt=e;let t=this.contacts,n=C_,i=R_,s=this.bodies.length,o=this.bodies,a=this.solver,l=this.gravity,h=this.doProfiling,f=this.profile,c=Xe.DYNAMIC,u=-1/0,d=this.constraints,p=T_;l.length();let v=l.x,g=l.y,m=l.z,_=0;for(h&&(u=Bt.now()),_=0;_!==s;_++){let D=o[_];if(D.type===c){let C=D.force,P=D.mass;C.x+=P*v,C.y+=P*g,C.z+=P*m}}for(let D=0,C=this.subsystems.length;D!==C;D++)this.subsystems[D].update();h&&(u=Bt.now()),n.length=0,i.length=0,this.broadphase.collisionPairs(this,n,i),h&&(f.broadphase=Bt.now()-u);let x=d.length;for(_=0;_!==x;_++){let D=d[_];if(!D.collideConnected)for(let C=n.length-1;C>=0;C-=1)(D.bodyA===n[C]&&D.bodyB===i[C]||D.bodyB===n[C]&&D.bodyA===i[C])&&(n.splice(C,1),i.splice(C,1))}this.collisionMatrixTick(),h&&(u=Bt.now());let y=A_,S=t.length;for(_=0;_!==S;_++)y.push(t[_]);t.length=0;let M=this.frictionEquations.length;for(_=0;_!==M;_++)p.push(this.frictionEquations[_]);for(this.frictionEquations.length=0,this.narrowphase.getContacts(n,i,this,t,y,this.frictionEquations,p),h&&(f.narrowphase=Bt.now()-u),h&&(u=Bt.now()),_=0;_<this.frictionEquations.length;_++)a.addEquation(this.frictionEquations[_]);let E=t.length;for(let D=0;D!==E;D++){let C=t[D],P=C.bi,N=C.bj,z=C.si,O=C.sj,K;if(P.material&&N.material?K=this.getContactMaterial(P.material,N.material)||this.defaultContactMaterial:K=this.defaultContactMaterial,K.friction,P.material&&N.material&&(P.material.friction>=0&&N.material.friction>=0&&P.material.friction*N.material.friction,P.material.restitution>=0&&N.material.restitution>=0&&(C.restitution=P.material.restitution*N.material.restitution)),a.addEquation(C),P.allowSleep&&P.type===Xe.DYNAMIC&&P.sleepState===Xe.SLEEPING&&N.sleepState===Xe.AWAKE&&N.type!==Xe.STATIC){let ee=N.velocity.lengthSquared()+N.angularVelocity.lengthSquared(),oe=N.sleepSpeedLimit**2;ee>=oe*2&&(P.wakeUpAfterNarrowphase=!0)}if(N.allowSleep&&N.type===Xe.DYNAMIC&&N.sleepState===Xe.SLEEPING&&P.sleepState===Xe.AWAKE&&P.type!==Xe.STATIC){let ee=P.velocity.lengthSquared()+P.angularVelocity.lengthSquared(),oe=P.sleepSpeedLimit**2;ee>=oe*2&&(N.wakeUpAfterNarrowphase=!0)}this.collisionMatrix.set(P,N,!0),this.collisionMatrixPrevious.get(P,N)||(fo.body=N,fo.contact=C,P.dispatchEvent(fo),fo.body=P,N.dispatchEvent(fo)),this.bodyOverlapKeeper.set(P.id,N.id),this.shapeOverlapKeeper.set(z.id,O.id)}for(this.emitContactEvents(),h&&(f.makeContactConstraints=Bt.now()-u,u=Bt.now()),_=0;_!==s;_++){let D=o[_];D.wakeUpAfterNarrowphase&&(D.wakeUp(),D.wakeUpAfterNarrowphase=!1)}for(x=d.length,_=0;_!==x;_++){let D=d[_];D.update();for(let C=0,P=D.equations.length;C!==P;C++){let N=D.equations[C];a.addEquation(N)}}a.solve(e,this),h&&(f.solve=Bt.now()-u),a.removeAllEquations();let A=Math.pow;for(_=0;_!==s;_++){let D=o[_];if(D.type&c){let C=A(1-D.linearDamping,e),P=D.velocity;P.scale(C,P);let N=D.angularVelocity;if(N){let z=A(1-D.angularDamping,e);N.scale(z,N)}}}this.dispatchEvent(E_),h&&(u=Bt.now());let w=this.stepnumber%(this.quatNormalizeSkip+1)===0,T=this.quatNormalizeFast;for(_=0;_!==s;_++)o[_].integrate(e,w,T);this.clearForces(),this.broadphase.dirty=!0,h&&(f.integrate=Bt.now()-u),this.stepnumber+=1,this.dispatchEvent(w_);let F=!0;if(this.allowSleep)for(F=!1,_=0;_!==s;_++){let D=o[_];D.sleepTick(this.time),D.sleepState!==Xe.SLEEPING&&(F=!0)}this.hasActiveBodies=F}emitContactEvents(){let e=this.hasAnyEventListener("beginContact"),t=this.hasAnyEventListener("endContact");if((e||t)&&this.bodyOverlapKeeper.getDiff(Ri,Pi),e){for(let s=0,o=Ri.length;s<o;s+=2)po.bodyA=this.getBodyById(Ri[s]),po.bodyB=this.getBodyById(Ri[s+1]),this.dispatchEvent(po);po.bodyA=po.bodyB=null}if(t){for(let s=0,o=Pi.length;s<o;s+=2)mo.bodyA=this.getBodyById(Pi[s]),mo.bodyB=this.getBodyById(Pi[s+1]),this.dispatchEvent(mo);mo.bodyA=mo.bodyB=null}Ri.length=Pi.length=0;let n=this.hasAnyEventListener("beginShapeContact"),i=this.hasAnyEventListener("endShapeContact");if((n||i)&&this.shapeOverlapKeeper.getDiff(Ri,Pi),n){for(let s=0,o=Ri.length;s<o;s+=2){let a=this.getShapeById(Ri[s]),l=this.getShapeById(Ri[s+1]);Ii.shapeA=a,Ii.shapeB=l,a&&(Ii.bodyA=a.body),l&&(Ii.bodyB=l.body),this.dispatchEvent(Ii)}Ii.bodyA=Ii.bodyB=Ii.shapeA=Ii.shapeB=null}if(i){for(let s=0,o=Pi.length;s<o;s+=2){let a=this.getShapeById(Pi[s]),l=this.getShapeById(Pi[s+1]);Ni.shapeA=a,Ni.shapeB=l,a&&(Ni.bodyA=a.body),l&&(Ni.bodyB=l.body),this.dispatchEvent(Ni)}Ni.bodyA=Ni.bodyB=Ni.shapeA=Ni.shapeB=null}}clearForces(){let e=this.bodies,t=e.length;for(let n=0;n!==t;n++){let i=e[n];i.force,i.torque,i.force.set(0,0,0),i.torque.set(0,0,0)}}};new wn;var Ph=new Un,Bt=globalThis.performance||{};if(!Bt.now){let r=Date.now();Bt.timing&&Bt.timing.navigationStart&&(r=Bt.timing.navigationStart),Bt.now=()=>Date.now()-r}new R;var w_={type:"postStep"},E_={type:"preStep"},fo={type:Xe.COLLIDE_EVENT_NAME,body:null,contact:null},A_=[],T_=[],C_=[],R_=[],Ri=[],Pi=[],po={type:"beginContact",bodyA:null,bodyB:null},mo={type:"endContact",bodyA:null,bodyB:null},Ii={type:"beginShapeContact",bodyA:null,bodyB:null,shapeA:null,shapeB:null},Ni={type:"endShapeContact",bodyA:null,bodyB:null,shapeA:null,shapeB:null};function P_(r){return r!==null?{comment:r,variations:[]}:{variations:[]}}function I_(r,e,t,n,i){let s={move:r,variations:i};return e&&(s.suffix=e),t&&(s.nag=t),n!==null&&(s.comment=n),s}function N_(...r){let[e,...t]=r,n=e;for(let i of t)i!==null&&(n.variations=[i,...i.variations],i.variations=[],n=i);return e}function L_(r,e){if(e.marker&&e.marker.comment){let t=e.root;for(;;){let n=t.variations[0];if(!n){t.comment=e.marker.comment;break}t=n}}return{headers:r,root:e.root,result:(e.marker&&e.marker.result)??void 0}}function D_(r,e){function t(){this.constructor=r}t.prototype=e.prototype,r.prototype=new t}function xr(r,e,t,n){var i=Error.call(this,r);return Object.setPrototypeOf&&Object.setPrototypeOf(i,xr.prototype),i.expected=e,i.found=t,i.location=n,i.name="SyntaxError",i}D_(xr,Error);function Gh(r,e,t){return t=t||" ",r.length>e?r:(e-=r.length,t+=t.repeat(e),r+t.slice(0,e))}xr.prototype.format=function(r){var e="Error: "+this.message;if(this.location){var t=null,n;for(n=0;n<r.length;n++)if(r[n].source===this.location.source){t=r[n].text.split(/\r\n|\n|\r/g);break}var i=this.location.start,s=this.location.source&&typeof this.location.source.offset=="function"?this.location.source.offset(i):i,o=this.location.source+":"+s.line+":"+s.column;if(t){var a=this.location.end,l=Gh("",s.line.toString().length," "),h=t[i.line-1],f=i.line===a.line?a.column:h.length+1,c=f-i.column||1;e+=`
 --> `+o+`
`+l+` |
`+s.line+" | "+h+`
`+l+" | "+Gh("",i.column-1," ")+Gh("",c,"^")}else e+=`
 at `+o}return e};xr.buildMessage=function(r,e){var t={literal:function(h){return'"'+i(h.text)+'"'},class:function(h){var f=h.parts.map(function(c){return Array.isArray(c)?s(c[0])+"-"+s(c[1]):s(c)});return"["+(h.inverted?"^":"")+f.join("")+"]"},any:function(){return"any character"},end:function(){return"end of input"},other:function(h){return h.description}};function n(h){return h.charCodeAt(0).toString(16).toUpperCase()}function i(h){return h.replace(/\\/g,"\\\\").replace(/"/g,'\\"').replace(/\0/g,"\\0").replace(/\t/g,"\\t").replace(/\n/g,"\\n").replace(/\r/g,"\\r").replace(/[\x00-\x0F]/g,function(f){return"\\x0"+n(f)}).replace(/[\x10-\x1F\x7F-\x9F]/g,function(f){return"\\x"+n(f)})}function s(h){return h.replace(/\\/g,"\\\\").replace(/\]/g,"\\]").replace(/\^/g,"\\^").replace(/-/g,"\\-").replace(/\0/g,"\\0").replace(/\t/g,"\\t").replace(/\n/g,"\\n").replace(/\r/g,"\\r").replace(/[\x00-\x0F]/g,function(f){return"\\x0"+n(f)}).replace(/[\x10-\x1F\x7F-\x9F]/g,function(f){return"\\x"+n(f)})}function o(h){return t[h.type](h)}function a(h){var f=h.map(o),c,u;if(f.sort(),f.length>0){for(c=1,u=1;c<f.length;c++)f[c-1]!==f[c]&&(f[u]=f[c],u++);f.length=u}switch(f.length){case 1:return f[0];case 2:return f[0]+" or "+f[1];default:return f.slice(0,-1).join(", ")+", or "+f[f.length-1]}}function l(h){return h?'"'+i(h)+'"':"end of input"}return"Expected "+a(r)+" but "+l(e)+" found."};function F_(r,e){e=e!==void 0?e:{};var t={},n=e.grammarSource,i={pgn:Po},s=Po,o="[",a='"',l="]",h=".",f="O-O-O",c="O-O",u="0-0-0",d="0-0",p="$",v="{",g="}",m=";",_="(",x=")",y="1-0",S="0-1",M="1/2-1/2",E="*",A=/^[a-zA-Z]/,b=/^[^"]/,w=/^[0-9]/,T=/^[.]/,F=/^[a-zA-Z1-8\-=]/,D=/^[+#]/,C=/^[!?]/,P=/^[^}]/,N=/^[^\r\n]/,z=/^[ \t\r\n]/,O=qt("tag pair"),K=Et("[",!1),ee=Et('"',!1),oe=Et("]",!1),ae=qt("tag name"),Ge=sn([["a","z"],["A","Z"]],!1,!1),Ce=qt("tag value"),We=sn(['"'],!0,!1),j=qt("move number"),ne=sn([["0","9"]],!1,!1),ye=Et(".",!1),De=sn(["."],!1,!1),Se=qt("standard algebraic notation"),st=Et("O-O-O",!1),Ct=Et("O-O",!1),U=Et("0-0-0",!1),ft=Et("0-0",!1),$e=sn([["a","z"],["A","Z"],["1","8"],"-","="],!1,!1),ke=sn(["+","#"],!1,!1),be=qt("suffix annotation"),ht=sn(["!","?"],!1,!1),Ee=qt("NAG"),Ke=Et("$",!1),yt=qt("brace comment"),gt=Et("{",!1),B=sn(["}"],!0,!1),I=Et("}",!1),X=qt("rest of line comment"),te=Et(";",!1),se=sn(["\r",`
`],!0,!1),Q=qt("variation"),Ue=Et("(",!1),fe=Et(")",!1),Ne=qt("game termination marker"),Fe=Et("1-0",!1),he=Et("0-1",!1),Me=Et("1/2-1/2",!1),He=Et("*",!1),Be=qt("whitespace"),me=sn([" ","	","\r",`
`],!1,!1),Qe=function(V,$){return L_(V,$)},k=function(V){return Object.fromEntries(V)},ue=function(V,$){return[V,$]},de=function(V,$){return{root:V,marker:$}},Ae=function(V,$){return N_(P_(V),...$.flat())},le=function(V,$,q,re,ge){return I_(V,$,q,re,ge)},ie=function(V){return V},Pe=function(V){return V.replace(/[\r\n]+/g," ")},Je=function(V){return V.trim()},mt=function(V){return V},ct=function(V,$){return{result:V,comment:$}},Y=e.peg$currPos|0,Wt=[{line:1,column:1}],ln=Y,Pn=e.peg$maxFailExpected||[],pe=e.peg$silentFails|0,Ui;if(e.startRule){if(!(e.startRule in i))throw new Error(`Can't start parsing from rule "`+e.startRule+'".');s=i[e.startRule]}function Et(V,$){return{type:"literal",text:V,ignoreCase:$}}function sn(V,$,q){return{type:"class",parts:V,inverted:$,ignoreCase:q}}function Ro(){return{type:"end"}}function qt(V){return{type:"other",description:V}}function br(V){var $=Wt[V],q;if($)return $;if(V>=Wt.length)q=Wt.length-1;else for(q=V;!Wt[--q];);for($=Wt[q],$={line:$.line,column:$.column};q<V;)r.charCodeAt(q)===10?($.line++,$.column=1):$.column++,q++;return Wt[V]=$,$}function wr(V,$,q){var re=br(V),ge=br($),Ie={source:n,start:{offset:V,line:re.line,column:re.column},end:{offset:$,line:ge.line,column:ge.column}};return Ie}function Oe(V){Y<ln||(Y>ln&&(ln=Y,Pn=[]),Pn.push(V))}function tc(V,$,q){return new xr(xr.buildMessage(V,$),V,$,q)}function Po(){var V,$,q;return V=Y,$=nc(),q=H(),V=Qe($,q),V}function nc(){var V,$,q;for(V=Y,$=[],q=Io();q!==t;)$.push(q),q=Io();return q=je(),V=k($),V}function Io(){var V,$,q,re,ge,Ie,At;return pe++,V=Y,je(),r.charCodeAt(Y)===91?($=o,Y++):($=t,pe===0&&Oe(K)),$!==t?(je(),q=ic(),q!==t?(je(),r.charCodeAt(Y)===34?(re=a,Y++):(re=t,pe===0&&Oe(ee)),re!==t?(ge=L(),r.charCodeAt(Y)===34?(Ie=a,Y++):(Ie=t,pe===0&&Oe(ee)),Ie!==t?(je(),r.charCodeAt(Y)===93?(At=l,Y++):(At=t,pe===0&&Oe(oe)),At!==t?V=ue(q,ge):(Y=V,V=t)):(Y=V,V=t)):(Y=V,V=t)):(Y=V,V=t)):(Y=V,V=t),pe--,V===t&&pe===0&&Oe(O),V}function ic(){var V,$,q;if(pe++,V=Y,$=[],q=r.charAt(Y),A.test(q)?Y++:(q=t,pe===0&&Oe(Ge)),q!==t)for(;q!==t;)$.push(q),q=r.charAt(Y),A.test(q)?Y++:(q=t,pe===0&&Oe(Ge));else $=t;return $!==t?V=r.substring(V,Y):V=$,pe--,V===t&&($=t,pe===0&&Oe(ae)),V}function L(){var V,$,q;for(pe++,V=Y,$=[],q=r.charAt(Y),b.test(q)?Y++:(q=t,pe===0&&Oe(We));q!==t;)$.push(q),q=r.charAt(Y),b.test(q)?Y++:(q=t,pe===0&&Oe(We));return V=r.substring(V,Y),pe--,$=t,pe===0&&Oe(Ce),V}function H(){var V,$,q;return V=Y,$=Z(),je(),q=rt(),q===t&&(q=null),je(),V=de($,q),V}function Z(){var V,$,q,re;for(V=Y,$=we(),$===t&&($=null),q=[],re=J();re!==t;)q.push(re),re=J();return V=Ae($,q),V}function J(){var V,$,q,re,ge,Ie,At,Hn;if(V=Y,je(),W(),je(),$=ce(),$!==t){for(q=_e(),q===t&&(q=null),re=[],ge=Re();ge!==t;)re.push(ge),ge=Re();for(ge=je(),Ie=we(),Ie===t&&(Ie=null),At=[],Hn=ze();Hn!==t;)At.push(Hn),Hn=ze();V=le($,q,re,Ie,At)}else Y=V,V=t;return V}function W(){var V,$,q,re,ge,Ie;for(pe++,V=Y,$=[],q=r.charAt(Y),w.test(q)?Y++:(q=t,pe===0&&Oe(ne));q!==t;)$.push(q),q=r.charAt(Y),w.test(q)?Y++:(q=t,pe===0&&Oe(ne));if(r.charCodeAt(Y)===46?(q=h,Y++):(q=t,pe===0&&Oe(ye)),q!==t){for(re=je(),ge=[],Ie=r.charAt(Y),T.test(Ie)?Y++:(Ie=t,pe===0&&Oe(De));Ie!==t;)ge.push(Ie),Ie=r.charAt(Y),T.test(Ie)?Y++:(Ie=t,pe===0&&Oe(De));$=[$,q,re,ge],V=$}else Y=V,V=t;return pe--,V===t&&($=t,pe===0&&Oe(j)),V}function ce(){var V,$,q,re,ge,Ie;if(pe++,V=Y,$=Y,r.substr(Y,5)===f?(q=f,Y+=5):(q=t,pe===0&&Oe(st)),q===t&&(r.substr(Y,3)===c?(q=c,Y+=3):(q=t,pe===0&&Oe(Ct)),q===t&&(r.substr(Y,5)===u?(q=u,Y+=5):(q=t,pe===0&&Oe(U)),q===t&&(r.substr(Y,3)===d?(q=d,Y+=3):(q=t,pe===0&&Oe(ft)),q===t))))if(q=Y,re=r.charAt(Y),A.test(re)?Y++:(re=t,pe===0&&Oe(Ge)),re!==t){if(ge=[],Ie=r.charAt(Y),F.test(Ie)?Y++:(Ie=t,pe===0&&Oe($e)),Ie!==t)for(;Ie!==t;)ge.push(Ie),Ie=r.charAt(Y),F.test(Ie)?Y++:(Ie=t,pe===0&&Oe($e));else ge=t;ge!==t?(re=[re,ge],q=re):(Y=q,q=t)}else Y=q,q=t;return q!==t?(re=r.charAt(Y),D.test(re)?Y++:(re=t,pe===0&&Oe(ke)),re===t&&(re=null),q=[q,re],$=q):(Y=$,$=t),$!==t?V=r.substring(V,Y):V=$,pe--,V===t&&($=t,pe===0&&Oe(Se)),V}function _e(){var V,$,q;for(pe++,V=Y,$=[],q=r.charAt(Y),C.test(q)?Y++:(q=t,pe===0&&Oe(ht));q!==t;)$.push(q),$.length>=2?q=t:(q=r.charAt(Y),C.test(q)?Y++:(q=t,pe===0&&Oe(ht)));return $.length<1?(Y=V,V=t):V=$,pe--,V===t&&($=t,pe===0&&Oe(be)),V}function Re(){var V,$,q,re,ge;if(pe++,V=Y,je(),r.charCodeAt(Y)===36?($=p,Y++):($=t,pe===0&&Oe(Ke)),$!==t){if(q=Y,re=[],ge=r.charAt(Y),w.test(ge)?Y++:(ge=t,pe===0&&Oe(ne)),ge!==t)for(;ge!==t;)re.push(ge),ge=r.charAt(Y),w.test(ge)?Y++:(ge=t,pe===0&&Oe(ne));else re=t;re!==t?q=r.substring(q,Y):q=re,q!==t?V=ie(q):(Y=V,V=t)}else Y=V,V=t;return pe--,V===t&&pe===0&&Oe(Ee),V}function we(){var V;return V=Ve(),V===t&&(V=qe()),V}function Ve(){var V,$,q,re,ge;if(pe++,V=Y,r.charCodeAt(Y)===123?($=v,Y++):($=t,pe===0&&Oe(gt)),$!==t){for(q=Y,re=[],ge=r.charAt(Y),P.test(ge)?Y++:(ge=t,pe===0&&Oe(B));ge!==t;)re.push(ge),ge=r.charAt(Y),P.test(ge)?Y++:(ge=t,pe===0&&Oe(B));q=r.substring(q,Y),r.charCodeAt(Y)===125?(re=g,Y++):(re=t,pe===0&&Oe(I)),re!==t?V=Pe(q):(Y=V,V=t)}else Y=V,V=t;return pe--,V===t&&($=t,pe===0&&Oe(yt)),V}function qe(){var V,$,q,re,ge;if(pe++,V=Y,r.charCodeAt(Y)===59?($=m,Y++):($=t,pe===0&&Oe(te)),$!==t){for(q=Y,re=[],ge=r.charAt(Y),N.test(ge)?Y++:(ge=t,pe===0&&Oe(se));ge!==t;)re.push(ge),ge=r.charAt(Y),N.test(ge)?Y++:(ge=t,pe===0&&Oe(se));q=r.substring(q,Y),V=Je(q)}else Y=V,V=t;return pe--,V===t&&($=t,pe===0&&Oe(X)),V}function ze(){var V,$,q,re;return pe++,V=Y,je(),r.charCodeAt(Y)===40?($=_,Y++):($=t,pe===0&&Oe(Ue)),$!==t?(q=Z(),q!==t?(je(),r.charCodeAt(Y)===41?(re=x,Y++):(re=t,pe===0&&Oe(fe)),re!==t?V=mt(q):(Y=V,V=t)):(Y=V,V=t)):(Y=V,V=t),pe--,V===t&&pe===0&&Oe(Q),V}function rt(){var V,$,q;return pe++,V=Y,r.substr(Y,3)===y?($=y,Y+=3):($=t,pe===0&&Oe(Fe)),$===t&&(r.substr(Y,3)===S?($=S,Y+=3):($=t,pe===0&&Oe(he)),$===t&&(r.substr(Y,7)===M?($=M,Y+=7):($=t,pe===0&&Oe(Me)),$===t&&(r.charCodeAt(Y)===42?($=E,Y++):($=t,pe===0&&Oe(He))))),$!==t?(je(),q=we(),q===t&&(q=null),V=ct($,q)):(Y=V,V=t),pe--,V===t&&($=t,pe===0&&Oe(Ne)),V}function je(){var V,$;for(pe++,V=[],$=r.charAt(Y),z.test($)?Y++:($=t,pe===0&&Oe(me));$!==t;)V.push($),$=r.charAt(Y),z.test($)?Y++:($=t,pe===0&&Oe(me));return pe--,$=t,pe===0&&Oe(Be),V}if(Ui=s(),e.peg$library)return{peg$result:Ui,peg$currPos:Y,peg$FAILED:t,peg$maxFailExpected:Pn,peg$maxFailPos:ln};if(Ui!==t&&Y===r.length)return Ui;throw Ui!==t&&Y<r.length&&Oe(Ro()),tc(Pn,ln<r.length?r.charAt(ln):null,ln<r.length?wr(ln,ln+1):wr(ln,ln))}var Ol=0xffffffffffffffffn;function Wh(r,e){return(r<<e|r>>64n-e)&0xffffffffffffffffn}function _d(r,e){return r*e&Ol}function B_(r){return function(){let e=BigInt(r&Ol),t=BigInt(r>>64n&Ol),n=_d(Wh(_d(e,5n),7n),9n);return t^=e,e=(Wh(e,24n)^t^t<<16n)&Ol,t=Wh(t,37n),r=t<<64n|e,n}}var kl=B_(0xa187eb39cdcaed8f31c4b365b102e01en),U_=Array.from({length:2},()=>Array.from({length:6},()=>Array.from({length:128},()=>kl()))),O_=Array.from({length:8},()=>kl()),z_=Array.from({length:16},()=>kl()),qh=kl(),tn="w",En="b",It="p",Kh="n",zl="b",xo="r",os="q",Ut="k",Xh="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",vr=class{color;from;to;piece;captured;promotion;flags;san;lan;before;after;constructor(e,t){let{color:n,piece:i,from:s,to:o,flags:a,captured:l,promotion:h}=t,f=Vt(s),c=Vt(o);this.color=n,this.piece=i,this.from=f,this.to=c,this.san=e._moveToSan(t,e._moves({legal:!0})),this.lan=f+c,this.before=e.fen(),e._makeMove(t),this.after=e.fen(),e._undoMove(),this.flags="";for(let u in Ze)Ze[u]&a&&(this.flags+=Ps[u]);l&&(this.captured=l),h&&(this.promotion=h,this.lan+=h)}isCapture(){return this.flags.indexOf(Ps.CAPTURE)>-1}isPromotion(){return this.flags.indexOf(Ps.PROMOTION)>-1}isEnPassant(){return this.flags.indexOf(Ps.EP_CAPTURE)>-1}isKingsideCastle(){return this.flags.indexOf(Ps.KSIDE_CASTLE)>-1}isQueensideCastle(){return this.flags.indexOf(Ps.QSIDE_CASTLE)>-1}isBigPawn(){return this.flags.indexOf(Ps.BIG_PAWN)>-1}},$t=-1,Ps={NORMAL:"n",CAPTURE:"c",BIG_PAWN:"b",EP_CAPTURE:"e",PROMOTION:"p",KSIDE_CASTLE:"k",QSIDE_CASTLE:"q",NULL_MOVE:"-"};var Ze={NORMAL:1,CAPTURE:2,BIG_PAWN:4,EP_CAPTURE:8,PROMOTION:16,KSIDE_CASTLE:32,QSIDE_CASTLE:64,NULL_MOVE:128},Jh={Event:"?",Site:"?",Date:"????.??.??",Round:"?",White:"?",Black:"?",Result:"*"},k_={WhiteTitle:null,BlackTitle:null,WhiteElo:null,BlackElo:null,WhiteUSCF:null,BlackUSCF:null,WhiteNA:null,BlackNA:null,WhiteType:null,BlackType:null,EventDate:null,EventSponsor:null,Section:null,Stage:null,Board:null,Opening:null,Variation:null,SubVariation:null,ECO:null,NIC:null,Time:null,UTCTime:null,UTCDate:null,TimeControl:null,SetUp:null,FEN:null,Termination:null,Annotator:null,Mode:null,PlyCount:null},V_={...Jh,...k_},Ye={a8:0,b8:1,c8:2,d8:3,e8:4,f8:5,g8:6,h8:7,a7:16,b7:17,c7:18,d7:19,e7:20,f7:21,g7:22,h7:23,a6:32,b6:33,c6:34,d6:35,e6:36,f6:37,g6:38,h6:39,a5:48,b5:49,c5:50,d5:51,e5:52,f5:53,g5:54,h5:55,a4:64,b4:65,c4:66,d4:67,e4:68,f4:69,g4:70,h4:71,a3:80,b3:81,c3:82,d3:83,e3:84,f3:85,g3:86,h3:87,a2:96,b2:97,c2:98,d2:99,e2:100,f2:101,g2:102,h2:103,a1:112,b1:113,c1:114,d1:115,e1:116,f1:117,g1:118,h1:119},$h={b:[16,32,17,15],w:[-16,-32,-17,-15]},Md={n:[-18,-33,-31,-14,18,33,31,14],b:[-17,-15,17,15],r:[-16,1,16,-1],q:[-17,-16,-15,1,17,16,15,-1],k:[-17,-16,-15,1,17,16,15,-1]},H_=[20,0,0,0,0,0,0,24,0,0,0,0,0,0,20,0,0,20,0,0,0,0,0,24,0,0,0,0,0,20,0,0,0,0,20,0,0,0,0,24,0,0,0,0,20,0,0,0,0,0,0,20,0,0,0,24,0,0,0,20,0,0,0,0,0,0,0,0,20,0,0,24,0,0,20,0,0,0,0,0,0,0,0,0,0,20,2,24,2,20,0,0,0,0,0,0,0,0,0,0,0,2,53,56,53,2,0,0,0,0,0,0,24,24,24,24,24,24,56,0,56,24,24,24,24,24,24,0,0,0,0,0,0,2,53,56,53,2,0,0,0,0,0,0,0,0,0,0,0,20,2,24,2,20,0,0,0,0,0,0,0,0,0,0,20,0,0,24,0,0,20,0,0,0,0,0,0,0,0,20,0,0,0,24,0,0,0,20,0,0,0,0,0,0,20,0,0,0,0,24,0,0,0,0,20,0,0,0,0,20,0,0,0,0,0,24,0,0,0,0,0,20,0,0,20,0,0,0,0,0,0,24,0,0,0,0,0,0,20],G_=[17,0,0,0,0,0,0,16,0,0,0,0,0,0,15,0,0,17,0,0,0,0,0,16,0,0,0,0,0,15,0,0,0,0,17,0,0,0,0,16,0,0,0,0,15,0,0,0,0,0,0,17,0,0,0,16,0,0,0,15,0,0,0,0,0,0,0,0,17,0,0,16,0,0,15,0,0,0,0,0,0,0,0,0,0,17,0,16,0,15,0,0,0,0,0,0,0,0,0,0,0,0,17,16,15,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,-15,-16,-17,0,0,0,0,0,0,0,0,0,0,0,0,-15,0,-16,0,-17,0,0,0,0,0,0,0,0,0,0,-15,0,0,-16,0,0,-17,0,0,0,0,0,0,0,0,-15,0,0,0,-16,0,0,0,-17,0,0,0,0,0,0,-15,0,0,0,0,-16,0,0,0,0,-17,0,0,0,0,-15,0,0,0,0,0,-16,0,0,0,0,0,-17,0,0,-15,0,0,0,0,0,0,-16,0,0,0,0,0,0,-17],W_={p:1,n:2,b:4,r:8,q:16,k:32},q_="pnbrqkPNBRQK",Sd=[Kh,zl,xo,os],X_=7,$_=6,Y_=1,Z_=0,Ul={[Ut]:Ze.KSIDE_CASTLE,[os]:Ze.QSIDE_CASTLE},ss={w:[{square:Ye.a1,flag:Ze.QSIDE_CASTLE},{square:Ye.h1,flag:Ze.KSIDE_CASTLE}],b:[{square:Ye.a8,flag:Ze.QSIDE_CASTLE},{square:Ye.h8,flag:Ze.KSIDE_CASTLE}]},K_={b:Y_,w:$_},Yh="--";function Is(r){return r>>4}function yo(r){return r&15}function wd(r){return"0123456789".indexOf(r)!==-1}function Vt(r){let e=yo(r),t=Is(r);return"abcdefgh".substring(e,e+1)+"87654321".substring(t,t+1)}function vo(r){return r===tn?En:tn}function J_(r){let e=r.split(/\s+/);if(e.length!==6)return{ok:!1,error:"Invalid FEN: must contain six space-delimited fields"};let t=parseInt(e[5],10);if(isNaN(t)||t<=0)return{ok:!1,error:"Invalid FEN: move number must be a positive integer"};let n=parseInt(e[4],10);if(isNaN(n)||n<0)return{ok:!1,error:"Invalid FEN: half move counter number must be a non-negative integer"};if(!/^(-|[abcdefgh][36])$/.test(e[3]))return{ok:!1,error:"Invalid FEN: en-passant square is invalid"};if(/[^kKqQ-]/.test(e[2]))return{ok:!1,error:"Invalid FEN: castling availability is invalid"};if(!/^(w|b)$/.test(e[1]))return{ok:!1,error:"Invalid FEN: side-to-move is invalid"};let i=e[0].split("/");if(i.length!==8)return{ok:!1,error:"Invalid FEN: piece data does not contain 8 '/'-delimited rows"};for(let o=0;o<i.length;o++){let a=0,l=!1;for(let h=0;h<i[o].length;h++)if(wd(i[o][h])){if(l)return{ok:!1,error:"Invalid FEN: piece data is invalid (consecutive number)"};a+=parseInt(i[o][h],10),l=!0}else{if(!/^[prnbqkPRNBQK]$/.test(i[o][h]))return{ok:!1,error:"Invalid FEN: piece data is invalid (invalid piece)"};a+=1,l=!1}if(a!==8)return{ok:!1,error:"Invalid FEN: piece data is invalid (too many squares in rank)"}}if(e[3][1]=="3"&&e[1]=="w"||e[3][1]=="6"&&e[1]=="b")return{ok:!1,error:"Invalid FEN: illegal en-passant square"};let s=[{color:"white",regex:/K/g},{color:"black",regex:/k/g}];for(let{color:o,regex:a}of s){if(!a.test(e[0]))return{ok:!1,error:`Invalid FEN: missing ${o} king`};if((e[0].match(a)||[]).length>1)return{ok:!1,error:`Invalid FEN: too many ${o} kings`}}return Array.from(i[0]+i[7]).some(o=>o.toUpperCase()==="P")?{ok:!1,error:"Invalid FEN: some pawns are on the edge rows"}:{ok:!0}}function j_(r,e){let t=r.from,n=r.to,i=r.piece,s=0,o=0,a=0;for(let l=0,h=e.length;l<h;l++){let f=e[l].from,c=e[l].to,u=e[l].piece;i===u&&t!==f&&n===c&&(s++,Is(t)===Is(f)&&o++,yo(t)===yo(f)&&a++)}return s>0?o>0&&a>0?Vt(t):a>0?Vt(t).charAt(1):Vt(t).charAt(0):""}function rs(r,e,t,n,i,s=void 0,o=Ze.NORMAL){let a=Is(n);if(i===It&&(a===X_||a===Z_))for(let l=0;l<Sd.length;l++){let h=Sd[l];r.push({color:e,from:t,to:n,piece:i,captured:s,promotion:h,flags:o|Ze.PROMOTION})}else r.push({color:e,from:t,to:n,piece:i,captured:s,flags:o})}function bd(r){let e=r.charAt(0);return e>="a"&&e<="h"?r.match(/[a-h]\d.*[a-h]\d/)?void 0:It:(e=e.toLowerCase(),e==="o"?Ut:e)}function Zh(r){return r.replace(/=/,"").replace(/[+#]?[?!]*$/,"")}var Li=class{_board=new Array(128);_turn=tn;_header={};_kings={w:$t,b:$t};_epSquare=-1;_halfMoves=0;_moveNumber=0;_history=[];_comments={};_castling={w:0,b:0};_hash=0n;_positionCount=new Map;constructor(e=Xh,{skipValidation:t=!1}={}){this.load(e,{skipValidation:t})}clear({preserveHeaders:e=!1}={}){this._board=new Array(128),this._kings={w:$t,b:$t},this._turn=tn,this._castling={w:0,b:0},this._epSquare=$t,this._halfMoves=0,this._moveNumber=1,this._history=[],this._comments={},this._header=e?this._header:{...V_},this._hash=this._computeHash(),this._positionCount=new Map,this._header.SetUp=null,this._header.FEN=null}load(e,{skipValidation:t=!1,preserveHeaders:n=!1}={}){let i=e.split(/\s+/);if(i.length>=2&&i.length<6){let a=["-","-","0","1"];e=i.concat(a.slice(-(6-i.length))).join(" ")}if(i=e.split(/\s+/),!t){let{ok:a,error:l}=J_(e);if(!a)throw new Error(l)}let s=i[0],o=0;this.clear({preserveHeaders:n});for(let a=0;a<s.length;a++){let l=s.charAt(a);if(l==="/")o+=8;else if(wd(l))o+=parseInt(l,10);else{let h=l<"a"?tn:En;this._put({type:l.toLowerCase(),color:h},Vt(o)),o++}}this._turn=i[1],i[2].indexOf("K")>-1&&(this._castling.w|=Ze.KSIDE_CASTLE),i[2].indexOf("Q")>-1&&(this._castling.w|=Ze.QSIDE_CASTLE),i[2].indexOf("k")>-1&&(this._castling.b|=Ze.KSIDE_CASTLE),i[2].indexOf("q")>-1&&(this._castling.b|=Ze.QSIDE_CASTLE),this._epSquare=i[3]==="-"?$t:Ye[i[3]],this._halfMoves=parseInt(i[4],10),this._moveNumber=parseInt(i[5],10),this._hash=this._computeHash(),this._updateSetup(e),this._incPositionCount()}fen({forceEnpassantSquare:e=!1}={}){let t=0,n="";for(let o=Ye.a8;o<=Ye.h1;o++){if(this._board[o]){t>0&&(n+=t,t=0);let{color:a,type:l}=this._board[o];n+=a===tn?l.toUpperCase():l.toLowerCase()}else t++;o+1&136&&(t>0&&(n+=t),o!==Ye.h1&&(n+="/"),t=0,o+=8)}let i="";this._castling[tn]&Ze.KSIDE_CASTLE&&(i+="K"),this._castling[tn]&Ze.QSIDE_CASTLE&&(i+="Q"),this._castling[En]&Ze.KSIDE_CASTLE&&(i+="k"),this._castling[En]&Ze.QSIDE_CASTLE&&(i+="q"),i=i||"-";let s="-";if(this._epSquare!==$t)if(e)s=Vt(this._epSquare);else{let o=this._epSquare+(this._turn===tn?16:-16),a=[o+1,o-1];for(let l of a){if(l&136)continue;let h=this._turn;if(this._board[l]?.color===h&&this._board[l]?.type===It){this._makeMove({color:h,from:l,to:this._epSquare,piece:It,captured:It,flags:Ze.EP_CAPTURE});let f=!this._isKingAttacked(h);if(this._undoMove(),f){s=Vt(this._epSquare);break}}}}return[n,this._turn,i,s,this._halfMoves,this._moveNumber].join(" ")}_pieceKey(e){if(!this._board[e])return 0n;let{color:t,type:n}=this._board[e],i={w:0,b:1}[t],s={p:0,n:1,b:2,r:3,q:4,k:5}[n];return U_[i][s][e]}_epKey(){return this._epSquare===$t?0n:O_[this._epSquare&7]}_castlingKey(){let e=this._castling.w>>5|this._castling.b>>3;return z_[e]}_computeHash(){let e=0n;for(let t=Ye.a8;t<=Ye.h1;t++){if(t&136){t+=7;continue}this._board[t]&&(e^=this._pieceKey(t))}return e^=this._epKey(),e^=this._castlingKey(),this._turn==="b"&&(e^=qh),e}_updateSetup(e){this._history.length>0||(e!==Xh?(this._header.SetUp="1",this._header.FEN=e):(this._header.SetUp=null,this._header.FEN=null))}reset(){this.load(Xh)}get(e){return this._board[Ye[e]]}findPiece(e){let t=[];for(let n=Ye.a8;n<=Ye.h1;n++){if(n&136){n+=7;continue}!this._board[n]||this._board[n]?.color!==e.color||this._board[n].color===e.color&&this._board[n].type===e.type&&t.push(Vt(n))}return t}put({type:e,color:t},n){return this._put({type:e,color:t},n)?(this._updateCastlingRights(),this._updateEnPassantSquare(),this._updateSetup(this.fen()),!0):!1}_set(e,t){this._hash^=this._pieceKey(e),this._board[e]=t,this._hash^=this._pieceKey(e)}_put({type:e,color:t},n){if(q_.indexOf(e.toLowerCase())===-1||!(n in Ye))return!1;let i=Ye[n];if(e==Ut&&!(this._kings[t]==$t||this._kings[t]==i))return!1;let s=this._board[i];return s&&s.type===Ut&&(this._kings[s.color]=$t),this._set(i,{type:e,color:t}),e===Ut&&(this._kings[t]=i),!0}_clear(e){this._hash^=this._pieceKey(e),delete this._board[e]}remove(e){let t=this.get(e);return this._clear(Ye[e]),t&&t.type===Ut&&(this._kings[t.color]=$t),this._updateCastlingRights(),this._updateEnPassantSquare(),this._updateSetup(this.fen()),t}_updateCastlingRights(){this._hash^=this._castlingKey();let e=this._board[Ye.e1]?.type===Ut&&this._board[Ye.e1]?.color===tn,t=this._board[Ye.e8]?.type===Ut&&this._board[Ye.e8]?.color===En;(!e||this._board[Ye.a1]?.type!==xo||this._board[Ye.a1]?.color!==tn)&&(this._castling.w&=-65),(!e||this._board[Ye.h1]?.type!==xo||this._board[Ye.h1]?.color!==tn)&&(this._castling.w&=-33),(!t||this._board[Ye.a8]?.type!==xo||this._board[Ye.a8]?.color!==En)&&(this._castling.b&=-65),(!t||this._board[Ye.h8]?.type!==xo||this._board[Ye.h8]?.color!==En)&&(this._castling.b&=-33),this._hash^=this._castlingKey()}_updateEnPassantSquare(){if(this._epSquare===$t)return;let e=this._epSquare+(this._turn===tn?-16:16),t=this._epSquare+(this._turn===tn?16:-16),n=[t+1,t-1];if(this._board[e]!==null||this._board[this._epSquare]!==null||this._board[t]?.color!==vo(this._turn)||this._board[t]?.type!==It){this._hash^=this._epKey(),this._epSquare=$t;return}let i=s=>!(s&136)&&this._board[s]?.color===this._turn&&this._board[s]?.type===It;n.some(i)||(this._hash^=this._epKey(),this._epSquare=$t)}_attacked(e,t,n){let i=[];for(let s=Ye.a8;s<=Ye.h1;s++){if(s&136){s+=7;continue}if(this._board[s]===void 0||this._board[s].color!==e)continue;let o=this._board[s],a=s-t;if(a===0)continue;let l=a+119;if(H_[l]&W_[o.type]){if(o.type===It){if(a>0&&o.color===tn||a<=0&&o.color===En)if(n)i.push(Vt(s));else return!0;continue}if(o.type==="n"||o.type==="k")if(n){i.push(Vt(s));continue}else return!0;let h=G_[l],f=s+h,c=!1;for(;f!==t;){if(this._board[f]!=null){c=!0;break}f+=h}if(!c)if(n){i.push(Vt(s));continue}else return!0}}return n?i:!1}attackers(e,t){return t?this._attacked(t,Ye[e],!0):this._attacked(this._turn,Ye[e],!0)}_isKingAttacked(e){let t=this._kings[e];return t===-1?!1:this._attacked(vo(e),t)}hash(){return this._hash.toString(16)}isAttacked(e,t){return this._attacked(t,Ye[e])}isCheck(){return this._isKingAttacked(this._turn)}inCheck(){return this.isCheck()}isCheckmate(){return this.isCheck()&&this._moves().length===0}isStalemate(){return!this.isCheck()&&this._moves().length===0}isInsufficientMaterial(){let e={b:0,n:0,r:0,q:0,k:0,p:0},t=[],n=0,i=0;for(let s=Ye.a8;s<=Ye.h1;s++){if(i=(i+1)%2,s&136){s+=7;continue}let o=this._board[s];o&&(e[o.type]=o.type in e?e[o.type]+1:1,o.type===zl&&t.push(i),n++)}if(n===2)return!0;if(n===3&&(e[zl]===1||e[Kh]===1))return!0;if(n===e[zl]+2){let s=0,o=t.length;for(let a=0;a<o;a++)s+=t[a];if(s===0||s===o)return!0}return!1}isThreefoldRepetition(){return this._getPositionCount(this._hash)>=3}isDrawByFiftyMoves(){return this._halfMoves>=100}isDraw(){return this.isDrawByFiftyMoves()||this.isStalemate()||this.isInsufficientMaterial()||this.isThreefoldRepetition()}isGameOver(){return this.isCheckmate()||this.isDraw()}moves({verbose:e=!1,square:t=void 0,piece:n=void 0}={}){let i=this._moves({square:t,piece:n});return e?i.map(s=>new vr(this,s)):i.map(s=>this._moveToSan(s,i))}_moves({legal:e=!0,piece:t=void 0,square:n=void 0}={}){let i=n?n.toLowerCase():void 0,s=t?.toLowerCase(),o=[],a=this._turn,l=vo(a),h=Ye.a8,f=Ye.h1,c=!1;if(i)if(i in Ye)h=f=Ye[i],c=!0;else return[];for(let d=h;d<=f;d++){if(d&136){d+=7;continue}if(!this._board[d]||this._board[d].color===l)continue;let{type:p}=this._board[d],v;if(p===It){if(s&&s!==p)continue;v=d+$h[a][0],this._board[v]||(rs(o,a,d,v,It),v=d+$h[a][1],K_[a]===Is(d)&&!this._board[v]&&rs(o,a,d,v,It,void 0,Ze.BIG_PAWN));for(let g=2;g<4;g++)v=d+$h[a][g],!(v&136)&&(this._board[v]?.color===l?rs(o,a,d,v,It,this._board[v].type,Ze.CAPTURE):v===this._epSquare&&rs(o,a,d,v,It,It,Ze.EP_CAPTURE))}else{if(s&&s!==p)continue;for(let g=0,m=Md[p].length;g<m;g++){let _=Md[p][g];for(v=d;v+=_,!(v&136);){if(!this._board[v])rs(o,a,d,v,p);else{if(this._board[v].color===a)break;rs(o,a,d,v,p,this._board[v].type,Ze.CAPTURE);break}if(p===Kh||p===Ut)break}}}}if((s===void 0||s===Ut)&&(!c||f===this._kings[a])){if(this._castling[a]&Ze.KSIDE_CASTLE){let d=this._kings[a],p=d+2;!this._board[d+1]&&!this._board[p]&&!this._attacked(l,this._kings[a])&&!this._attacked(l,d+1)&&!this._attacked(l,p)&&rs(o,a,this._kings[a],p,Ut,void 0,Ze.KSIDE_CASTLE)}if(this._castling[a]&Ze.QSIDE_CASTLE){let d=this._kings[a],p=d-2;!this._board[d-1]&&!this._board[d-2]&&!this._board[d-3]&&!this._attacked(l,this._kings[a])&&!this._attacked(l,d-1)&&!this._attacked(l,p)&&rs(o,a,this._kings[a],p,Ut,void 0,Ze.QSIDE_CASTLE)}}if(!e||this._kings[a]===-1)return o;let u=[];for(let d=0,p=o.length;d<p;d++)this._makeMove(o[d]),this._isKingAttacked(a)||u.push(o[d]),this._undoMove();return u}move(e,{strict:t=!1}={}){let n=null;if(typeof e=="string")n=this._moveFromSan(e,t);else if(e===null)n=this._moveFromSan(Yh,t);else if(typeof e=="object"){let s=this._moves();for(let o=0,a=s.length;o<a;o++)if(e.from===Vt(s[o].from)&&e.to===Vt(s[o].to)&&(!("promotion"in s[o])||e.promotion===s[o].promotion)){n=s[o];break}}if(!n)throw typeof e=="string"?new Error(`Invalid move: ${e}`):new Error(`Invalid move: ${JSON.stringify(e)}`);if(this.isCheck()&&n.flags&Ze.NULL_MOVE)throw new Error("Null move not allowed when in check");let i=new vr(this,n);return this._makeMove(n),this._incPositionCount(),i}_push(e){this._history.push({move:e,kings:{b:this._kings.b,w:this._kings.w},turn:this._turn,castling:{b:this._castling.b,w:this._castling.w},epSquare:this._epSquare,halfMoves:this._halfMoves,moveNumber:this._moveNumber})}_movePiece(e,t){this._hash^=this._pieceKey(e),this._board[t]=this._board[e],delete this._board[e],this._hash^=this._pieceKey(t)}_makeMove(e){let t=this._turn,n=vo(t);if(this._push(e),e.flags&Ze.NULL_MOVE){t===En&&this._moveNumber++,this._halfMoves++,this._turn=n,this._epSquare=$t;return}if(this._hash^=this._epKey(),this._hash^=this._castlingKey(),e.captured&&(this._hash^=this._pieceKey(e.to)),this._movePiece(e.from,e.to),e.flags&Ze.EP_CAPTURE&&(this._turn===En?this._clear(e.to-16):this._clear(e.to+16)),e.promotion&&(this._clear(e.to),this._set(e.to,{type:e.promotion,color:t})),this._board[e.to].type===Ut){if(this._kings[t]=e.to,e.flags&Ze.KSIDE_CASTLE){let i=e.to-1,s=e.to+1;this._movePiece(s,i)}else if(e.flags&Ze.QSIDE_CASTLE){let i=e.to+1,s=e.to-2;this._movePiece(s,i)}this._castling[t]=0}if(this._castling[t]){for(let i=0,s=ss[t].length;i<s;i++)if(e.from===ss[t][i].square&&this._castling[t]&ss[t][i].flag){this._castling[t]^=ss[t][i].flag;break}}if(this._castling[n]){for(let i=0,s=ss[n].length;i<s;i++)if(e.to===ss[n][i].square&&this._castling[n]&ss[n][i].flag){this._castling[n]^=ss[n][i].flag;break}}if(this._hash^=this._castlingKey(),e.flags&Ze.BIG_PAWN){let i;t===En?i=e.to-16:i=e.to+16,!(e.to-1&136)&&this._board[e.to-1]?.type===It&&this._board[e.to-1]?.color===n||!(e.to+1&136)&&this._board[e.to+1]?.type===It&&this._board[e.to+1]?.color===n?(this._epSquare=i,this._hash^=this._epKey()):this._epSquare=$t}else this._epSquare=$t;e.piece===It?this._halfMoves=0:e.flags&(Ze.CAPTURE|Ze.EP_CAPTURE)?this._halfMoves=0:this._halfMoves++,t===En&&this._moveNumber++,this._turn=n,this._hash^=qh}undo(){let e=this._hash,t=this._undoMove();if(t){let n=new vr(this,t);return this._decPositionCount(e),n}return null}_undoMove(){let e=this._history.pop();if(e===void 0)return null;this._hash^=this._epKey(),this._hash^=this._castlingKey();let t=e.move;this._kings=e.kings,this._turn=e.turn,this._castling=e.castling,this._epSquare=e.epSquare,this._halfMoves=e.halfMoves,this._moveNumber=e.moveNumber,this._hash^=this._epKey(),this._hash^=this._castlingKey(),this._hash^=qh;let n=this._turn,i=vo(n);if(t.flags&Ze.NULL_MOVE)return t;if(this._movePiece(t.to,t.from),t.piece&&(this._clear(t.from),this._set(t.from,{type:t.piece,color:n})),t.captured)if(t.flags&Ze.EP_CAPTURE){let s;n===En?s=t.to-16:s=t.to+16,this._set(s,{type:It,color:i})}else this._set(t.to,{type:t.captured,color:i});if(t.flags&(Ze.KSIDE_CASTLE|Ze.QSIDE_CASTLE)){let s,o;t.flags&Ze.KSIDE_CASTLE?(s=t.to+1,o=t.to-1):(s=t.to-2,o=t.to+1),this._movePiece(o,s)}return t}pgn({newline:e=`
`,maxWidth:t=0}={}){let n=[],i=!1;for(let u in this._header)this._header[u]&&n.push(`[${u} "${this._header[u]}"]`+e),i=!0;i&&this._history.length&&n.push(e);let s=u=>{let d=this._comments[this.fen()];if(typeof d<"u"){let p=u.length>0?" ":"";u=`${u}${p}{${d}}`}return u},o=[];for(;this._history.length>0;)o.push(this._undoMove());let a=[],l="";for(o.length===0&&a.push(s(""));o.length>0;){l=s(l);let u=o.pop();if(!u)break;if(!this._history.length&&u.color==="b"){let d=`${this._moveNumber}. ...`;l=l?`${l} ${d}`:d}else u.color==="w"&&(l.length&&a.push(l),l=this._moveNumber+".");l=l+" "+this._moveToSan(u,this._moves({legal:!0})),this._makeMove(u)}if(l.length&&a.push(s(l)),a.push(this._header.Result||"*"),t===0)return n.join("")+a.join(" ");let h=function(){return n.length>0&&n[n.length-1]===" "?(n.pop(),!0):!1},f=function(u,d){for(let p of d.split(" "))if(p){if(u+p.length>t){for(;h();)u--;n.push(e),u=0}n.push(p),u+=p.length,n.push(" "),u++}return h()&&u--,u},c=0;for(let u=0;u<a.length;u++){if(c+a[u].length>t&&a[u].includes("{")){c=f(c,a[u]);continue}c+a[u].length>t&&u!==0?(n[n.length-1]===" "&&n.pop(),n.push(e),c=0):u!==0&&(n.push(" "),c++),n.push(a[u]),c+=a[u].length}return n.join("")}header(...e){for(let t=0;t<e.length;t+=2)typeof e[t]=="string"&&typeof e[t+1]=="string"&&(this._header[e[t]]=e[t+1]);return this._header}setHeader(e,t){return this._header[e]=t??Jh[e]??null,this.getHeaders()}removeHeader(e){return e in this._header?(this._header[e]=Jh[e]||null,!0):!1}getHeaders(){let e={};for(let[t,n]of Object.entries(this._header))n!==null&&(e[t]=n);return e}loadPgn(e,{strict:t=!1,newlineChar:n=`\r?
`}={}){n!==`\r?
`&&(e=e.replace(new RegExp(n,"g"),`
`));let i=F_(e);this.reset();let s=i.headers,o="";for(let h in s)h.toLowerCase()==="fen"&&(o=s[h]),this.header(h,s[h]);if(!t)o&&this.load(o,{preserveHeaders:!0});else if(s.SetUp==="1"){if(!("FEN"in s))throw new Error("Invalid PGN: FEN tag must be supplied with SetUp tag");this.load(s.FEN,{preserveHeaders:!0})}let a=i.root;for(;a;){if(a.move){let h=this._moveFromSan(a.move,t);if(h==null)throw new Error(`Invalid move in PGN: ${a.move}`);this._makeMove(h),this._incPositionCount()}a.comment!==void 0&&(this._comments[this.fen()]=a.comment),a=a.variations[0]}let l=i.result;l&&Object.keys(this._header).length&&this._header.Result!==l&&this.setHeader("Result",l)}_moveToSan(e,t){let n="";if(e.flags&Ze.KSIDE_CASTLE)n="O-O";else if(e.flags&Ze.QSIDE_CASTLE)n="O-O-O";else{if(e.flags&Ze.NULL_MOVE)return Yh;if(e.piece!==It){let i=j_(e,t);n+=e.piece.toUpperCase()+i}e.flags&(Ze.CAPTURE|Ze.EP_CAPTURE)&&(e.piece===It&&(n+=Vt(e.from)[0]),n+="x"),n+=Vt(e.to),e.promotion&&(n+="="+e.promotion.toUpperCase())}return this._makeMove(e),this.isCheck()&&(this.isCheckmate()?n+="#":n+="+"),this._undoMove(),n}_moveFromSan(e,t=!1){let n=Zh(e);if(t||(n==="0-0"?n="O-O":n==="0-0-0"&&(n="O-O-O")),n==Yh)return{color:this._turn,from:0,to:0,piece:"k",flags:Ze.NULL_MOVE};let i=bd(n),s=this._moves({legal:!0,piece:i});for(let u=0,d=s.length;u<d;u++)if(n===Zh(this._moveToSan(s[u],s)))return s[u];if(t)return null;let o,a,l,h,f,c=!1;if(a=n.match(/([pnbrqkPNBRQK])?([a-h][1-8])x?-?([a-h][1-8])([qrbnQRBN])?/),a?(o=a[1],l=a[2],h=a[3],f=a[4],l.length==1&&(c=!0)):(a=n.match(/([pnbrqkPNBRQK])?([a-h]?[1-8]?)x?-?([a-h][1-8])([qrbnQRBN])?/),a&&(o=a[1],l=a[2],h=a[3],f=a[4],l.length==1&&(c=!0))),i=bd(n),s=this._moves({legal:!0,piece:o||i}),!h)return null;for(let u=0,d=s.length;u<d;u++)if(l){if((!o||o.toLowerCase()==s[u].piece)&&Ye[l]==s[u].from&&Ye[h]==s[u].to&&(!f||f.toLowerCase()==s[u].promotion))return s[u];if(c){let p=Vt(s[u].from);if((!o||o.toLowerCase()==s[u].piece)&&Ye[h]==s[u].to&&(l==p[0]||l==p[1])&&(!f||f.toLowerCase()==s[u].promotion))return s[u]}}else if(n===Zh(this._moveToSan(s[u],s)).replace("x",""))return s[u];return null}ascii(){let e=`   +------------------------+
`;for(let t=Ye.a8;t<=Ye.h1;t++){if(yo(t)===0&&(e+=" "+"87654321"[Is(t)]+" |"),this._board[t]){let n=this._board[t].type,s=this._board[t].color===tn?n.toUpperCase():n.toLowerCase();e+=" "+s+" "}else e+=" . ";t+1&136&&(e+=`|
`,t+=8)}return e+=`   +------------------------+
`,e+="     a  b  c  d  e  f  g  h",e}perft(e){let t=this._moves({legal:!1}),n=0,i=this._turn;for(let s=0,o=t.length;s<o;s++)this._makeMove(t[s]),this._isKingAttacked(i)||(e-1>0?n+=this.perft(e-1):n++),this._undoMove();return n}setTurn(e){return this._turn==e?!1:(this.move("--"),!0)}turn(){return this._turn}board(){let e=[],t=[];for(let n=Ye.a8;n<=Ye.h1;n++)this._board[n]==null?t.push(null):t.push({square:Vt(n),type:this._board[n].type,color:this._board[n].color}),n+1&136&&(e.push(t),t=[],n+=8);return e}squareColor(e){if(e in Ye){let t=Ye[e];return(Is(t)+yo(t))%2===0?"light":"dark"}return null}history({verbose:e=!1}={}){let t=[],n=[];for(;this._history.length>0;)t.push(this._undoMove());for(;;){let i=t.pop();if(!i)break;e?n.push(new vr(this,i)):n.push(this._moveToSan(i,this._moves())),this._makeMove(i)}return n}_getPositionCount(e){return this._positionCount.get(e)??0}_incPositionCount(){this._positionCount.set(this._hash,(this._positionCount.get(this._hash)??0)+1)}_decPositionCount(e){let t=this._positionCount.get(e)??0;t===1?this._positionCount.delete(e):this._positionCount.set(e,t-1)}_pruneComments(){let e=[],t={},n=i=>{i in this._comments&&(t[i]=this._comments[i])};for(;this._history.length>0;)e.push(this._undoMove());for(n(this.fen());;){let i=e.pop();if(!i)break;this._makeMove(i),n(this.fen())}this._comments=t}getComment(){return this._comments[this.fen()]}setComment(e){this._comments[this.fen()]=e.replace("{","[").replace("}","]")}deleteComment(){return this.removeComment()}removeComment(){let e=this._comments[this.fen()];return delete this._comments[this.fen()],e}getComments(){return this._pruneComments(),Object.keys(this._comments).map(e=>({fen:e,comment:this._comments[e]}))}deleteComments(){return this.removeComments()}removeComments(){return this._pruneComments(),Object.keys(this._comments).map(e=>{let t=this._comments[e];return delete this._comments[e],{fen:e,comment:t}})}setCastlingRights(e,t){for(let i of[Ut,os])t[i]!==void 0&&(t[i]?this._castling[e]|=Ul[i]:this._castling[e]&=~Ul[i]);this._updateCastlingRights();let n=this.getCastlingRights(e);return(t[Ut]===void 0||t[Ut]===n[Ut])&&(t[os]===void 0||t[os]===n[os])}getCastlingRights(e){return{[Ut]:(this._castling[e]&Ul[Ut])!==0,[os]:(this._castling[e]&Ul[os])!==0}}moveNumber(){return this._moveNumber}};var jh=rc(Ml(),1);var Q_="maroon-games-2.0.0",ei={width:1e3,height:2e3,radius:27,pockets:[[0,0],[1e3,0],[0,1e3],[1e3,1e3],[0,2e3],[1e3,2e3]]},eM=[{id:0,x:0,z:-.45},{id:1,x:-.083,z:-.62},{id:2,x:.083,z:-.62},{id:3,x:-.166,z:-.79},{id:4,x:0,z:-.79},{id:5,x:.166,z:-.79}],Ad=r=>JSON.parse(JSON.stringify(r)),Yt=r=>Math.round(r*1e4)/1e4,Vl=r=>r>=1&&r<=7?"solids":r>=9&&r<=15?"stripes":null,_o=(r,e,t)=>typeof r=="number"&&Number.isFinite(r)&&r>=e&&r<=t,Ht=r=>{throw new Error(r)};function tM(r,e){let t=r.isGameOver(),n=r.turn()==="w"?0:1,i=r.isCheckmate()?1-n:null;return{...e,fen:r.fen(),pgn:r.pgn(),turn:n,winner:i,finished:t,legal:r.moves({verbose:!0}).map(s=>({from:s.from,to:s.to,promotion:s.promotion})),status:i!==null?`Player ${i+1} wins by checkmate.`:t?"Draw.":`Player ${n+1} to move${r.isCheck()?" \xB7 check":""}.`}}function Mo(r,e,t){(!e||e.kind!==r||e.rules!==Q_)&&Ht("Unsupported game version."),(e.winner!==null||e.finished)&&Ht("This game has finished."),(!t||typeof t!="object")&&Ht("Missing turn.");let n=r==="chess"?["from","to","promotion"]:r==="pool"?["aim","power","spin","cue"]:["aim","power","bounce"];if(Object.keys(t).some(i=>!n.includes(i))&&Ht("Unsupported turn input."),t.cue&&(typeof t.cue!="object"||Object.keys(t.cue).some(i=>!["x","y"].includes(i)))&&Ht("Invalid cue position."),r==="chess"){(!/^[a-h][1-8]$/.test(t.from)||!/^[a-h][1-8]$/.test(t.to)||!["q","r","b","n"].includes(t.promotion||"q"))&&Ht("Choose a legal chess move.");return}(!_o(t.aim,-Math.PI,Math.PI)||!_o(t.power,.03,1))&&Ht("Aim or power is outside the allowed range."),r==="pool"?(_o(t.spin??0,-1,1)||Ht("Spin is outside the allowed range."),t.cue&&(e.ballInHand||Ht("The cue ball cannot be moved now."),(!_o(t.cue.x,ei.radius+8,ei.width-ei.radius-8)||!_o(t.cue.y,ei.radius+8,ei.height-ei.radius-8))&&Ht("Place the cue ball on the felt."),e.balls.some(i=>i.id!==0&&!i.pocketed&&Math.hypot(i.x-t.cue.x,i.y-t.cue.y)<ei.radius*2+1)&&Ht("The cue ball overlaps another ball."),ei.pockets.some(([i,s])=>Math.hypot(i-t.cue.x,s-t.cue.y)<80)&&Ht("Place the cue ball away from a pocket."))):r==="pong"&&(Math.abs(t.aim)>.42&&Ht("Aim at the table."),t.bounce!==void 0&&typeof t.bounce!="boolean"&&Ht("Invalid throw type."))}function Hl(r,e,t){if(Mo(r,e,t),r==="pool")return nM(e,t);if(r==="pong")return iM(e,t);let n=new Li;e.pgn?n.loadPgn(e.pgn):n.load(e.fen);let i;try{i=n.move({from:t.from,to:t.to,promotion:t.promotion||"q"})}catch{Ht("That chess move is not legal.")}return i||Ht("That chess move is not legal."),{state:tM(n,{...e,shots:e.shots+1}),replay:{kind:"chess",move:{from:t.from,to:t.to},notation:i.san}}}function nM(r,e){let{Engine:t,Bodies:n,Body:i,Composite:s,Events:o}=jh.default;jh.default.Common._nextId=0;let a=t.create({gravity:{x:0,y:0,scale:0},positionIterations:10,velocityIterations:10,enableSleeping:!1}),l=Ad(r),h=ei.radius;e.cue&&(l.balls[0].x=e.cue.x,l.balls[0].y=e.cue.y);let f=new Map,c=[],u=(C,P,N,z,O=0)=>{let K=n.rectangle(C,P,N,z,{isStatic:!0,restitution:.87,friction:.09,angle:O,label:"cushion",chamfer:{radius:8}});return c.push(K),K};for(let C of[-24,1024])for(let P of[500,1500])u(C,P,48,850);for(let C of[-24,2024])u(500,C,850,48);for(let[C,P,N,z]of[[30,40,1,1],[970,40,-1,1],[30,1960,1,-1],[970,1960,-1,-1]])u(C,P,42,18,N*z*Math.PI/4);s.add(a.world,c);for(let C of l.balls)if(!C.pocketed){let P=n.circle(C.x,C.y,h,{restitution:.96,friction:.018,frictionStatic:.02,frictionAir:.0055,density:.002,label:`ball:${C.id}`},32);f.set(C.id,P),s.add(a.world,P)}let d=f.get(0);d||Ht("Cue ball missing.");let p=3+e.power*30;i.setVelocity(d,{x:Math.sin(e.aim)*p,y:-Math.cos(e.aim)*p}),i.setAngularVelocity(d,(e.spin||0)*.25);let v=[],g=[],m=[],_=null,x=!1,y=0,S=0;o.on(a,"collisionStart",C=>{for(let P of C.pairs){let N=[P.bodyA.label,P.bodyB.label];if(_===null&&N.includes("ball:0")){let z=N.find(O=>O.startsWith("ball:")&&O!=="ball:0");z&&(_=Number(z.split(":")[1]))}}for(let P of C.pairs){(P.bodyA.label==="cushion"||P.bodyB.label==="cushion")&&_!==null&&(x=!0);let N=Math.hypot(P.bodyA.velocity.x-P.bodyB.velocity.x,P.bodyA.velocity.y-P.bodyB.velocity.y);N>.25&&g.length<80&&g.push({t:Yt(y),type:"hit",strength:Math.min(1,N/20)})}});function M(){m.push(l.balls.flatMap(C=>{let P=f.get(C.id);return[C.id,P?Yt(P.position.x):C.x,P?Yt(P.position.y):C.y,P?1:0]}))}M();for(let C=0;C<2400;C++){y=(C+1)/240,t.update(a,1e3/240);for(let[N,z]of f){let O=Math.hypot(z.velocity.x,z.velocity.y);if(O>.015){let ee=Math.max(0,O-.0035)/O;i.setVelocity(z,{x:z.velocity.x*ee,y:z.velocity.y*ee})}if(ei.pockets.some(([ee,oe])=>Math.hypot(z.position.x-ee,z.position.y-oe)<58)){let ee=l.balls.find(oe=>oe.id===N);ee.x=Yt(z.position.x),ee.y=Yt(z.position.y),ee.pocketed=!0,v.push(N),g.push({t:Yt(y),type:"pocket",id:N}),s.remove(a.world,z),f.delete(N)}}if(C%8===7&&M(),S=[...f.values()].some(N=>Math.hypot(N.velocity.x,N.velocity.y)>.07)?0:S+1,S>=36&&C>24)break}for(let[C,P]of f){let N=l.balls.find(z=>z.id===C);N.x=Yt(Math.min(1e3-h,Math.max(h,P.position.x))),N.y=Yt(Math.min(2e3-h,Math.max(h,P.position.y)))}t.clear(a),s.clear(a.world,!1);let E=r.groups[r.turn],A=r.balls.filter(C=>!C.pocketed&&Vl(C.id)===E&&E!==null).map(C=>C.id),b=E?A.length?A:[8]:r.balls.filter(C=>!C.pocketed&&C.id!==0&&C.id!==8).map(C=>C.id),w=v.includes(0),T=_===null||!b.includes(_),F=!x&&v.length===0,D=w||T||F;if(l.shots++,l.ballInHand=!1,v.includes(8)&&(r.shots===0?(Ed(l,8,500,570),g.push({t:Yt(y),type:"spot",id:8})):(l.winner=!D&&b.length===1&&b[0]===8?r.turn:1-r.turn,l.status=l.winner===r.turn?`Player ${l.winner+1} wins. Clean finish!`:`Player ${l.winner+1} wins \xB7 ${w?"scratch on the 8":"8 ball pocketed too early or illegally"}.`)),l.winner===null){if(!E&&!D){let P=v.map(Vl).find(Boolean);P&&(l.groups[l.turn]=P,l.groups[1-l.turn]=P==="solids"?"stripes":"solids")}let C=v.some(P=>Vl(P)&&Vl(P)===l.groups[l.turn]);D?(l.turn=1-l.turn,l.ballInHand=!0,Ed(l,0,500,1500),l.status=`${w?"Scratch":T?_===null?"No ball contacted":"Wrong ball hit first":"No ball reached a cushion"}. Player ${l.turn+1} has ball in hand.`):C?l.status=`Nice shot. Player ${l.turn+1} goes again.`:(l.turn=1-l.turn,l.status=`Player ${l.turn+1} to shoot.`)}return{state:l,replay:{kind:"pool",fps:30,frames:m,events:g,duration:Yt(y),sunk:v,firstContact:_}}}function Ed(r,e,t,n){let i=r.balls.find(s=>s.id===e);if(i){for(let s=0;s<400;s++){let o=s===0?t:80+s%15*60,a=s===0?n:100+Math.floor(s/15)*65;if(a<1920&&r.balls.every(l=>l.id===e||l.pocketed||Math.hypot(l.x-o,l.y-a)>ei.radius*2+2)){i.x=o,i.y=a,i.pocketed=!1;return}}Ht("Unable to place the ball.")}}function iM(r,e){let t=Ad(r),n=new is({gravity:new R(0,-9.81,0)});n.broadphase=new ns(n),n.solver.iterations=12;let i=new kt("pingpong"),s=new kt("table"),o=new kt("cup");n.addContactMaterial(new an(i,s,{friction:.12,restitution:.78})),n.addContactMaterial(new an(i,o,{friction:.18,restitution:.48}));let a=new Xe({mass:0,material:s,shape:new On(new R(.5,.04,1.13)),position:new R(0,-.04,0)});n.addBody(a);let l=eM.filter(_=>!t.removed[t.turn].includes(_.id));for(let _ of l){let x=new Xe({mass:0,material:o,position:new R(_.x,0,_.z)});for(let y=0;y<16;y++){let S=y*Math.PI*2/16,M=new Pt;M.setFromAxisAngle(new R(0,1,0),-S),x.addShape(new On(new R(.004,.073,.014)),new R(Math.cos(S)*.064,.073,Math.sin(S)*.064),M),x.addShape(new Qn(.0045),new R(Math.cos(S)*.069,.148,Math.sin(S)*.069))}n.addBody(x)}let h=new Xe({mass:.0027,material:i,shape:new Qn(.02),position:new R(0,.23,1.02),linearDamping:.012,angularDamping:.1}),f=e.bounce?3+e.power*2.3:1.75+e.power*1.7,c=e.bounce?.65+e.power*.7:2.55+e.power*.9;h.velocity.set(Math.sin(e.aim)*f,c,-Math.cos(e.aim)*f),n.addBody(h);let u=[],d=[],p=null,v=0,g=0;h.addEventListener("collide",_=>{_.body===a?(g++,d.push({t:Yt(v),type:"bounce"})):d.length<20&&d.push({t:Yt(v),type:"rim"})}),u.push([0,.23,1.02]);for(let _=0;_<960;_++){if(v=(_+1)/240,n.step(1/240),_%4===3&&u.push([Yt(h.position.x),Yt(h.position.y),Yt(h.position.z)]),h.velocity.y<0&&h.position.y<.112&&h.position.y>.03){let x=l.find(y=>Math.hypot(h.position.x-y.x,h.position.z-y.z)<.042);if(x){p=x.id,d.push({t:Yt(v),type:"cup",id:p}),u.push([x.x,.035,x.z]);break}}if(h.position.y<-.6||Math.abs(h.position.z)>2||Math.abs(h.position.x)>1.2||v>1.8&&h.velocity.length()<.035)break}let m=t.turn;return t.shots++,p!==null&&t.removed[m].push(p),t.removed[m].length===6?(t.winner=m,t.status=`Player ${m+1} wins. Six cups cleared!`):(t.turn=1-m,t.status=p!==null?`Cup sunk! Player ${t.turn+1}, your throw.`:`${g?"Off the table.":"Just missed."} Player ${t.turn+1}, your throw.`),{state:t,replay:{kind:"pong",fps:60,frames:u,events:d,duration:Yt(v),hit:p,bounces:g,player:m}}}var Qh=rc(Ml(),1);var yr={wallRestitution:.1,bottomRestitution:0},sM={baseRadius:.044,topRadius:.065,bottomTop:.012,top:.146,thickness:.003,segments:24};function Gl(r,e,t,n){let{baseRadius:i,topRadius:s,bottomTop:o,top:a,thickness:l,segments:h}=sM,f=new Xe({mass:0,material:t,position:new R(e.x,0,e.z)}),c=a-o,u=s-i,d=Math.atan2(u,c),p=(i+s)/2+l;for(let g=0;g<h;g++){let m=g*Math.PI*2/h,_=new Pt;_.setFromAxisAngle(new R(0,1,0),-m);let x=new Pt;x.setFromAxisAngle(new R(0,0,1),-d);let y=_.mult(x);f.addShape(new On(new R(l,Math.hypot(c,u)/2,s*Math.tan(Math.PI/h)*1.04)),new R(Math.cos(m)*p,(a+o)/2,Math.sin(m)*p),y),f.addShape(new Qn(.0035),new R(Math.cos(m)*.069,.149,Math.sin(m)*.069))}r.addBody(f);let v=new Xe({mass:0,material:n,shape:new Dl(i,i,.008,h),position:new R(e.x,o-.004,e.z)});return r.addBody(v),v}var rM="maroon-games-2.1.0",ti={width:1e3,height:2e3,radius:27,pockets:[[0,0],[1e3,0],[0,1e3],[1e3,1e3],[0,2e3],[1e3,2e3]]},oM=[{id:0,x:0,z:-.45},{id:1,x:-.083,z:-.62},{id:2,x:.083,z:-.62},{id:3,x:-.166,z:-.79},{id:4,x:0,z:-.79},{id:5,x:.166,z:-.79}],Cd=r=>JSON.parse(JSON.stringify(r)),Nt=r=>Math.round(r*1e4)/1e4,Wl=r=>r>=1&&r<=7?"solids":r>=9&&r<=15?"stripes":null,So=(r,e,t)=>typeof r=="number"&&Number.isFinite(r)&&r>=e&&r<=t,Gt=r=>{throw new Error(r)};function aM(r,e){let t=r.isGameOver(),n=r.turn()==="w"?0:1,i=r.isCheckmate()?1-n:null;return{...e,fen:r.fen(),pgn:r.pgn(),turn:n,winner:i,finished:t,legal:r.moves({verbose:!0}).map(s=>({from:s.from,to:s.to,promotion:s.promotion})),status:i!==null?`Player ${i+1} wins by checkmate.`:t?"Draw.":`Player ${n+1} to move${r.isCheck()?" \xB7 check":""}.`}}function eu(r,e,t){if(e?.rules==="maroon-games-2.0.0")return Mo(r,e,t);(!e||e.kind!==r||e.rules!==rM)&&Gt("Unsupported game version."),(e.winner!==null||e.finished)&&Gt("This game has finished."),(!t||typeof t!="object")&&Gt("Missing turn.");let n=r==="chess"?["from","to","promotion"]:r==="pool"?["aim","power","spin","cue"]:["aim","power","bounce"];if(Object.keys(t).some(i=>!n.includes(i))&&Gt("Unsupported turn input."),t.cue&&(typeof t.cue!="object"||Object.keys(t.cue).some(i=>!["x","y"].includes(i)))&&Gt("Invalid cue position."),r==="chess"){(!/^[a-h][1-8]$/.test(t.from)||!/^[a-h][1-8]$/.test(t.to)||!["q","r","b","n"].includes(t.promotion||"q"))&&Gt("Choose a legal chess move.");return}(!So(t.aim,-Math.PI,Math.PI)||!So(t.power,.03,1))&&Gt("Aim or power is outside the allowed range."),r==="pool"?(So(t.spin??0,-1,1)||Gt("Spin is outside the allowed range."),t.cue&&(e.ballInHand||Gt("The cue ball cannot be moved now."),(!So(t.cue.x,ti.radius+8,ti.width-ti.radius-8)||!So(t.cue.y,ti.radius+8,ti.height-ti.radius-8))&&Gt("Place the cue ball on the felt."),e.balls.some(i=>i.id!==0&&!i.pocketed&&Math.hypot(i.x-t.cue.x,i.y-t.cue.y)<ti.radius*2+1)&&Gt("The cue ball overlaps another ball."),ti.pockets.some(([i,s])=>Math.hypot(i-t.cue.x,s-t.cue.y)<80)&&Gt("Place the cue ball away from a pocket."))):r==="pong"&&(Math.abs(t.aim)>.42&&Gt("Aim at the table."),t.bounce!==void 0&&typeof t.bounce!="boolean"&&Gt("Invalid throw type."))}function Rd(r,e,t){if(e?.rules==="maroon-games-2.0.0")return Hl(r,e,t);if(eu(r,e,t),r==="pool")return lM(e,t);if(r==="pong")return cM(e,t);let n=new Li;e.pgn?n.loadPgn(e.pgn):n.load(e.fen);let i;try{i=n.move({from:t.from,to:t.to,promotion:t.promotion||"q"})}catch{Gt("That chess move is not legal.")}return i||Gt("That chess move is not legal."),{state:aM(n,{...e,shots:e.shots+1}),replay:{kind:"chess",move:{from:t.from,to:t.to},notation:i.san}}}function lM(r,e){let{Engine:t,Bodies:n,Body:i,Composite:s,Events:o}=Qh.default;Qh.default.Common._nextId=0;let a=t.create({gravity:{x:0,y:0,scale:0},positionIterations:10,velocityIterations:10,enableSleeping:!1}),l=Cd(r),h=ti.radius;e.cue&&(l.balls[0].x=e.cue.x,l.balls[0].y=e.cue.y);let f=new Map,c=[],u=(C,P,N,z,O=0)=>{let K=n.rectangle(C,P,N,z,{isStatic:!0,restitution:.82,friction:.035,angle:O,label:"cushion",chamfer:{radius:8}});return c.push(K),K};for(let C of[-24,1024])for(let P of[500,1500])u(C,P,48,850);for(let C of[-24,2024])u(500,C,850,48);for(let[C,P,N,z]of[[30,40,1,1],[970,40,-1,1],[30,1960,1,-1],[970,1960,-1,-1]])u(C,P,42,18,N*z*Math.PI/4);s.add(a.world,c);for(let C of l.balls)if(!C.pocketed){let P=n.circle(C.x,C.y,h,{restitution:.96,friction:.008,frictionStatic:0,frictionAir:0,density:.002,label:`ball:${C.id}`},64);f.set(C.id,P),s.add(a.world,P)}let d=f.get(0);d||Gt("Cue ball missing.");let p=(.055+4.945*Math.pow(e.power,1.65))*1e3/60;i.setVelocity(d,{x:Math.sin(e.aim)*p,y:-Math.cos(e.aim)*p}),i.setAngularVelocity(d,(e.spin||0)*.25);let v=[],g=[],m=[],_=null,x=!1,y=0,S=0;o.on(a,"collisionStart",C=>{for(let P of C.pairs){let N=[P.bodyA.label,P.bodyB.label];if(N.includes("cushion")&&(P.restitution=.82),_===null&&N.includes("ball:0")){let z=N.find(O=>O.startsWith("ball:")&&O!=="ball:0");z&&(_=Number(z.split(":")[1]))}}for(let P of C.pairs){(P.bodyA.label==="cushion"||P.bodyB.label==="cushion")&&_!==null&&(x=!0);let N=Math.hypot(P.bodyA.velocity.x-P.bodyB.velocity.x,P.bodyA.velocity.y-P.bodyB.velocity.y);N>.25&&g.length<80&&g.push({t:Nt(y),type:"hit",strength:Math.min(1,N/20)})}});function M(){m.push(l.balls.flatMap(C=>{let P=f.get(C.id);return[C.id,P?Nt(P.position.x):C.x,P?Nt(P.position.y):C.y,P?1:0]}))}M();for(let C=0;C<7200;C++){y=(C+1)/240,t.update(a,1e3/240);for(let[N,z]of f){let O=Math.hypot(z.velocity.x,z.velocity.y);if(O>0){let ee=Math.max(0,O-.015277777777777777)/O;i.setVelocity(z,{x:z.velocity.x*ee,y:z.velocity.y*ee})}if(ti.pockets.some(([ee,oe])=>Math.hypot(z.position.x-ee,z.position.y-oe)<58)){let ee=l.balls.find(oe=>oe.id===N);ee.x=Nt(z.position.x),ee.y=Nt(z.position.y),ee.pocketed=!0,v.push(N),g.push({t:Nt(y),type:"pocket",id:N}),s.remove(a.world,z),f.delete(N)}}if(C%8===7&&M(),S=[...f.values()].some(N=>Math.hypot(N.velocity.x,N.velocity.y)>.07)?0:S+1,S>=36&&C>24)break}for(let[C,P]of f){let N=l.balls.find(z=>z.id===C);N.x=Nt(Math.min(1e3-h,Math.max(h,P.position.x))),N.y=Nt(Math.min(2e3-h,Math.max(h,P.position.y)))}t.clear(a),s.clear(a.world,!1);let E=r.groups[r.turn],A=r.balls.filter(C=>!C.pocketed&&Wl(C.id)===E&&E!==null).map(C=>C.id),b=E?A.length?A:[8]:r.balls.filter(C=>!C.pocketed&&C.id!==0&&C.id!==8).map(C=>C.id),w=v.includes(0),T=_===null||!b.includes(_),F=!x&&v.length===0,D=w||T||F;if(l.shots++,l.ballInHand=!1,v.includes(8)&&(r.shots===0?(Td(l,8,500,570),g.push({t:Nt(y),type:"spot",id:8})):(l.winner=!D&&b.length===1&&b[0]===8?r.turn:1-r.turn,l.status=l.winner===r.turn?`Player ${l.winner+1} wins. Clean finish!`:`Player ${l.winner+1} wins \xB7 ${w?"scratch on the 8":"8 ball pocketed too early or illegally"}.`)),l.winner===null){if(!E&&!D){let P=v.map(Wl).find(Boolean);P&&(l.groups[l.turn]=P,l.groups[1-l.turn]=P==="solids"?"stripes":"solids")}let C=v.some(P=>Wl(P)&&Wl(P)===l.groups[l.turn]);D?(l.turn=1-l.turn,l.ballInHand=!0,Td(l,0,500,1500),l.status=`${w?"Scratch":T?_===null?"No ball contacted":"Wrong ball hit first":"No ball reached a cushion"}. Player ${l.turn+1} has ball in hand.`):C?l.status=`Nice shot. Player ${l.turn+1} goes again.`:(l.turn=1-l.turn,l.status=`Player ${l.turn+1} to shoot.`)}return{state:l,replay:{kind:"pool",fps:30,frames:m,events:g,duration:Nt(y),sunk:v,firstContact:_}}}function Td(r,e,t,n){let i=r.balls.find(s=>s.id===e);if(i){for(let s=0;s<400;s++){let o=s===0?t:80+s%15*60,a=s===0?n:100+Math.floor(s/15)*65;if(a<1920&&r.balls.every(l=>l.id===e||l.pocketed||Math.hypot(l.x-o,l.y-a)>ti.radius*2+2)){i.x=o,i.y=a,i.pocketed=!1;return}}Gt("Unable to place the ball.")}}function cM(r,e){let t=Cd(r),n=new is({gravity:new R(0,-9.81,0)});n.broadphase=new ns(n),n.solver.iterations=12;let i=new kt("pingpong"),s=new kt("table"),o=new kt("cup");n.addContactMaterial(new an(i,s,{friction:.12,restitution:.78})),n.addContactMaterial(new an(i,o,{friction:.18,restitution:yr.wallRestitution}));let a=new Xe({mass:0,material:s,shape:new On(new R(.5,.04,1.13)),position:new R(0,-.04,0)});n.addBody(a);let l=oM.filter(y=>!t.removed[t.turn].includes(y.id)),h=new kt("cup-bottom");n.addContactMaterial(new an(i,h,{friction:.3,restitution:yr.bottomRestitution}));let f=new Map;for(let y of l){let S=Gl(n,y,o,h);f.set(S.id,y.id)}let c=new Xe({mass:.0027,material:i,shape:new Qn(.02),position:new R(0,.23,1.02),linearDamping:.012,angularDamping:.1}),u=e.bounce?3+e.power*2.3:1.75+e.power*1.7,d=e.bounce?.65+e.power*.7:2.55+e.power*.9;c.velocity.set(Math.sin(e.aim)*u,d,-Math.cos(e.aim)*u),n.addBody(c);let p=[],v=[],g=null,m=0,_=0;c.addEventListener("collide",y=>{f.has(y.body.id)&&g===null?(g=f.get(y.body.id),v.push({t:Nt(m),type:"cup",id:g})):y.body===a?(_++,v.push({t:Nt(m),type:"bounce"})):v.length<20&&v.push({t:Nt(m),type:"rim"})}),p.push([0,.23,1.02]);for(let y=0;y<960;y++){if(m=(y+1)/240,n.step(1/240),y%4===3&&p.push([Nt(c.position.x),Nt(c.position.y),Nt(c.position.z)]),g!==null){p.push([Nt(c.position.x),Nt(c.position.y),Nt(c.position.z)]);break}if(c.position.y<-.6||Math.abs(c.position.z)>2||Math.abs(c.position.x)>1.2||m>1.8&&c.velocity.length()<.035)break}let x=t.turn;return t.shots++,g!==null&&t.removed[x].push(g),t.removed[x].length===6?(t.winner=x,t.status=`Player ${x+1} wins. Six cups cleared!`):(t.turn=1-x,t.status=g!==null?`Cup sunk! Player ${t.turn+1}, your throw.`:`${_?"Off the table.":"Just missed."} Player ${t.turn+1}, your throw.`),{state:t,replay:{kind:"pong",fps:60,frames:p,events:v,duration:Nt(m),hit:g,bounces:_,player:x}}}var tu={density:1.225,coefficient:.47,radius:.02,mass:.0027},hM=.5*tu.density*tu.coefficient*Math.PI*tu.radius**2;function Pd(r){let e=r.velocity.length();if(e>0){let t=-hM*e;r.force.x+=r.velocity.x*t,r.force.y+=r.velocity.y*t,r.force.z+=r.velocity.z*t}}function Id(r,e){return e?{forward:2.5+r*1.3,up:1.1+r*.5}:{forward:2.2+r*1.8,up:2.7+r*.9}}var iu="maroon-games-2.2.0",pn={width:1e3,height:2e3,radius:27,pockets:[[0,0],[1e3,0],[0,1e3],[1e3,1e3],[0,2e3],[1e3,2e3]]},wo=[{id:0,x:0,z:-.45},{id:1,x:-.083,z:-.62},{id:2,x:.083,z:-.62},{id:3,x:-.166,z:-.79},{id:4,x:0,z:-.79},{id:5,x:.166,z:-.79}],Ld=r=>JSON.parse(JSON.stringify(r)),bt=r=>Math.round(r*1e4)/1e4,ql=r=>r>=1&&r<=7?"solids":r>=9&&r<=15?"stripes":null,bo=(r,e,t)=>typeof r=="number"&&Number.isFinite(r)&&r>=e&&r<=t,Ot=r=>{throw new Error(r)};function Xl(r){let e={kind:r,rules:iu,turn:0,winner:null,shots:0,status:"Player 1 to play."};if(r==="pool"){let t=[{id:0,x:500,y:1510,pocketed:!1}],n=[1,10,2,3,8,11,12,4,13,5,6,14,7,15,9],i=0;for(let s=0;s<5;s++)for(let o=0;o<=s;o++)t.push({id:n[i++],x:500+(o-s/2)*55.2,y:570-s*47.85,pocketed:!1});return{...e,balls:t,groups:[null,null],ballInHand:!1,status:"Player 1 breaks. Pull the cue back for a strong shot."}}if(r==="pong")return{...e,removed:[[],[]],status:"Player 1 \xB7 aim, pull back, and release."};if(r==="chess")return Dd(new Li,e);Ot("Unknown game.")}function Dd(r,e){let t=r.isGameOver(),n=r.turn()==="w"?0:1,i=r.isCheckmate()?1-n:null;return{...e,fen:r.fen(),pgn:r.pgn(),turn:n,winner:i,finished:t,legal:r.moves({verbose:!0}).map(s=>({from:s.from,to:s.to,promotion:s.promotion})),status:i!==null?`Player ${i+1} wins by checkmate.`:t?"Draw.":`Player ${n+1} to move${r.isCheck()?" \xB7 check":""}.`}}function Fd(r,e,t){if(e?.rules==="maroon-games-2.1.0")return eu(r,e,t);if(e?.rules==="maroon-games-2.0.0")return Mo(r,e,t);(!e||e.kind!==r||e.rules!==iu)&&Ot("Unsupported game version."),(e.winner!==null||e.finished)&&Ot("This game has finished."),(!t||typeof t!="object")&&Ot("Missing turn.");let n=r==="chess"?["from","to","promotion"]:r==="pool"?["aim","power","spin","cue"]:["aim","power","bounce"];if(Object.keys(t).some(i=>!n.includes(i))&&Ot("Unsupported turn input."),t.cue&&(typeof t.cue!="object"||Object.keys(t.cue).some(i=>!["x","y"].includes(i)))&&Ot("Invalid cue position."),r==="chess"){(!/^[a-h][1-8]$/.test(t.from)||!/^[a-h][1-8]$/.test(t.to)||!["q","r","b","n"].includes(t.promotion||"q"))&&Ot("Choose a legal chess move.");return}(!bo(t.aim,-Math.PI,Math.PI)||!bo(t.power,.03,1))&&Ot("Aim or power is outside the allowed range."),r==="pool"?(bo(t.spin??0,-1,1)||Ot("Spin is outside the allowed range."),t.cue&&(e.ballInHand||Ot("The cue ball cannot be moved now."),(!bo(t.cue.x,pn.radius+8,pn.width-pn.radius-8)||!bo(t.cue.y,pn.radius+8,pn.height-pn.radius-8))&&Ot("Place the cue ball on the felt."),e.balls.some(i=>i.id!==0&&!i.pocketed&&Math.hypot(i.x-t.cue.x,i.y-t.cue.y)<pn.radius*2+1)&&Ot("The cue ball overlaps another ball."),pn.pockets.some(([i,s])=>Math.hypot(i-t.cue.x,s-t.cue.y)<80)&&Ot("Place the cue ball away from a pocket."))):r==="pong"&&(Math.abs(t.aim)>.42&&Ot("Aim at the table."),t.bounce!==void 0&&typeof t.bounce!="boolean"&&Ot("Invalid throw type."))}function su(r,e,t){if(e?.rules==="maroon-games-2.1.0")return Rd(r,e,t);if(e?.rules==="maroon-games-2.0.0")return Hl(r,e,t);if(Fd(r,e,t),r==="pool")return uM(e,t);if(r==="pong")return Ud(e,t);let n=new Li;e.pgn?n.loadPgn(e.pgn):n.load(e.fen);let i;try{i=n.move({from:t.from,to:t.to,promotion:t.promotion||"q"})}catch{Ot("That chess move is not legal.")}return i||Ot("That chess move is not legal."),{state:Dd(n,{...e,shots:e.shots+1}),replay:{kind:"chess",move:{from:t.from,to:t.to},notation:i.san}}}function uM(r,e){let{Engine:t,Bodies:n,Body:i,Composite:s,Events:o}=nu.default;nu.default.Common._nextId=0;let a=t.create({gravity:{x:0,y:0,scale:0},positionIterations:10,velocityIterations:10,enableSleeping:!1}),l=Ld(r),h=pn.radius;e.cue&&(l.balls[0].x=e.cue.x,l.balls[0].y=e.cue.y);let f=new Map,c=[],u=(C,P,N,z,O=0)=>{let K=n.rectangle(C,P,N,z,{isStatic:!0,restitution:.82,friction:.035,angle:O,label:"cushion",chamfer:{radius:8}});return c.push(K),K};for(let C of[-24,1024])for(let P of[500,1500])u(C,P,48,850);for(let C of[-24,2024])u(500,C,850,48);for(let[C,P,N,z]of[[30,40,1,1],[970,40,-1,1],[30,1960,1,-1],[970,1960,-1,-1]])u(C,P,42,18,N*z*Math.PI/4);s.add(a.world,c);for(let C of l.balls)if(!C.pocketed){let P=n.circle(C.x,C.y,h,{restitution:.96,friction:.008,frictionStatic:0,frictionAir:0,density:.002,label:`ball:${C.id}`},64);f.set(C.id,P),s.add(a.world,P)}let d=f.get(0);d||Ot("Cue ball missing.");let p=(.055+4.945*Math.pow(e.power,1.65))*1e3/60;i.setVelocity(d,{x:Math.sin(e.aim)*p,y:-Math.cos(e.aim)*p}),i.setAngularVelocity(d,(e.spin||0)*.25);let v=[],g=[],m=[],_=null,x=!1,y=0,S=0;o.on(a,"collisionStart",C=>{for(let P of C.pairs){let N=[P.bodyA.label,P.bodyB.label];if(N.includes("cushion")&&(P.restitution=.82),_===null&&N.includes("ball:0")){let z=N.find(O=>O.startsWith("ball:")&&O!=="ball:0");z&&(_=Number(z.split(":")[1]))}}for(let P of C.pairs){(P.bodyA.label==="cushion"||P.bodyB.label==="cushion")&&_!==null&&(x=!0);let N=Math.hypot(P.bodyA.velocity.x-P.bodyB.velocity.x,P.bodyA.velocity.y-P.bodyB.velocity.y);N>.25&&g.length<80&&g.push({t:bt(y),type:"hit",strength:Math.min(1,N/20)})}});function M(){m.push(l.balls.flatMap(C=>{let P=f.get(C.id);return[C.id,P?bt(P.position.x):C.x,P?bt(P.position.y):C.y,P?1:0]}))}M();for(let C=0;C<7200;C++){y=(C+1)/240,t.update(a,1e3/240);for(let[N,z]of f){let O=Math.hypot(z.velocity.x,z.velocity.y);if(O>0){let ee=Math.max(0,O-.015277777777777777)/O;i.setVelocity(z,{x:z.velocity.x*ee,y:z.velocity.y*ee})}if(pn.pockets.some(([ee,oe])=>Math.hypot(z.position.x-ee,z.position.y-oe)<58)){let ee=l.balls.find(oe=>oe.id===N);ee.x=bt(z.position.x),ee.y=bt(z.position.y),ee.pocketed=!0,v.push(N),g.push({t:bt(y),type:"pocket",id:N}),s.remove(a.world,z),f.delete(N)}}if(C%8===7&&M(),S=[...f.values()].some(N=>Math.hypot(N.velocity.x,N.velocity.y)>.07)?0:S+1,S>=36&&C>24)break}for(let[C,P]of f){let N=l.balls.find(z=>z.id===C);N.x=bt(Math.min(1e3-h,Math.max(h,P.position.x))),N.y=bt(Math.min(2e3-h,Math.max(h,P.position.y)))}t.clear(a),s.clear(a.world,!1);let E=r.groups[r.turn],A=r.balls.filter(C=>!C.pocketed&&ql(C.id)===E&&E!==null).map(C=>C.id),b=E?A.length?A:[8]:r.balls.filter(C=>!C.pocketed&&C.id!==0&&C.id!==8).map(C=>C.id),w=v.includes(0),T=_===null||!b.includes(_),F=!x&&v.length===0,D=w||T||F;if(l.shots++,l.ballInHand=!1,v.includes(8)&&(r.shots===0?(Nd(l,8,500,570),g.push({t:bt(y),type:"spot",id:8})):(l.winner=!D&&b.length===1&&b[0]===8?r.turn:1-r.turn,l.status=l.winner===r.turn?`Player ${l.winner+1} wins. Clean finish!`:`Player ${l.winner+1} wins \xB7 ${w?"scratch on the 8":"8 ball pocketed too early or illegally"}.`)),l.winner===null){if(!E&&!D){let P=v.map(ql).find(Boolean);P&&(l.groups[l.turn]=P,l.groups[1-l.turn]=P==="solids"?"stripes":"solids")}let C=v.some(P=>ql(P)&&ql(P)===l.groups[l.turn]);D?(l.turn=1-l.turn,l.ballInHand=!0,Nd(l,0,500,1500),l.status=`${w?"Scratch":T?_===null?"No ball contacted":"Wrong ball hit first":"No ball reached a cushion"}. Player ${l.turn+1} has ball in hand.`):C?l.status=`Nice shot. Player ${l.turn+1} goes again.`:(l.turn=1-l.turn,l.status=`Player ${l.turn+1} to shoot.`)}return{state:l,replay:{kind:"pool",fps:30,frames:m,events:g,duration:bt(y),sunk:v,firstContact:_}}}function Nd(r,e,t,n){let i=r.balls.find(s=>s.id===e);if(i){for(let s=0;s<400;s++){let o=s===0?t:80+s%15*60,a=s===0?n:100+Math.floor(s/15)*65;if(a<1920&&r.balls.every(l=>l.id===e||l.pocketed||Math.hypot(l.x-o,l.y-a)>pn.radius*2+2)){i.x=o,i.y=a,i.pocketed=!1;return}}Ot("Unable to place the ball.")}}function Bd(r,e){return Fd("pong",r,e),r.rules!==iu?su("pong",r,e).replay:Ud(r,e,!0).replay}function Ud(r,e,t=!1){let n=Ld(r),i=new is({gravity:new R(0,-9.81,0)});i.broadphase=new ns(i),i.solver.iterations=12;let s=new kt("pingpong"),o=new kt("table"),a=new kt("cup");i.addContactMaterial(new an(s,o,{friction:.12,restitution:.78})),i.addContactMaterial(new an(s,a,{friction:.18,restitution:yr.wallRestitution}));let l=new Xe({mass:0,material:o,shape:new On(new R(.5,.04,1.13)),position:new R(0,-.04,0)});i.addBody(l);let h=wo.filter(S=>!n.removed[n.turn].includes(S.id)),f=new kt("cup-bottom");i.addContactMaterial(new an(s,f,{friction:.3,restitution:yr.bottomRestitution}));let c=new Map;for(let S of h){let M=Gl(i,S,a,f);c.set(M.id,S.id)}let u=new Xe({mass:.0027,material:s,shape:new Qn(.02),position:new R(0,.23,1.02),linearDamping:0,angularDamping:.1}),{forward:d,up:p}=Id(e.power,e.bounce);u.velocity.set(Math.sin(e.aim)*d,p,-Math.cos(e.aim)*d),i.addBody(u);let v=[],g=[],m=null,_=0,x=0;u.addEventListener("collide",S=>{c.has(S.body.id)&&m===null?(m=c.get(S.body.id),g.push({t:bt(_),type:"cup",id:m})):S.body===l?(x++,g.push({t:bt(_),type:"bounce"})):g.length<20&&g.push({t:bt(_),type:"rim"})}),v.push([0,.23,1.02]);for(let S=0;S<960;S++){if(_=(S+1)/240,Pd(u),i.step(1/240),S%4===3&&v.push([bt(u.position.x),bt(u.position.y),bt(u.position.z)]),t&&g.some((M,E)=>M.type!=="bounce"||!e.bounce||g.slice(0,E+1).filter(A=>A.type==="bounce").length>=2)){v.push([bt(u.position.x),bt(u.position.y),bt(u.position.z)]);break}if(m!==null){v.push([bt(u.position.x),bt(u.position.y),bt(u.position.z)]);break}if(u.position.y<-.6||Math.abs(u.position.z)>2||Math.abs(u.position.x)>1.2||_>1.8&&u.velocity.length()<.035)break}let y=n.turn;return n.shots++,m!==null&&n.removed[y].push(m),n.removed[y].length===6?(n.winner=y,n.status=`Player ${y+1} wins. Six cups cleared!`):(n.turn=1-y,n.status=m!==null?`Cup sunk! Player ${n.turn+1}, your throw.`:`${x?"Off the table.":"Just missed."} Player ${n.turn+1}, your throw.`),{state:n,replay:{kind:"pong",fps:60,frames:v,events:g,duration:bt(_),hit:m,bounces:x,player:y}}}var Od=(r,e,t)=>Math.min(t,Math.max(e,r));function zd(r,e,t,n=0){let i=Math.max(1,t.width),s=Math.max(1,t.height),o=e.x-r.x,a=e.y-r.y;return{aim:Od(n-o/i*.52,-.24,.24),power:Od(a/(s*.33),.03,1),releases:a>=12}}function kd(r,e){let t=Bd(r,e),n=0,i=t.events.find(a=>a.type!=="bounce"||++n>=(e.bounce?2:1)),s=Math.min(t.frames.length-1,Math.ceil(Math.min(i?.t??t.duration,1.5)*t.fps));return{points:t.frames.slice(0,s+1).filter((a,l)=>l%2===0||l===s),target:t.frames[s],contact:i?.type??"miss"}}var xe=r=>document.getElementById(r),Mr=r=>window.webkit?.messageHandlers.game.postMessage(r),Le="pool",nt=Xl("pool"),as=!1,To=0,Di=["Player 1","Player 2"],Hd=!0,$l=-1,Tt=0,pi=.65,vn=!1,Zt=null,ii=null,Gd=0,Yl=0,Eo=!0,zn,wt=null,Fi=!1,Bi=null,ni=null,_r=!1,Ls=new Map,Kl=new Map,Ds,Rn,Tn,Sr,mi,Ns,si,kn,gn;var Ao=null,ru=null,fM=[16117983,15578667,1525408,12855341,6435722,14186786,2451271,8069155,1381397],ou=new to,dM=new Dn(new G(0,1,0),0),Vd=new et;function An(r,e={}){return new sr({color:r,roughness:.5,...e})}function nn(r,e,t=0,n=0,i=0,s=gn){let o=new fn(r,e);return o.position.set(t,n,i),o.castShadow=!0,o.receiveShadow=!0,s.add(o),o}function mn(r,e,t,n,i=0,s=0,o=0,a){return nn(new Yi(r,e,t),An(n,a),i,s,o)}function jl(r,e=256){let t=document.createElement("canvas");t.width=t.height=e,r(t.getContext("2d"),e);let n=new Wr(t);return n.colorSpace=jt,n}var Co=jl((r,e)=>{r.fillStyle="#155c4e",r.fillRect(0,0,e,e);for(let t=0;t<8500;t++){let n=t*137.508%e,i=t*73.31%e;r.fillStyle=t%2?"#ffffff07":"#00000008",r.fillRect(n,i,1,1)}});Co.wrapS=Co.wrapT=Ys;Co.repeat.set(5,10);var Zl=jl((r,e)=>{r.fillStyle="#512c1e",r.fillRect(0,0,e,e);for(let t=0;t<160;t++){r.strokeStyle=t%2?"#bc795f28":"#170e092c",r.lineWidth=.4+t%3*.3,r.beginPath();for(let n=0;n<=e;n+=8){let i=t*e/160+Math.sin(n*.012+t)*2;n?r.lineTo(i,n):r.moveTo(i,n)}r.stroke()}});function Wd(){if(kn)return;kn=new yl({canvas:xe("table"),antialias:!0,alpha:!0,powerPreference:"high-performance"}),kn.setPixelRatio(Math.min(devicePixelRatio,2)),kn.shadowMap.enabled=!0,kn.shadowMap.type=ba,kn.outputColorSpace=jt,kn.toneMapping=Ia,kn.toneMappingExposure=1,Ns=new Vr,si=new Qt(38,1,.01,30),Ns.add(new Qr(16774103,2244424,1.15));let r=new rr(16772551,2.1);r.position.set(-2,5,2),r.castShadow=!0,r.shadow.mapSize.set(1024,1024),r.shadow.camera.left=-2,r.shadow.camera.right=2,r.shadow.camera.top=2,r.shadow.camera.bottom=-2,r.shadow.normalBias=.005,Ns.add(r);let e=new rr(11063782,.8);e.position.set(2,2,-2),Ns.add(e),new ResizeObserver(qd).observe(xe("stage")),requestAnimationFrame($d)}function qd(){if(!kn)return;let r=xe("stage").getBoundingClientRect();kn.setSize(r.width,r.height,!1),si.aspect=r.width/r.height,si.updateProjectionMatrix(),Ql()}function Ql(){if(!si)return;let r=Le==="pool"&&!Zt||_r;si.up.set(0,r?0:1,r?-1:0);let e=r?new G(0,1,0):Le==="chess"?new G(0,2.2,1.5):new G(0,2.1,2.4);e.normalize();let t=new G(0,0,Le==="pool"&&!r?.16:Le==="pong"?-.02:0),n=2,i=.6,s=Le==="chess"?.6:Le==="pool"?1.1:1.175,o=[];for(let a of[-i,i])for(let l of[-s,s])for(let h of[0,Le==="pool"?.06:Le==="chess"?.2:.17])o.push(new G(a,h,l));for(let a=0;a<110&&(si.position.copy(e).multiplyScalar(n).add(t),si.lookAt(t),si.updateMatrixWorld(),!o.map(h=>h.clone().project(si)).every(h=>Math.abs(h.x)<.94&&h.y<.94&&h.y>-.88));a++)n*=1.025;xe("camera").textContent=r?"Perspective":"Overhead",xe("table").setAttribute("aria-label",Le==="pool"&&r?"Game table, flat overhead pool. Touch to aim; pull back and release to shoot.":"Game table. Pull down for power and sideways to steer; release to throw.")}function pM(r){return jl((e,t)=>{let n="#"+new ot(fM[r>8?r-8:r]).getHexString();if(e.fillStyle=r>8?"#f5f0df":n,e.fillRect(0,0,t,t),r>8&&(e.fillStyle=n,e.fillRect(0,t*.28,t,t*.44)),r)for(let i of[t*.25,t*.75])e.fillStyle="#fff8e7",e.beginPath(),e.arc(i,t*.5,t*.16,0,Math.PI*2),e.fill(),e.fillStyle="#161413",e.font=`bold ${t*.19}px Arial`,e.textAlign="center",e.textBaseline="middle",e.fillText(String(r),i,t*.508)},256)}function Jl(){if(wt=null,clearTimeout(Ao),Ao=null,ru=null,gn&&(gn.traverse(r=>{if(r.geometry&&r.geometry.dispose(),r.material){let e=Array.isArray(r.material)?r.material:[r.material];for(let t of e)t.map&&t.map!==Co&&t.map!==Zl&&t.map.dispose(),t.dispose()}}),Ns.remove(gn)),gn=new $n,Ns.add(gn),Ls=new Map,Kl=new Map,Rn=null,Tn=null,Sr=null,mi=null,Ds=null,ni=null,Bi=null,Le==="pool"){mn(1.18,.17,2.18,6503464,0,-.095,0,{map:Zl,roughness:.35}),mn(1.06,.01,2.06,1516834,0,-.004,0),mn(1,.007,2,16777215,0,.002,0,{map:Co,roughness:.92});for(let n of[-.524,.524])for(let i of[-.5,.5])mn(.048,.045,.85,2324060,n,.022,i);for(let n of[-1.024,1.024])mn(.85,.045,.048,2324060,0,.022,n);for(let[n,i]of pn.pockets){let s=n/1e3-.5,o=i/1e3-1;nn(new ai(.061,.054,.07,32),An(592651),s,-.006,o);let a=nn(new ir(.061,.007,8,32),An(11635281,{metalness:.65}),s,.025,o);a.rotation.x=Math.PI/2}for(let n of[-1,1])for(let i of[-.75,-.25,.25,.75]){let s=mn(.01,.002,.01,14207136,n*.563,.005,i);s.rotation.y=Math.PI/4}for(let n of nt.balls){let i=nn(new Zi(.027,24,16),An(16777215,{map:pM(n.id),roughness:.18,metalness:.04}),n.x/1e3-.5,.029,n.y/1e3-1);Ls.set(n.id,i)}Rn=new $n,gn.add(Rn);let r=nn(new ai(.003,.006,.65,12),An(13345911),0,0,0,Rn);r.rotation.x=Math.PI/2,r.position.z=.355;let e=nn(new ai(.006,.008,.25,12),An(3872792),0,0,.805,Rn);e.rotation.x=Math.PI/2;let t=nn(new ai(.0033,.0033,.006,12),An(7385012),0,0,.029,Rn);t.rotation.x=Math.PI/2,Sr=nn(new Zi(.027,18,12),An(16771488,{transparent:!0,opacity:.3,depthWrite:!1}))}else if(Le==="pong"){mn(1.08,.1,2.34,6766121,0,-.08,0,{map:Zl}),mn(1,.035,2.26,15391677,0,-.0175,0,{roughness:.5}),mn(.008,.001,2.2,6626604,0,.001,0);for(let t of[-1.03,1.03])mn(.85,.002,.018,6626604,0,.002,t);let r=jl((t,n)=>{t.clearRect(0,0,n,n),t.fillStyle="#5a1c2bcc",t.textAlign="center",t.font="bold 80px Georgia",t.fillText("M",n/2,160)}),e=nn(new ys(.35,.35),new sr({map:r,transparent:!0,roughness:1}),0,.003,.05);e.rotation.x=-Math.PI/2;for(let t of wo){let n=new $n;gn.add(n),n.position.set(t.x,0,t.z);let i=[[.047,0],[.049,.01],[.071,.145],[.074,.149],[.069,.151],[.065,.143],[.044,.012],[0,.012]].map(([l,h])=>new et(l,h)),s=nn(new nr(i,40),An(8789811,{side:bn,roughness:.3}),0,0,0,n),o=nn(new ir(.07,.003,8,40),An(15984341),0,.15,0,n);o.rotation.x=Math.PI/2;let a=nn(new $r(.051,32),An(10245153,{roughness:.14,transparent:!0,opacity:.88}),0,.06,0,n);a.rotation.x=-Math.PI/2,Kl.set(t.id,n)}Ds=nn(new Zi(.02,24,18),An(16774882,{roughness:.6}),0,.23,1.02),mi=nn(new Zr(.042,.051,40),new xs({color:5242880,side:bn,transparent:!0,opacity:.9,depthWrite:!1}),0,.006,0),mi.rotation.x=-Math.PI/2}else mM();if(Le!=="chess"){let r=new Lt().setFromPoints([new G,new G]);Tn=new Gr(r,new Kr({color:16773044,dashSize:.03,gapSize:.025,transparent:!0,opacity:.75})),gn.add(Tn)}Xd(),qd()}function mM(){mn(1.18,.09,1.18,4925727,0,-.057,0,{map:Zl});let r=nt.fen.split(" ")[0].split("/");for(let e=0;e<8;e++){let t=0;for(let n of r[e]){if(/\d/.test(n)){t+=Number(n);continue}let i=(t-3.5)*.135,s=(e-3.5)*.135,o=String.fromCharCode(97+t)+(8-e),a=n===n.toUpperCase(),l=An(a?15589309:5052452,{roughness:.3}),h=n.toLowerCase(),f=[[.035,0],[.04,.01],[.035,.019],[.028,.025],[.014,.048],[.012,.068],[.026,.073],[.023,.08]],c=h==="p"?1:h==="k"?1.6:1.35,u=nn(new nr(f.map(([p,v])=>new et(p,v*c)),24),l,i,.011,s);u.userData.square=o;let d=nn(h==="r"?new ai(.027,.027,.023,8):h==="n"?new Yr(.027,.052,4):new Zi(h==="p"?.019:.023,16,12),l,i,.095*c,s);if(d.userData.square=o,h==="n"&&(d.rotation.z=-.3,d.rotation.y=Math.PI/4),h==="k"){let p=mn(.038,.01,.009,a?15589309:5052452,i,.185,s);p.userData.square=o;let v=mn(.01,.039,.009,a?15589309:5052452,i,.182,s);v.userData.square=o}t++}}for(let e=0;e<8;e++)for(let t=0;t<8;t++){let n=mn(.135,.012,.135,(e+t)%2?7161142:14602411,(t-3.5)*.135,0,(e-3.5)*.135);n.userData.square=String.fromCharCode(97+t)+(8-e),Ls.set(n.userData.square,n)}}function Cn(){return Hd&&!vn&&nt.winner===null&&!nt.finished&&(!as||nt.turn===To)}function Xd(){if(Le==="pool")for(let r of nt.balls){let e=Ls.get(r.id);e.visible=!r.pocketed,e.position.set(r.x/1e3-.5,.029,r.y/1e3-1)}if(Le==="pong"){for(let r of wo)Kl.get(r.id).visible=!nt.removed[nt.turn].includes(r.id);Ds.position.set(0,.23,1.02),Ds.visible=!0}ri(),Vn(),Ql()}function ri(){if(xe("turn").textContent=nt.winner!==null?`${Di[nt.winner]} wins`:nt.finished?"Draw":as?`${nt.turn===To?"Your turn":Di[nt.turn]+"\u2019s turn"}`:`${Di[nt.turn]} \xB7 ${nt.shots===0?"ready":"your turn"}`,xe("score").textContent=Le==="pool"?nt.groups.map((r,e)=>`${e===To&&as?"You":Di[e]}: ${r||"open table"}${r?" \xB7 "+nt.balls.filter(t=>!t.pocketed&&(r==="solids"?t.id>0&&t.id<8:t.id>8)).length+" left":""}`).join("  /  "):Le==="pong"?`${Di[0]}  ${nt.removed[0].length}/6     \xB7     ${Di[1]}  ${nt.removed[1].length}/6`:"White \xB7 "+Di[0]+"   /   Black \xB7 "+Di[1],xe("replayShot").disabled=vn||!ii||Le==="chess",xe("status").textContent=nt.status,xe("toast").textContent=vn?"Watching the shot\u2026":Fi?"Tap an empty spot on the felt":Le==="chess"?ni?"Choose a highlighted square":"Choose a piece":"",xe("toast").style.display=xe("toast").textContent?"block":"none",xe("hint").textContent=Le==="pool"?"Tap to aim \xB7 pull back and release":Le==="pong"?"Pull down for power \xB7 sideways to steer \xB7 release":"Tap a piece, then its destination",xe("camera").style.display=Le==="pool"&&!Zt?"none":"block",xe("shoot").textContent=vn?"Shot in motion\u2026":!Cn()&&as?"Waiting for opponent":Le==="pool"?"Take shot":Le==="pong"?"Throw ball":"Choose a move",xe("shoot").disabled=!Cn()||Le==="chess",xe("power").disabled=xe("aim").disabled=!Cn(),xe("left").disabled=xe("right").disabled=!Cn(),xe("aimrow").style.display=xe("powerrow").style.display=Le==="chess"?"none":"flex",xe("throwType").style.display=Le==="pong"?"block":"none",xe("promotion").style.display=Le==="chess"?"block":"none",xe("shoot").style.display=Le==="chess"?"none":"block",xe("reset").style.display=as?"none":"block",xe("ballInHand").style.display=Le==="pool"&&nt.ballInHand&&Cn()?"block":"none",xe("legal").style.display=Le==="chess"&&Cn()?"flex":"none",xe("legal").replaceChildren(),Le==="chess"&&Cn())for(let r of nt.legal.filter(e=>!ni||e.from===ni)){if(r.promotion&&r.promotion!==xe("promotion").value)continue;let e=document.createElement("button");e.textContent=r.from+" \u2192 "+r.to,e.onclick=()=>ec(r),xe("legal").append(e)}xe("aim").min=Le==="pong"?-13.75:-180,xe("aim").max=Le==="pong"?13.75:180}function Vn(){if(!gn||Le==="chess")return;let r=Cn();if(Rn){let t=Bi||nt.balls[0];Rn.visible=r&&!Fi,Rn.position.set(t.x/1e3-.5,.03,t.y/1e3-1),Rn.rotation.y=-Tt,Rn.translateZ(pi*.1),Bi&&Ls.get(0).position.set(t.x/1e3-.5,.029,t.y/1e3-1)}let e=[];if(Le==="pool"){let t=Bi||nt.balls[0],n=t.x/1e3-.5,i=t.y/1e3-1,s=Math.sin(Tt),o=-Math.cos(Tt),a=.65;for(let l of nt.balls){if(!l.id||l.pocketed)continue;let h=l.x/1e3-.5-n,f=l.y/1e3-1-i,c=h*s+f*o,u=h*h+f*f-c*c;c>0&&u<.054*.054&&(a=Math.min(a,c-Math.sqrt(.054*.054-u)))}a=Math.max(0,a),e=[new G(n,.03,i),new G(n+s*a,.03,i+o*a)],Sr.visible=r&&!Fi,Sr.position.copy(e[1])}else r&&!Ao&&(Ao=setTimeout(()=>{if(Ao=null,Le!=="pong"||!Cn())return;let t=[nt.shots,nt.turn,Tt.toFixed(4),pi.toFixed(3),xe("throwType").value].join(":");if(t===ru)return;ru=t;let n=kd(nt,{aim:Tt,power:pi,bounce:xe("throwType").value==="bounce"});Tn.geometry.dispose(),Tn.geometry=new Lt().setFromPoints(n.points.map(i=>new G(...i))),Tn.computeLineDistances(),Tn.visible=!0,mi&&n.target&&(mi.position.set(n.target[0],.006,n.target[2]),mi.visible=Math.abs(n.target[0])<.5&&Math.abs(n.target[2])<1.13)},80));Le==="pool"&&(Tn.geometry.dispose(),Tn.geometry=new Lt().setFromPoints(e),Tn.computeLineDistances()),Tn.visible=r&&!Fi,mi&&!r&&(mi.visible=!1),xe("aim").value=Tt*180/Math.PI,xe("power").value=pi*100,xe("powerValue").textContent=Math.round(pi*100)+"%"}function au(r){if(!Eo)try{zn??=new(window.AudioContext||window.webkitAudioContext),zn.resume();let e=zn.createOscillator(),t=zn.createGain();e.connect(t),t.connect(zn.destination),e.type=r==="cup"?"sine":"triangle",e.frequency.setValueAtTime(r==="cup"?760:r==="pocket"?140:920,zn.currentTime),e.frequency.exponentialRampToValueAtTime(80,zn.currentTime+.09),t.gain.setValueAtTime(.1,zn.currentTime),t.gain.exponentialRampToValueAtTime(.001,zn.currentTime+.13),e.start(),e.stop(zn.currentTime+.14)}catch{}}function lu(r,e){ii={data:r,next:e},vn=!0,Zt={...r,next:e},Gd=performance.now(),Yl=0,Le==="pool"&&(_r=!(as&&nt.turn!==To)),ri(),Ql(),Rn&&(Rn.visible=!1),Sr&&(Sr.visible=!1),Tn&&(Tn.visible=!1),mi&&(mi.visible=!1),Mr({type:"haptic",style:"shot"})}async function ec(r){if(!Cn())return;let e=r||{aim:Tt,power:pi,...Le==="pool"?{spin:0,...Bi?{cue:Bi}:{}}:{bounce:xe("throwType").value==="bounce"}};if(Fi=!1,as){vn=!0,ri(),Mr({type:"shot",input:e});return}try{let t=su(Le,nt,e);Le==="chess"?(nt=t.state,Jl(),au("hit")):lu(t.replay,t.state)}catch(t){xe("status").textContent=t.message,vn=!1,ri()}}function $d(r){if(requestAnimationFrame($d),!!kn){if(Zt){let e=(r-Gd)/1e3,t=Zt.frames||[],n=Math.min(t.length-1,Math.floor(e*Zt.fps)),i=Math.min(1,e*Zt.fps-n),s=t[n],o=t[Math.min(n+1,t.length-1)];if(s&&o)if(Le==="pool")for(let a=0;a<s.length;a+=4){let l=Ls.get(s[a]);if(!l)continue;let h=(s[a+1]+(o[a+1]-s[a+1])*i)/1e3-.5,f=(s[a+2]+(o[a+2]-s[a+2])*i)/1e3-1;l.rotation.x+=(f-l.position.z)/.027,l.rotation.z-=(h-l.position.x)/.027,l.position.set(h,.029,f),l.visible=!!s[a+3]}else Le==="pong"&&(Ds.position.set(...s.map((a,l)=>a+(o[l]-a)*i)),Ds.rotation.x+=.08);for(;Yl<(Zt.events?.length||0)&&Zt.events[Yl].t<=e;){let a=Zt.events[Yl++];au(a.type),["cup","pocket"].includes(a.type)&&Mr({type:"haptic",style:"score"})}e>=Math.max(Zt.duration||0,(t.length-1)/(Zt.fps||30))+.22&&(nt=Zt.next,Zt=null,vn=!1,Bi=null,Xd(),Mr({type:"settled"}))}kn.render(Ns,si)}}function Yd(r){let e=xe("table").getBoundingClientRect();return!e.width||!e.height||!Number.isFinite(r.clientX)||!Number.isFinite(r.clientY)?null:(Vd.set((r.clientX-e.left)/e.width*2-1,-(r.clientY-e.top)/e.height*2+1),ou.setFromCamera(Vd,si),ou.ray.intersectPlane(dM,new G))}function Zd(r){if(!wt||r.pointerId!==wt.pointerId||!Cn())return;let e=Yd(r);if(e&&(wt.last=e),Le==="pong"){let s={x:r.clientX,y:r.clientY};wt.pull=zd(wt.screen,s,xe("table").getBoundingClientRect(),wt.aim),Math.hypot(s.x-wt.screen.x,s.y-wt.screen.y)>4&&(Tt=wt.pull.aim,s.y-wt.screen.y>4&&(pi=wt.pull.power),Vn());return}if(!e)return;let t=e.x-wt.start.x,n=e.z-wt.start.z,i=Math.hypot(t,n);i>.04&&(Tt=Math.atan2(-t,n),Le==="pong"&&(Tt=Math.max(-.42,Math.min(.42,Tt))),pi=Math.max(.03,Math.min(1,i/.65)),Vn())}xe("table").addEventListener("pointerdown",r=>{if(wt||!Cn()||r.isPrimary===!1||r.button!==0)return;let e=Yd(r);if(e){if(Le==="chess"){let t=ou.intersectObjects(gn.children,!0),n=t.find(i=>i.object.userData.square)?.object.userData.square;if(!n)return;if(ni&&nt.legal.some(i=>i.from===ni&&i.to===n)){ec({from:ni,to:n,promotion:xe("promotion").value}),ni=null;return}ni=nt.legal.some(i=>i.from===n)?n:null;for(let[i,s]of Ls)s.material.emissive.setHex(i===ni?9990459:nt.legal.some(o=>o.from===ni&&o.to===i)?2443562:0);ri();return}if(Fi){let t={x:Math.round((e.x+.5)*1e3),y:Math.round((e.z+1)*1e3)};t.x>35&&t.x<965&&t.y>35&&t.y<1965&&!nt.balls.some(n=>n.id&&!n.pocketed&&Math.hypot(n.x-t.x,n.y-t.y)<56)&&!pn.pockets.some(([n,i])=>Math.hypot(n-t.x,i-t.y)<80)&&(Bi=t,Fi=!1,ri(),Vn());return}wt={start:e,last:e,pointerId:r.pointerId,screen:{x:r.clientX,y:r.clientY},aim:Tt};try{xe("table").setPointerCapture(r.pointerId)}catch{}}});xe("table").addEventListener("pointermove",Zd);xe("table").addEventListener("pointerup",r=>{if(!wt||r.pointerId!==wt.pointerId)return;Zd(r);let e=wt;wt=null;try{xe("table").hasPointerCapture(r.pointerId)&&xe("table").releasePointerCapture(r.pointerId)}catch{}if(Cn()){if(Le==="pong"?e.pull?.releases:Math.hypot(e.last.x-e.start.x,e.last.z-e.start.z)>.09){ec();return}if(Le==="pool"){let t=Bi||nt.balls[0];Tt=Math.atan2(e.last.x-(t.x/1e3-.5),-(e.last.z-(t.y/1e3-1)))}else Tt=Math.max(-.24,Math.min(.24,Math.atan2(e.last.x,1.02-e.last.z)));Vn()}});for(let r of["pointercancel","lostpointercapture"])xe("table").addEventListener(r,e=>{wt?.pointerId===e.pointerId&&(wt=null)});xe("replayShot").onclick=()=>{if(!(vn||!ii)){if(Le==="pong"){for(let r of wo)Kl.get(r.id).visible=!ii.next.removed[ii.data.player].includes(r.id)||r.id===ii.data.hit;Ds.visible=!0}lu(ii.data,ii.next)}};xe("shoot").onclick=()=>ec();xe("aim").oninput=()=>{Tt=Number(xe("aim").value)*Math.PI/180,Vn()};xe("power").oninput=()=>{pi=Number(xe("power").value)/100,Vn()};xe("left").onclick=()=>{Tt=Math.max(Le==="pong"?-.24:-Math.PI,Tt-Math.PI/180),Vn()};xe("right").onclick=()=>{Tt=Math.min(Le==="pong"?.24:Math.PI,Tt+Math.PI/180),Vn()};xe("throwType").onchange=Vn;xe("promotion").onchange=ri;xe("ballInHand").onclick=()=>{Fi=!Fi,ri(),Vn()};xe("sound").onclick=()=>{Eo=!Eo,xe("sound").textContent=Eo?"Sound off":"Sound on",au("hit")};xe("camera").onclick=()=>{_r=!_r,xe("camera").textContent=_r?"Perspective":"Overhead",Ql()};xe("reset").onclick=()=>{nt.shots&&!window.confirm("Start a new local game?")||(nt=Xl(Le),Zt=null,ii=null,vn=!1,Tt=0,Jl())};xe("ruleButton").onclick=()=>{xe("rules").style.display="block",xe("rulesTitle").textContent=Le==="pool"?"Eight-ball \xB7 house rules":Le==="pong"?"Six-cup pong":"Classic chess",xe("rulesText").textContent=Le==="pool"?"Break the rack, then claim solids or stripes with your first legal pocket. Sink your group before the eight. A scratch, no object contact, wrong first ball, or no cushion/pocket after contact gives your opponent ball in hand. Sink your own ball to continue. The eight is respotted on the break; an early eight loses. Call-pocket and three-point break rules are not used. Tap to aim or pull backwards and release. Use Place cue after a foul.":Le==="pong"?"Two players take alternating throws at their own six-cup rack. Clear all six to win. Choose an arc or a table bounce. The ball can bounce off the table, rim, and cup walls; a miss passes the turn. There is no redemption round. Pull down for power. Pull sideways to steer away from your finger. The arc and landing ring follow the physics up to the first cup contact. Use the fine controls below for precision.":"Classic legal chess including castling, en passant, promotion, checkmate, stalemate, repetition, fifty-move and insufficient-material draws. White moves first. Tap a piece and a highlighted destination, or use the accessible move buttons below."};xe("closeRules").onclick=()=>{xe("rules").style.display="none"};window.MaroonGame={configure(r){Wd();let e=Le!==r.kind;e&&(ii=null,Tt=0,pi=r.kind==="pong"?.3:.65,_r=r.kind==="pool"),Le=r.kind,as=!!r.online,To=r.yourSeat??0,Di=r.players||["Player 1","Player 2"],Hd=r.interactive!==!1;let t=r.version??0;if(r.error){vn=!1,ri(),xe("status").textContent=r.error;return}if(r.state){let n=r.state;r.replay?.frames&&(ii={data:r.replay,next:n}),!e&&$l>=0&&t>$l&&r.replay?.frames&&gn?lu(r.replay,n):e||$l!==t||!gn?(nt=n,vn=!1,Zt=null,Jl()):(Zt||(vn=!1),ri(),Vn())}else(e||!gn)&&(nt=Xl(Le),vn=!1,Jl());$l=t,ri()},pause(){zn?.suspend()},resume(){Eo||zn?.resume()}};try{Wd(),Mr({type:"ready"}),window.webkit||window.MaroonGame.configure({kind:new URLSearchParams(location.search).get("kind")||"pool"})}catch(r){xe("turn").textContent="The table could not load",xe("status").textContent=r.message,Mr({type:"error",message:r.message})}})();
