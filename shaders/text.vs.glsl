prepend: shaders/screen.glsl
--------------------------------------------------------------------------------

out gl_PerVertex
{
  vec4 gl_Position;
  float gl_PointSize;
  float gl_ClipDistance[];
};


layout(std140, binding = 2)
uniform TextInfoBlock
{
    float Line;
    float Width;
};


out vec2 UV;


void main()
{
	const vec2 SlugOffset = vec2(9.0, (Line + 1) * -20.0 + ScreenSize.y);
	const vec2 SlugSize = vec2(Width * 9.0, -20.0);
	const vec4 ScreenBounds = vec4(SlugOffset, SlugOffset + SlugSize);

	const vec4 ClipBounds = ScreenBounds * ScreenSize.zwzw * 2.0 - 1.0;
	//const vec4 ClipBounds = vec4(-1.0, -1.0, 1.0, 1.0);
	vec2 Alpha = vec2(float(((gl_VertexID % 3) & 1) << 2), float(((gl_VertexID % 3) & 2) << 1)) * 0.25;
	if (gl_VertexID > 2)
	{
		Alpha = 1.0 - Alpha;
	}
	UV = Alpha;
	gl_Position = vec4(mix(ClipBounds.xy, ClipBounds.zw, Alpha), 0.0, 1.0);
}
