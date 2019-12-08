prepend: shaders/defs.glsl
prepend: shaders/screen.glsl
prepend: shaders/math.glsl
prepend: shaders/shapes.glsl
--------------------------------------------------------------------------------


vec3 GetRayDir();
vec3 GetStartPosition(const vec3 RayDir);


#if ENABLE_CUBETRACE
bool CubeTrace(out vec3 Position)
{
	const vec3 WorldRayDir = GetRayDir();
	const vec3 WorldRayStart = GetStartPosition(WorldRayDir);
	const vec3 LocalRayStart = Transform3(WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);

	float SDF = sdBox(LocalRayStart, ShapeBounds);
	if (IS_SOLID(SDF))
	{
		Position = WorldRayStart;
		return true;
	}

	const vec3 Fnord1 = (-ShapeBounds - LocalRayStart) / LocalRayDir;
	const vec3 Fnord2 = (ShapeBounds - LocalRayStart) / LocalRayDir;
	float RayDists[6] = \
	{
		Fnord1.x,
		Fnord1.y,
		Fnord1.z,
		Fnord2.x,
		Fnord2.y,
		Fnord2.z
	};

	for (int t = 0; t < 5; ++t)
	{
		for (int i = 0; i < 5; ++i)
		{
			const float a = RayDists[i];
			const float b = RayDists[i+1];
			RayDists[i] = min(a, b);
			RayDists[i+1] = max(a, b);
		}
	}

	for (int i = 0; i < 3; ++i)
	{
		const vec3 LocalPosition = RayDists[i] * LocalRayDir + LocalRayStart;
		SDF = sdBox(LocalPosition, ShapeBounds);
		if (IS_SOLID(SDF))
		{
			Position = RayDists[i] * WorldRayDir + WorldRayStart;
			return true;
		}
	}

	Position = vec3(0.0);
	return false;
}
#endif // ENABLE_CUBETRACE


#if USE_RAYMETHOD == RAYMETHOD_BASIC
bool RayMarch(out vec3 Position)
{
	const vec3 WorldRayDir = GetRayDir();
	const vec3 WorldRayStart = GetStartPosition(WorldRayDir);
	vec3 LocalPosition = Transform3(WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(WorldToLocal, WorldRayStart + WorldRayDir) - LocalPosition);
	const vec3 LocalCameraOrigin = Transform3(WorldToLocal, CameraOrigin.xyz);

	for (int Step = 0; Step <= MaxIterations; ++Step)
    {
		float SDF = SceneHull(LocalPosition);
		if (IS_SOLID(SDF))
        {
			Position = Transform3(LocalToWorld, LocalPosition);
			return true;
        }
		else
		{
			LocalPosition += LocalRayDir * SDF;
			if (distance(LocalPosition, LocalCameraOrigin) > DepthRange.y)
			{
				break;
			}
		}
    }

	Position = vec3(0.0);
	return false;
}


