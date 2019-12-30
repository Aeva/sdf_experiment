prepend: shaders/raymarch.glsl
prepend: shaders/scene.glsl
--------------------------------------------------------------------------------

layout(location = 0) out int OutObjectId;
layout(depth_any) out float gl_FragDepth;


in vec4 gl_FragCoord;
in flat ObjectInfo Object;
in flat int ObjectId;


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
	return RayDir * max(Object.DepthRange.x - Fudge, 0.0) + CameraOrigin.xyz;
}


void main()
{
	const vec3 WorldRayDir = GetRayDir();
	const vec3 WorldRayStart = GetStartPosition(WorldRayDir);
	const vec3 LocalRayStart = Transform3(Object.WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(Object.WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);
	const RayData Ray = RayData(WorldRayDir, WorldRayStart, LocalRayDir, LocalRayStart);

	vec3 Position;
	bool bFound;
#if ENABLE_CUBETRACE
	if (Object.ShapeParams.w > CUBE_TRACEABLES)
	{
		bFound = CubeTrace(Object, Ray, Position);
	}
	else
#endif
	{
		bFound = RayMarch(Object, Ray, Position);
	}
	if (bFound)
	{
		OutObjectId = ObjectId;
		gl_FragDepth = 1.0 / distance(Position, CameraOrigin.xyz);
	}
	else
	{
		OutObjectId = -1;
		gl_FragDepth = 0.0;
	}
}
