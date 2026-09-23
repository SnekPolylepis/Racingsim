shader_type spatial;
render_mode vertex_lighting, cull_disabled;
// Original wire pattern; 2 triangles per barrier span instead of modelled wire.
varying vec2 metres;
void vertex() {
 metres = UV * vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
}
void fragment() {
 vec2 mesh = metres * vec2(5., 5.);
 vec2 diamond = vec2(mesh.x + mesh.y, mesh.x - mesh.y);
 vec2 edge = abs(fract(diamond) - .5);
 // Remove sub-pixel diamond wires before they turn into bright aliasing dots.
 float footprint = max(length(dFdx(diamond)), length(dFdy(diamond)));
 float wire = step(.465, max(edge.x, edge.y)) * (1. - smoothstep(.3, .8, footprint));
 float rail = step(.485, abs(fract(metres.y) - .5));
 ALBEDO = vec3(.13, .15, .14);
 ALPHA = max(wire, rail);
 ALPHA_SCISSOR_THRESHOLD = .5;
 ROUGHNESS = .75;
}