#elif USE_RAYMETHOD == RAYMETHOD_CUBE_ELIMINATE
bool RayMarch(out vec3 Position)
{
	const vec3 WorldRayDir = GetRayDir();
	const vec3 WorldRayStart = GetStartPosition(WorldRayDir);
	const vec3 LocalRayStart = Transform3(WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);

	const vec3 BoxExtent = ShapeBounds;

	float SDF = sdBox(LocalRayStart, ShapeBounds);
	if (IS_SOLID(SDF))
	{
		Position = WorldRayStart;
		return true;
	}

	const vec3 Fnord1 = (-BoxExtent - LocalRayStart) / LocalRayDir;
	const vec3 Fnord2 = (BoxExtent - LocalRayStart) / LocalRayDir;
	float RayDists[6] = \
	{
		Fnord1.x,
		Fnord1.y,
		Fnord1.z,
		Fnord2.x,
		Fnord2.y,
		Fnord2.z
	};

	for (int t = 0; t < 5; ++t)
	{
		for (int i = 0; i < 5; ++i)
		{
			const float a = RayDists[i];
			const float b = RayDists[i+1];
			RayDists[i] = min(a, b);
			RayDists[i+1] = max(a, b);
		}
	}

	bool bFound = false;
	float RayDistance;
	for (int i = 0; i < 3; ++i)
	{
		vec3 LocalPosition = RayDists[i] * LocalRayDir + LocalRayStart;
		if (IS_SOLID(sdBox(LocalPosition, BoxExtent)))
		{
			RayDistance = RayDists[i];
			bFound = true;
			break;
		}
	}
	if (bFound)
	{
		const float EndRayDist = RayDists[5];
		for (int Step = 0; Step <= MaxIterations; ++Step)
	    {
			const vec3 LocalPosition = RayDistance * LocalRayDir + LocalRayStart;
			const float SDF = SceneHull(LocalPosition);
			if (IS_SOLID(SDF))
		    {
				Position = Transform3(LocalToWorld, LocalPosition);
				return true;
			}
			else
			{
				RayDistance += SDF;
				if (RayDistance > EndRayDist)
				{
					break;
				}
			}
		}
	}

	Position = vec3(0.0);
	return false;
}


#elif USE_RAYMETHOD == RAYMETHOD_COVERAGE_SEARCH
// TODO: we could be clever and nix the Sign field to improve occupancy.
struct Coverage
{
	float Low;
	float High;
	int Sign;
};


bool RayMarch(out vec3 Position)
{
	const vec3 WorldRayDir = GetRayDir();
	const vec3 WorldRayStart = GetStartPosition(WorldRayDir);
	const vec3 LocalRayStart = Transform3(WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);

#define POS_AT_T(T) (T * LocalRayDir + LocalRayStart)
#define SDF_AT_T(T) SceneHull(POS_AT_T(T))
#define SPAN(T, SD) T-abs(SD), T+abs(SD), (IS_SOLID(SD) ? -1 : 1)

	// TODO: I don't think this is correct.
	const float RayToCenter = length(LocalRayStart);
	const float ShapeRadius = length(ShapeBounds);
	const float StartT = RayToCenter - ShapeRadius;
	const float EndT = RayToCenter + ShapeRadius;

	const float PivotT = (StartT + EndT) * 0.5;
	const float PivotD = SDF_AT_T(PivotT);

	const int MaxStack = 10;
	Coverage Stack[MaxStack];
	// TODO: We can probably be clever and remove the first entry on the stack and just push it
	// when the stack drains out the first time, or something like that.
	Stack[0] = Coverage(EndT, EndT, 0);
	Stack[1] = Coverage(SPAN(PivotT, PivotD));
	int Top = 1;
	Coverage Cursor = Coverage(StartT, StartT, 0);

	for (int i=0; i<MaxIterations; ++i)
	{
		if ((Stack[Top].Low - AlmostZero) <= Cursor.High)
		{
			Cursor = Stack[Top];
			--Top;
			if (Top == -1 || Cursor.Sign < 0)
			{
				break;
			}
		}
		else
		{
			const float NextT = (Stack[Top].Low + Cursor.High) * 0.5;
			const float NextD = SDF_AT_T(NextT);
			const Coverage Next = Coverage(SPAN(NextT, NextD));
			if (Stack[Top].Sign == Next.Sign && (Stack[Top].Low - AlmostZero) <= Next.High)
			{
				Stack[Top].Low = Next.Low;
			}
			else if (Top < MaxStack - 1)
			{
				++Top;
				Stack[Top] = Next;
			}
			else
			{
				// Whoops, ran out of stack!
				break;
			}
		}
	}

	if (Cursor.Sign == -1)
	{
		const float HitT = max(StartT, Cursor.Low);
		const vec3 LocalPosition = POS_AT_T(HitT);
		Position = Transform3(LocalToWorld, LocalPosition);
		return true;
	}
	else
	{
		Position = vec3(0.0);
		return false;
	}
#undef SPAN
#undef SDF_AT_T
#undef POS_AT_T
}


#endif // USE_RAYMETHOD
