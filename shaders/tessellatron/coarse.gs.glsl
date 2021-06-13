prepend: shaders/standard_boilerplate.glsl
prepend: shaders/tessellation_test/sdf.glsl
--------------------------------------------------------------------------------


layout(std430, binding = 0) restrict buffer TriangleMeta
{
	uint StreamStop;
	uint StreamNext;
};


layout(std430, binding = 1) writeonly buffer TriangleStream
{
	vec4 StreamOut[];
};


in TES_OUT
{
	vec4 Position;
	vec3 Barycenter;
	int CutShape;
} gs_in[];


out GS_OUT
{
	vec3 Position;
	vec3 Barycenter;
	vec3 SubBarycenter;
	int CutShape;
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
		if (!(SceneCutFn(gs_in[i].Position.xyz) > 0.00001))
		{
			++Passing;
		}
	}
	if (Passing == 3)
	{
		for (int i = 0; i < 3; ++i)
		{
			gl_Position = gl_in[i].gl_Position;
			gs_out.Position = gs_in[i].Position.xyz;
			gs_out.Barycenter = gs_in[i].Barycenter;
			gs_out.SubBarycenter = SubBarycenters[i];
			gs_out.CutShape = gs_in[i].CutShape;
			EmitVertex();
		}
		EndPrimitive();
	}
	else if (Passing > 0)
	{
		uint Base = atomicAdd(StreamNext, 3);
		if (Base < StreamStop)
		{
			for (int i = 0; i < 3; ++i)
			{
				StreamOut[Base + i] = vec4(gs_in[i].Position.xyz, intBitsToFloat(gs_in[i].CutShape));
			}
		}
	}
}
