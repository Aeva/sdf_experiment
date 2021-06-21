prepend: shaders/tessellatron/objects.glsl
--------------------------------------------------------------------------------

#define EPSILON 0.0001

#define CUTS 3
#define COARSE_ITERATIONS 1
#define FINE_ITERATIONS 4


bool IsCutShape(int ShapeID)
{
	return ShapeID == 2;
}


float Sphere(vec3 Point, int SphereID)
{
	vec3 Translate = SphereParams[SphereID].xyz;
	float Radius = abs(SphereParams[SphereID].w);
	return length(Point - Translate) - Radius;
}


float SmoothUnion(float d1, float d2, float k)
{
	float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
	return mix(d2, d1, h) - k * h * (1.0 - h);
}


float Cut(float d1, float d2)
{
	return max(d1, -d2);
}


float SceneWholeFn(vec3 Point)
{
	return SmoothUnion(
		Sphere(Point, 0),
		Sphere(Point, 1),
		0.6);
}


float SceneFn(vec3 Point, int ShapeID)
{
	int Local = ShapeID == 0 ? 0 : 1;
	int Other = ShapeID == 0 ? 1 : 0;
	float A = Sphere(Point, Local);
	float B = Sphere(Point, Other);
	float K = 0.6;

	float Ideal = SmoothUnion(A, B, K);
	float Force = 0.5 + 0.5 * (B - A) / K;
	return Cut(Ideal, Force);
}


float SceneCutFn(vec3 Point)
{
	return Cut(
		SmoothUnion(
			Sphere(Point, 0),
			Sphere(Point, 1),
			0.6),
		Sphere(Point, 2));
}


float EdgeMagnet(vec3 Point)
{
	float A = SmoothUnion(
		Sphere(Point, 0),
		Sphere(Point, 1),
		0.6);
	float B = Sphere(Point, 2);
	return length(vec2(A, B));
}


vec3 Gradient(vec3 Point, int ShapeID)
{
	vec3 Fnord = vec3(EPSILON, 0.0, 0.0);

	vec3 High = vec3(
		SceneFn(Point + Fnord.xyz, ShapeID),
		SceneFn(Point + Fnord.zxy, ShapeID),
		SceneFn(Point + Fnord.yzx, ShapeID));

	vec3 Low = vec3(
		SceneFn(Point - Fnord.xyz, ShapeID),
		SceneFn(Point - Fnord.zxy, ShapeID),
		SceneFn(Point - Fnord.yzx, ShapeID));

	return (High - Low) / (2.0 * EPSILON);
}


vec3 EdgeGradient(vec3 Point)
{
	vec3 Fnord = vec3(EPSILON, 0.0, 0.0);

	vec3 High = vec3(
		EdgeMagnet(Point + Fnord.xyz),
		EdgeMagnet(Point + Fnord.zxy),
		EdgeMagnet(Point + Fnord.yzx));

	vec3 Low = vec3(
		EdgeMagnet(Point - Fnord.xyz),
		EdgeMagnet(Point - Fnord.zxy),
		EdgeMagnet(Point - Fnord.yzx));

	return (High - Low) / (2.0 * EPSILON);
}


vec3 GradientCut(vec3 Point, int SphereID)
{
	vec3 Fnord = vec3(EPSILON, 0.0, 0.0);

	vec3 High = vec3(
		Sphere(Point + Fnord.xyz, SphereID),
		Sphere(Point + Fnord.zxy, SphereID),
		Sphere(Point + Fnord.yzx, SphereID));

	vec3 Low = vec3(
		Sphere(Point - Fnord.xyz, SphereID),
		Sphere(Point - Fnord.zxy, SphereID),
		Sphere(Point - Fnord.yzx, SphereID));

	return (High - Low) / (2.0 * EPSILON);
}


vec3 GradientFinal(vec3 Point)
{
	vec3 Fnord = vec3(EPSILON, 0.0, 0.0);

	vec3 High = vec3(
		SceneCutFn(Point + Fnord.xyz),
		SceneCutFn(Point + Fnord.zxy),
		SceneCutFn(Point + Fnord.yzx));

	vec3 Low = vec3(
		SceneCutFn(Point - Fnord.xyz),
		SceneCutFn(Point - Fnord.zxy),
		SceneCutFn(Point - Fnord.yzx));

	return (High - Low) / (2.0 * EPSILON);
}


void Coarse(inout vec3 Position, inout vec3 Normal, int ShapeID)
{
	if (IsCutShape(ShapeID))
	{
		for (int i=0; i<COARSE_ITERATIONS; ++i)
		{
			Position -= Normal * Sphere(Position, ShapeID);
		}
		Normal = GradientCut(Position, ShapeID);
	}
	else
	{
		for (int i=0; i<COARSE_ITERATIONS; ++i)
		{
			Normal = normalize(mix(Normal, Gradient(Position, ShapeID), 0.5));
			Position -= Normal * SceneFn(Position, ShapeID);
		}
	}
}


void Fine(inout vec3 Position, inout vec3 Normal, int ShapeID)
{
	vec3 Grade = Normal;
	if (IsCutShape(ShapeID))
	{
		for (int i=0; i<FINE_ITERATIONS; ++i)
		{
			Grade = GradientCut(Position, ShapeID);
			Normal = normalize(mix(Normal, Grade, 0.5));
			Position -= Normal * Sphere(Position, ShapeID);
		}
	}
	else
	{
		for (int i=0; i<FINE_ITERATIONS; ++i)
		{
			Grade = Gradient(Position, ShapeID);
			Normal = normalize(mix(Normal, Grade, 0.5));
			Position -= Normal * SceneFn(Position, ShapeID);
		}
	}
	Normal = Grade;
}
