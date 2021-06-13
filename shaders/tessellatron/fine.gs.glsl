prepend: shaders/standard_boilerplate.glsl
prepend: shaders/tessellation_test/sdf.glsl
--------------------------------------------------------------------------------


in TES_OUT
{
	vec4 Position;
	int CutShape;
} gs_in[];


out GS_OUT
{
	vec3 Position;
	int CutShape;
} gs_out;


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;


void main()
{
	int Passing = 0;
	for (int i = 0; i < 3; ++i)
	{
		if (!(SceneCutFn(gs_in[i].Position.xyz) > 0.00001))
		{
			++Passing;
		}
	}
	if (Passing > 0)
	{
		for (int i = 0; i < 3; ++i)
		{
			gl_Position = gl_in[i].gl_Position;
			gs_out.Position = gs_in[i].Position.xyz;
			gs_out.CutShape = gs_in[i].CutShape;
			EmitVertex();
		}
		EndPrimitive();
	}
}
