prepend: shaders/standard_boilerplate.glsl
prepend: shaders/tessellatron/sdf.glsl
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
	int ShapeID;
} gs_in[];


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;


void main()
{
	vec3 Center = (\
		gs_in[0].Position.xyz + \
		gs_in[1].Position.xyz + \
		gs_in[2].Position.xyz) / 3.0;
	int ShapeID = gs_in[0].ShapeID;

	float Positive = SceneFn(Center);
	float Negative = -Sphere(Center, 2);
	float Other = IsCutShape(ShapeID) ? Positive : Negative;

	if (Other < 0.0)
	{
		uint Base = atomicAdd(StreamNext, 3);
		if (Base < StreamStop)
		{
			for (int i = 0; i < 3; ++i)
			{
				StreamOut[Base + i] = vec4(gs_in[i].Position.xyz, intBitsToFloat(ShapeID));
			}
		}
		else
		{
			atomicAdd(StreamNext, -3);
		}
	}
}
