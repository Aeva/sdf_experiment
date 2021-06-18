prepend: shaders/standard_boilerplate.glsl
prepend: shaders/view.glsl
--------------------------------------------------------------------------------


layout(std430, binding = 2) Readonly buffer TriangleStream
{
	vec4 StreamIn[];
};


out VS_OUT
{
	vec3 Position;
	vec3 Barycenter;
};


const vec3 Barycenters[3] = \
{
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
};


void main()
{
	Position = StreamIn[gl_VertexID].xyz;
	gl_Position = ViewToClip * WorldToView * vec4(Position, 1.0);
	Barycenter = Barycenters[gl_VertexID % 3];
}
