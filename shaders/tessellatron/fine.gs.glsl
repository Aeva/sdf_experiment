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


vec3 Slide(vec3 Start, vec3 Stop)
{
	vec3 Position;
	{
		vec3 Ray = normalize(Stop - Start);
		float Travel = 0.0;
		float LastDist = distance(Start, Stop);
		for (int i = 0; i < 10; ++i)
		{
			Position = Ray * Travel + Start;
			float Dist = EdgeMagnet(Position);
			if (Dist <= LastDist)
			{
				Travel += Dist;
				LastDist = Dist;
			}
			else
			{
				break;
			}
		}
		Position = Ray * Travel + Start;
	}
	{
		vec3 Ray = normalize(EdgeGradient(Position));
		for (int i = 0; i < 2; ++i)
		{
			float Dist = EdgeMagnet(Position);
			Position -= Ray * Dist;
		}
	}
	return Position;
}


void main()
{
	int ShapeID = gs_in[0].ShapeID;

	bool Keep = true;
	if (!IsCutShape(ShapeID))
	{
		for (int i = 0; i < 3; ++i)
		{
			if (SmoothCull(gs_in[i].Position.xyz, ShapeID))
			{
				Keep = false;
				break;
			}
		}
	}
	if (Keep)
	{
		int OverlapCount = 0;
		int OverlapMask = 0;
		int Passing = 0;
		for (int i = 0; i < 3; ++i)
		{
			vec3 Position = gs_in[i].Position.xyz;
			bool Passed = IsCutShape(ShapeID) ? (SceneWholeFn(Position) < 0.0) : (Sphere(Position, 2) > 0.0);
			if (Passed)
			{
				++Passing;
			}
			else
			{
				OverlapMask |= 1 << i;
				++OverlapCount;
			}
		}
		if (Passing == 3)
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
		else if (OverlapCount == 1)
		{
			uint Base = atomicAdd(StreamNext, 6);
			if (Base < StreamStop)
			{
				// Slide the outside edge towards the interior point, and then tessellate.
				int A = findLSB(OverlapMask);
				int B = (A + 1) % 3;
				int C = (A + 2) % 3;

				vec3 Anchor =  gs_in[A].Position.xyz;
				vec3 First = gs_in[B].Position.xyz;
				vec3 Second = gs_in[C].Position.xyz;

				vec3 Fnord = Slide(Anchor, First);
				StreamOut[Base + A] = vec4(Fnord, intBitsToFloat(ShapeID));
				StreamOut[Base + B] = vec4(First, intBitsToFloat(ShapeID));
				StreamOut[Base + C] = vec4(Second, intBitsToFloat(ShapeID));

				StreamOut[Base + A + 3] = vec4(Fnord, intBitsToFloat(ShapeID));
				StreamOut[Base + B + 3] = vec4(Second, intBitsToFloat(ShapeID));
				StreamOut[Base + C + 3] = vec4(Slide(Anchor, Second), intBitsToFloat(ShapeID));
			}
			else
			{
				atomicAdd(StreamNext, -6);
			}
		}
		else if (OverlapCount == 2)
		{
			uint Base = atomicAdd(StreamNext, 3);
			if (Base < StreamStop)
			{
				// Slide the interior edge towards the outside point.
				int A = findLSB(OverlapMask);
				int B = findMSB(OverlapMask);
				int C = 3 - A - B;
				vec3 First = gs_in[A].Position.xyz;
				vec3 Second = gs_in[B].Position.xyz;
				vec3 Anchor =  gs_in[C].Position.xyz;

				StreamOut[Base + A] = vec4(Slide(First, Anchor), intBitsToFloat(ShapeID));
				StreamOut[Base + B] = vec4(Slide(Second, Anchor), intBitsToFloat(ShapeID));
				StreamOut[Base + C] = vec4(Anchor, intBitsToFloat(ShapeID));
			}
			else
			{
				atomicAdd(StreamNext, -3);
			}
		}
	}
}
