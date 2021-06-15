prepend: shaders/standard_boilerplate.glsl
prepend: shaders/tessellation_test/sdf.glsl
--------------------------------------------------------------------------------


in TES_OUT
{
	vec4 Position;
	vec3 Barycenter;
	int CutShape;
	float Weight;
} gs_in[];


out GS_OUT
{
	vec3 Position;
	vec3 Barycenter;
	vec3 SubBarycenter;
	int CutShape;
	int Passing;
	float Weight;
} gs_out;


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;


const vec3 SubBarycenters[3] = \
{
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
};


void main()
{
	int Passing = 0;
	for (int i = 0; i < 3; ++i)
	{
		if (gs_in[i].Weight == 1.0 || SceneCutFn(gs_in[i].Position.xyz) <= 0.0001)
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
			gs_out.Barycenter = gs_in[i].Barycenter;
			gs_out.SubBarycenter = SubBarycenters[i];
			gs_out.CutShape = gs_in[i].CutShape;
			gs_out.Passing = Passing;
			gs_out.Weight = gs_in[i].Weight;
			EmitVertex();
		}
		EndPrimitive();
	}
}
