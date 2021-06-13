prepend: shaders/tessellation_test/sdf.glsl
prepend: shaders/view.glsl
--------------------------------------------------------------------------------

#define VISUALIZE_PRECISION 0
#define VISUALIZE_PRIMITIVE 1
#define ALLOW_DISCARD 1

layout(location = 0) out vec4 OutColor;
in vec4 gl_FragCoord;


in TES_OUT
{
	vec3 Position;
	vec3 Barycenter;
	vec3 SubBarycenter;
	flat int CutShape;
};


#if VISUALIZE_PRECISION
vec3 VisualizePrecision()
{
	vec3 Red = vec3(1.0, 0.0, 0.0);
	vec3 Green = Red.yxz;
	vec3 Blue = Red.zxy;
	vec3 Black = Red.zzz;
	vec3 White = Red.xxx;
	float Dist = SceneCutFn(Position);
	if (Dist == 0.0)
	{
		return Green;
	}
	else if (abs(Dist) <= 0.0001)
	{
		float Alpha = abs(Dist) / 0.0001;
		return mix(Green, Blue, Alpha);
	}
	else if (Dist <= 0.0)
	{
		float Alpha = Dist / -0.001;
		return mix(Green, Black, Alpha);
	}
	else if (abs(Dist) <= 0.001)
	{
		Dist = abs(Dist) - 0.0001;
		float Alpha = Dist / 0.0009;
		return mix(Blue, Red, Alpha);
	}
	else
	{
		return White;
	}
}
#endif


void main ()
{
#if ALLOW_DISCARD
	if (SceneCutFn(Position) > 0.0001)
	{
		discard;
	}
#endif
#if VISUALIZE_PRECISION
	OutColor = vec4(VisualizePrecision(), 1.0);
#elif VISUALIZE_PRIMITIVE
	if (Barycenter.x < 0.05 || Barycenter.y < 0.05 || Barycenter.z < 0.05)
	{
		OutColor = vec4(0.0, 0.0, 1.0, 1.0);
	}
	else if (SubBarycenter.x < 0.075 || SubBarycenter.y < 0.075 || SubBarycenter.z < 0.075)
	{
		OutColor = vec4(1.0, 0.0, 0.0, 1.0);
	}
	else
	{
		OutColor = vec4(0.85, 0.85, 0.85, 1.0);
	}
#else
	{
		vec3 Normal = normalize(GradientFinal(Position));
		OutColor = vec4((Normal + 1.0) * 0.5, 1.0);
	}
#endif
}
