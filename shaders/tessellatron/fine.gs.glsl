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
	int CutShape;
} gs_in[];


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;


void main()
{
	bool Passing = \
		SceneCutFn(gs_in[0].Position.xyz) <= 0.001 || \
		SceneCutFn(gs_in[1].Position.xyz) <= 0.001 || \
		SceneCutFn(gs_in[2].Position.xyz) <= 0.001;
	if (Passing)
	{
		uint Base = atomicAdd(StreamNext, 3);
		if (Base < StreamStop)
		{
			for (int i = 0; i < 3; ++i)
			{
				StreamOut[Base + i] = vec4(gs_in[i].Position.xyz, intBitsToFloat(gs_in[i].CutShape));
			}
		}
		else
		{
			atomicAdd(StreamNext, -3);
		}
	}
}
