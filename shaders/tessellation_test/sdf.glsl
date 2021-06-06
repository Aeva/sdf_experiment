--------------------------------------------------------------------------------

#define EPSILON 0.0001
#define DISCARD 0.025

#define CUTS 3
#define COARSE_ITERATIONS 1
#define FINE_ITERATIONS 4


float Sphere(vec3 p, float s)
{
	return length(p) - s;
}


float SmoothUnion(float d1, float d2, float k)
{
	float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
	return mix(d2, d1, h) - k * h * (1.0 - h);
}


float SceneFn(vec3 Point)
{
	return Sphere(Point, 1.0);
}


vec3 Gradient(vec3 Point)
{
	vec3 Fnord = vec3(EPSILON, 0.0, 0.0);

	vec3 High = vec3(
		SceneFn(Point + Fnord.xyz),
		SceneFn(Point + Fnord.zxy),
		SceneFn(Point + Fnord.yzx));

	vec3 Low = vec3(
		SceneFn(Point - Fnord.xyz),
		SceneFn(Point - Fnord.zxy),
		SceneFn(Point - Fnord.yzx));

	return (High - Low) / (2.0 * EPSILON);

	return vec3(0.0);
}


void Coarse(inout vec3 Position, inout vec3 Normal)
{
	for (int i=0; i<COARSE_ITERATIONS; ++i)
	{
		Position -= Normal * SceneFn(Position);
		Normal = normalize(Gradient(Position));
	}
}

void Fine(inout vec3 Position, inout vec3 Normal)
{
	for (int i=0; i<FINE_ITERATIONS; ++i)
	{
		Position -= Normal * SceneFn(Position);
		Normal = normalize(Gradient(Position));
	}
}
