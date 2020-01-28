prepend: shaders/defs.glsl
prepend: shaders/screen.glsl
prepend: shaders/math.glsl
prepend: shaders/shapes.glsl
--------------------------------------------------------------------------------


struct RayData
{
	vec3 WorldDir;
	vec3 WorldStart;
	vec3 LocalDir;
	vec3 LocalStart;
};


#if ENABLE_CUBETRACE
float CubeTrace(const vec3 ShapeBounds, const RayData Ray)
{
	const bvec3 bOutsideBounds = greaterThan(abs(Ray.LocalStart), ShapeBounds);
	if (!any(bOutsideBounds))
	{
		return 0.0;
	}
	const vec3 Planes = sign(Ray.LocalStart) * ShapeBounds;
	const vec3 PlaneDistances = mix(vec3(-1.0), (Planes - Ray.LocalStart) / Ray.LocalDir, bOutsideBounds);
	const float MaxTravel = max(max(PlaneDistances.x, PlaneDistances.y), PlaneDistances.z);
	const vec3 LocalPosition = Ray.LocalDir * MaxTravel + Ray.LocalStart;
	if (MaxTravel >= 0.0 && all(lessThanEqual(abs(LocalPosition), ShapeBounds + AlmostZero)))
	{
		return MaxTravel;
	}
	return -1.0;
}
#endif // ENABLE_CUBETRACE


#if USE_RAYMETHOD == RAYMETHOD_BASIC
bool RayMarchInner(ObjectInfo Object, const RayData Ray, out vec3 Position)
{
	const vec3 LocalRayDir = Ray.LocalDir;
	const vec3 LocalCameraOrigin = Transform3(Object.WorldToLocal, CameraOrigin.xyz);
	vec3 LocalPosition = Ray.LocalStart;

	for (int Step = 0; Step <= MaxIterations; ++Step)
    {
		float SDF = SceneHull(Object.ShapeParams, LocalPosition);
		if (IS_SOLID(SDF))
        {
			Position = Transform3(Object.LocalToWorld, LocalPosition);
			return true;
        }
		else
		{
			LocalPosition += Ray.LocalDir * SDF;
			if (distance(LocalPosition, LocalCameraOrigin) > Object.DepthRange.y)
			{
				break;
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


bool RayMarchInner(ObjectInfo Object, const RayData Ray, out vec3 Position)
{
#define POS_AT_T(T) (T * Ray.LocalDir + Ray.LocalStart)
#define SDF_AT_T(T) SceneHull(Object.ShapeParams, POS_AT_T(T))
#define SPAN(T, SD) T-abs(SD), T+abs(SD), (IS_SOLID(SD) ? -1 : 1)

	// TODO: I don't think this is correct.
	const float RayToCenter = length(Ray.LocalStart);
	const float ShapeRadius = length(Object.ShapeParams.xyz);
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
		Position = Transform3(Object.LocalToWorld, LocalPosition);
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


#if ENABLE_CUBETRACE
bool RayMarch(ObjectInfo Object, RayData Ray, out vec3 Position)
{
	float Distance = CubeTrace(Object.ShapeParams.xyz, Ray);
	if (Distance >= 0.0)
	{
		if (Object.ShapeParams.w > CUBE_TRACEABLES)
		{
			Position = Ray.WorldDir * Distance + Ray.WorldStart;
			return true;
		}
		else
		{
			Ray.LocalStart += Ray.LocalDir * Distance;
			return RayMarchInner(Object, Ray, Position);
		}
	}
	else
	{
		Position = vec3(0.0);
		return false;
	}
}
#else
#define RayMarch RayMarchInner
#endif //ENABLE_CUBETRACE


TRANSMISSION_TYPE OcclusionRayMarch(ObjectInfo Object, const RayData Ray)
{
#if ENABLE_CUBETRACE
	float Distance = CubeTrace(Object.ShapeParams.xyz, Ray);
	if (Distance >= 0.0)
#endif // ENABLE_CUBETRACE
	{
		float Travel = 0.1;
		const float MaxTravel = length(Ray.LocalStart) + length(Object.ShapeParams.xyz);
		for (int Step = 0; Step <= MaxIterations; ++Step)
		{
			const float SDF = SceneHull(Object.ShapeParams, Ray.LocalDir * Travel + Ray.LocalStart);
			Travel += SDF;
			if (IS_SOLID(SDF))
			{
				return TRANSMISSION_TYPE(0.0);
			}
			else if (Travel >= MaxTravel)
			{
				return TRANSMISSION_TYPE(1.0);
			}
		}
	}
	return TRANSMISSION_TYPE(1.0);
}


#if ENABLE_LIGHT_TRANSMISSION
vec3 TransmissiveSearch(ObjectInfo Object, const RayData Ray)
{
#if ENABLE_CUBETRACE
	float Distance = CubeTrace(Object.ShapeParams.xyz, Ray);
	if (Distance >= 0.0)
#endif // ENABLE_CUBETRACE
	{
		float Forward = 0.0;
		float Backward = length(Ray.LocalStart) + length(Object.ShapeParams.xyz);
		for (int Step = 0; Step <= CoarserMaxIterations; ++Step)
		{
			Forward += SceneHull(Object.ShapeParams, Ray.LocalDir * Forward + Ray.LocalStart);
			Backward -= SceneHull(Object.ShapeParams, Ray.LocalDir * Backward + Ray.LocalStart);
			if (Forward >= Backward)
			{
				return vec3(1.0);
			}
		}

		const float StepSize = (Backward - Forward) / float(MaxIterations);
		float Seek = Forward;
		int Buckets[2] = { 0, 0 };
		for (int Step = 0; Step <= MaxIterations; ++Step)
		{
			vec3 Local = Ray.LocalDir * Seek + Ray.LocalStart;
			int Bucket = SceneTransmission(Object.ShapeParams, Ray.LocalDir * Seek + Ray.LocalStart);
			if (Bucket > -1)
			{
				++Buckets[Bucket];
			}
			Seek += StepSize;
		}

		const int ShapeFn = int(Object.ShapeParams.w);
		if (ShapeFn == SHAPE_X_AXIS)
		{
			const vec3 Flesh = vec3(0.935, 0.453, 0.08);
			const vec3 Rind  = vec3(1.0, 0.767, 0.0);
			vec3 Transmission = vec3(1.0);
			float Power = (float(Buckets[0]) * StepSize) / 0.25;
			Transmission *= pow(Rind * 0.6, vec3(Power));

			Power = (float(Buckets[1]) * StepSize) / 0.3;
			Transmission *= pow(Flesh * 0.65, vec3(Power));
			return Transmission;
		}
		else if (ShapeFn == SHAPE_CYAN_SLAB)
		{
			float Power = (float(Buckets[0]) * StepSize) / 0.9;
			return pow(vec3(0.0, 1.0, 1.0), vec3(Power));
		}
		else if (ShapeFn == SHAPE_YELLOW_SLAB)
		{
			float Power = (float(Buckets[0]) * StepSize) / 0.9;
			return pow(vec3(1.0, 1.0, 0.0), vec3(Power));
		}
		else if (ShapeFn == SHAPE_MAGENTA_SLAB)
		{
			float Power = (float(Buckets[0]) * StepSize) / 0.9;
			return pow(vec3(1.0, 0.0, 1.0), vec3(Power));
		}
	}
	return vec3(1.0);
}
#endif // ENABLE_LIGHT_TRANSMISSION
