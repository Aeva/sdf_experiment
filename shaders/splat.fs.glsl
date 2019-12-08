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
	vec3 Position;
#if ENABLE_CUBETRACE
	if (ShapeFn > CUBE_TRACEABLES)
	{
		if (CubeTrace(Position))
		{
			OutColor = vec4(PaintCube(Position), 1.0);
		}
		else
		{
			discard;
		}
	}
	else
#endif
	{
		ColorSDF Scene;
		RayMarch(Position, Scene);
		if (Scene.PaintFn == PAINT_DISCARD)
		{
			discard;
		}
#if !ENABLE_CUBETRACE
		else if (Scene.PaintFn == PAINT_CUBE)
		{
			OutColor = vec4(PaintCube(Position), 1.0);
		}
#endif
		else
		{
			OutColor = vec4(Paint(Position, Scene), 1.0);
		}
	}
	gl_FragDepth = 1.0 / distance(Position, CameraOrigin.xyz);
}
