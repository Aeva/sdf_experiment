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
	vec3 Barycenter;
	int ShapeID;
} gs_in[];


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;


void main()
{
	{
		uint Base = atomicAdd(StreamNext, 3);
		if (Base < StreamStop)
		{
			for (int i = 0; i < 3; ++i)
			{
				StreamOut[Base + i] = vec4(gs_in[i].Position.xyz, intBitsToFloat(gs_in[i].ShapeID));
			}
		}
		else
		{
			atomicAdd(StreamNext, -3);
		}
	}
}
