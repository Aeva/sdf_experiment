prepend: shaders/screen.glsl
--------------------------------------------------------------------------------

out gl_PerVertex
{
  vec4 gl_Position;
  float gl_PointSize;
  float gl_ClipDistance[];
};


out flat mat4 LocalToWorld;
out flat mat4 WorldToLocal;
out flat vec2 DepthRange;
out flat int ShapeFn;


struct ObjectInfo
{
	vec4 ClipBounds; // (MinX, MinY, MaxX, MaxY)
	vec4 DepthRange; // (Min, Max, 0.0, 0.0)
	mat4 LocalToWorld;
	mat4 WorldToLocal;
	int ShapeFn;
};


layout(std430, binding = 0) readonly buffer ObjectsBlock
{
	ObjectInfo Objects[];
};


void main()
{
/*
0, 0
1, 0
0, 1

1, 1
0, 1
1, 0
*/
	LocalToWorld = Objects[gl_InstanceID].LocalToWorld;
	WorldToLocal = Objects[gl_InstanceID].WorldToLocal;
	DepthRange = Objects[gl_InstanceID].DepthRange.xy;
	ShapeFn = Objects[gl_InstanceID].ShapeFn;
	vec4 ClipBounds = Objects[gl_InstanceID].ClipBounds;

	// (-1.0, -1.0) is the upper-left corner of the screen.
	vec2 Alpha = vec2(float(((gl_VertexID % 3) & 1) << 2), float(((gl_VertexID % 3) & 2) << 1)) * 0.25;
	if (gl_VertexID > 2)
	{
		Alpha = 1.0 - Alpha;
	}
	gl_Position = vec4(mix(ClipBounds.xy, ClipBounds.zw, Alpha), 0.0, 1.0);
}
