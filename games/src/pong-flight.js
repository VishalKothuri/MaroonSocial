// Aerodynamic force for a 40 mm / 2.7 g hollow ball. Drag equation:
// NASA Glenn, https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/drag-equation/
// Cd=.47 is an explicit smooth-sphere approximation, not a calibrated ball brand.
export const PONG_AIR={density:1.225,coefficient:.47,radius:.02,mass:.0027};
const factor=.5*PONG_AIR.density*PONG_AIR.coefficient*Math.PI*PONG_AIR.radius**2;
export function applyPongDrag(ball){
 const speed=ball.velocity.length();
 if(speed>0){const scale=-factor*speed;ball.force.x+=ball.velocity.x*scale;ball.force.y+=ball.velocity.y*scale;ball.force.z+=ball.velocity.z*scale;}
}
export function pongLaunch(power,bounce){
 return bounce?{forward:2.5+power*1.3,up:1.1+power*.5}:{forward:2.2+power*1.8,up:2.7+power*.9};
}
