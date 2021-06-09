prepend: shaders/tessellation_test/sdf.glsl
--------------------------------------------------------------------------------


in gl_PerVertex
{
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[];
} gl_in[];


in TES_OUT
{
	vec4 Position;
	int CutShape;
} gs_in[];


out gl_PerVertex
{
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[];
};


out GS_OUT
{
	vec4 Position;
	int CutShape;
} gs_out;


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;


void main()
{
	bool Keep = false;
	for (int i = 0; i < 3; ++i)
	{
		if (!(SceneCutFn(gs_in[i].Position.xyz) > 0.01))
		{
			Keep = true;
			break;
		}
	}
	if (Keep)
	{
		for (int i = 0; i < 3; ++i)
		{
			gl_Position = gl_in[i].gl_Position;
			gs_out.Position = gs_in[i].Position;
			gs_out.CutShape = gs_in[i].CutShape;
			EmitVertex();
		}
		EndPrimitive();
	}
}
