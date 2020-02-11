prepend: shaders/defs.glsl
prepend: shaders/math.glsl
prepend: shaders/screen.glsl
prepend: shaders/scene.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
layout(binding = 1) uniform sampler2D DepthBuffer;
layout(binding = 3) uniform sampler2D NormalBuffer;
layout(binding = 4) uniform sampler2D ColorBuffer;
layout(binding = 5) uniform sampler2D GloomBuffer;


vec3 GetRayDir()
{
	const vec2 NDC = gl_FragCoord.xy * ScreenSize.zw * 2.0 - 1.0;
	vec4 View = ClipToView * vec4(NDC.xy, -1.0, 1.0);
	View = vec4(normalize(vec3(View.x, View.y, View.z) / View.w), 1.0);
	vec4 World = ViewToWorld * View;
	return normalize(vec3(World.xyz / World.w) - CameraOrigin.xyz);
}


vec3 Illuminate(const vec3 BaseColor, const vec3 WorldPosition, const vec3 WorldNormal, const vec3 Transmission, bool bIsTransmissive)
{
	const vec3 ShadowColor = BaseColor * 0.5;

#if VISUALIZE_NORMAL_LENGTH
	const float Magnitude = length(WorldNormal);
	if (Magnitude >= 1.0 - AlmostZero && Magnitude <= 1.0 + AlmostZero)
	{
		return vec3(1.0);
	}
	else if (Magnitude != Magnitude)
	{
		return vec3(1.0, 0.0, 0.0);
	}
	else if (isinf(Magnitude))
	{
		return vec3(0.0, 0.0, 1.0);
	}
	else
	{
		return vec3(0.0, 1.0, 0.0);
	}
#endif // VISUALIZE_NORMAL_LENGTH

	// Sun Light
	const vec3 LightRay = normalize(SUN_DIR);
	const float CosAngleToLight = dot(LightRay, WorldNormal);
	vec3 LightAlpha = vec3(0.0, 0.0, 0.0);

#if ENABLE_LIGHT_TRANSMISSION
	if (CosAngleToLight <= 0 && bIsTransmissive)
	{
		LightAlpha = Transmission * abs(CosAngleToLight);
	}
	else
#endif // ENABLE_LIGHT_TRANSMISSION
	{
		LightAlpha = vec3(Transmission * max(CosAngleToLight, 0.0));
	}

#if VISUALIZE_TRANSMISSION
	return LightAlpha;
#else
	return mix(ShadowColor, BaseColor, LightAlpha);
#endif // VISUALIZE_TRANSMISSION
}


void main()
{
	const vec2 UV = gl_FragCoord.xy * ScreenSize.zw;
	const float Depth = texture(DepthBuffer, UV).r;
	if (Depth == 0)
	{
		OutColor = vec4(0.729, 0.861, 0.951, 1.0);
		return;
	}
	else
	{
		const vec3 RayDir = GetRayDir();
		const float Travel = 1.0 / Depth;
		const vec3 Position = RayDir * Travel + CameraOrigin.xyz;
		const vec3 Normal = texture(NormalBuffer, UV).rgb;
		const vec4 Color = texture(ColorBuffer, UV).rgba;
#if ENABLE_LIGHT_TRANSMISSION
		const vec3 Gloom = texture(GloomBuffer, UV).rgb;
#else
		const vec3 Gloom = texture(GloomBuffer, UV).rrr;
#endif // ENABLE_LIGHT_TRANSMISSION
		const bool bIsTransmissive = Color.a > 0;
		OutColor = vec4(Illuminate(Color.rgb, Position, Normal, Gloom, bIsTransmissive), 1.0);
	}
}
