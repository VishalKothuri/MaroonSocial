import * as CANNON from 'cannon-es';

// Cup wall/bottom separation and bottom-contact scoring adapted from
// JBallin/beer-pong, ARViewController.addCupsPhysics/physicsWorld(didBegin:),
// commit 8f1e420ffce5bc396105e49450651e306d4089b9 (MIT, © 2019 JBallin).
// See licenses/JBallin-beer-pong.txt. Adaptations: deterministic Cannon bodies,
// matching tapered geometry, bounded restitution, and explicit body IDs rather
// than relying on contact node ordering. Original SceneKit assets are not used.
export const CUP_MATERIALS={wallRestitution:.1,bottomRestitution:0};
export const CUP_SHAPE={baseRadius:.044,topRadius:.065,bottomTop:.012,top:.146,thickness:.003,segments:24};
export function addPongCup(world,cup,wallMaterial,bottomMaterial){
  const {baseRadius,topRadius,bottomTop,top,thickness,segments}=CUP_SHAPE;
  const wall=new CANNON.Body({mass:0,material:wallMaterial,position:new CANNON.Vec3(cup.x,0,cup.z)});
  const rise=top-bottomTop,run=topRadius-baseRadius,tilt=Math.atan2(run,rise);
  const radius=(baseRadius+topRadius)/2+thickness;
  // Overlapping tangent slats create a hollow tapered cup, including its rim.
  // The lumen stays open, unlike a convex whole-cup hull.
  for(let i=0;i<segments;i++){
    const a=i*Math.PI*2/segments;
    const yaw=new CANNON.Quaternion();yaw.setFromAxisAngle(new CANNON.Vec3(0,1,0),-a);
    const lean=new CANNON.Quaternion();lean.setFromAxisAngle(new CANNON.Vec3(0,0,1),-tilt);
    const rotation=yaw.mult(lean);
    wall.addShape(new CANNON.Box(new CANNON.Vec3(thickness,Math.hypot(rise,run)/2,topRadius*Math.tan(Math.PI/segments)*1.04)),new CANNON.Vec3(Math.cos(a)*radius,(top+bottomTop)/2,Math.sin(a)*radius),rotation);
    wall.addShape(new CANNON.Sphere(.0035),new CANNON.Vec3(Math.cos(a)*.069,.149,Math.sin(a)*.069));
  }
  world.addBody(wall);
  const bottom=new CANNON.Body({mass:0,material:bottomMaterial,
    shape:new CANNON.Cylinder(baseRadius,baseRadius,.008,segments),
    position:new CANNON.Vec3(cup.x,bottomTop-.004,cup.z)});
  world.addBody(bottom);
  return bottom;
}
