prepend: shaders/raymarch.glsl
prepend: shaders/paint.glsl
prepend: shaders/scene.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
layout(depth_any) out float gl_FragDepth;


vec3 GetRayDir()
{
	const vec2 NDC = gl_FragCoord.xy * ScreenSize.zw * 2.0 - 1.0;
	vec4 View = ClipToView * vec4(NDC.xy, -1.0, 1.0);
	View = vec4(normalize(vec3(View.x, View.y, View.z) / View.w), 1.0);
	vec4 World = ViewToWorld * View;
	return normalize(vec3(World.xyz / World.w) - CameraOrigin.xyz);
}


vec3 GetStartPosition(const vec3 RayDir)
{
	const float Fudge = 0.2;
	return RayDir * max(DepthRange.x - Fudge, 0.0) + CameraOrigin.xyz;
}


void main()
{
	const vec3 WorldRayDir = GetRayDir();
	const vec3 WorldRayStart = GetStartPosition(WorldRayDir);
	const vec3 LocalRayStart = Transform3(WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);
	const RayData Ray = RayData(WorldRayDir, WorldRayStart, LocalRayDir, LocalRayStart);

	vec3 Position;
	bool bFound;
#if ENABLE_CUBETRACE
	if (ShapeFn > CUBE_TRACEABLES)
	{
		bFound = CubeTrace(Ray, Position);
	}
	else
#endif
	{
		bFound = RayMarch(Ray, Position);
	}
	if (bFound)
	{
		OutColor = vec4(Paint(Position), 1.0);
	}
	else
	{
		discard;
	}
	gl_FragDepth = 1.0 / distance(Position, CameraOrigin.xyz);
}
