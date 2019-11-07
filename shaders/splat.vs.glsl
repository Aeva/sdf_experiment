prepend: shaders/screen.glsl
--------------------------------------------------------------------------------

out gl_PerVertex
{
  vec4 gl_Position;
  float gl_PointSize;
  float gl_ClipDistance[];
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
	// (-1.0, -1.0) is the upper-left corner of the screen.
	vec2 Alpha = vec2(float(((gl_VertexID % 3) & 1) << 2), float(((gl_VertexID % 3) & 2) << 1)) * 0.25;
	if (gl_VertexID > 2)
	{
		Alpha = 1.0 - Alpha;
	}
	gl_Position = vec4(mix(ClipBounds.xy, ClipBounds.zw, Alpha), 0.0, 1.0);
}
