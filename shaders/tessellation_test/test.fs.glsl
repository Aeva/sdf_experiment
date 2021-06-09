prepend: shaders/tessellation_test/sdf.glsl
prepend: shaders/view.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
in vec4 gl_FragCoord;


in TES_OUT
{
	vec4 Position;
	flat int CutShape;
};


void main ()
{
#if 0
	vec3 RayDir = normalize(Position.xyz - CameraOrigin.xyz);
	vec3 Origin = Position.xyz;
	float Distance = 0.0;
	for (int i = 0; i < 1000; ++i)
	{
		Distance = SceneCutFn(RayDir * Distance + Origin);
	}
	if (Distance > 0.002)
	{
		discard;
	}
	vec3 NewPosition = RayDir * -Distance + Origin;
#else
	vec3 NewPosition = Position.xyz;
	if (SceneCutFn(NewPosition) > 0.001)
	{
		discard;
	}
#endif

	vec3 Normal = normalize(GradientFinal(NewPosition));
	OutColor = vec4((Normal + 1.0) * 0.5, 1.0);
}
