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
};


void main()
{
	Position = StreamIn[gl_VertexID].xyz;
	gl_Position = ViewToClip * WorldToView * vec4(Position, 1.0);
}
