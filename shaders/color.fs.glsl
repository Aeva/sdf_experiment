prepend: shaders/defs.glsl
prepend: shaders/math.glsl
prepend: shaders/screen.glsl
prepend: shaders/objects.glsl
prepend: shaders/scene.glsl
prepend: shaders/paint.glsl
prepend: shaders/raymarch.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
layout(std430, binding = 0) readonly buffer ObjectsBlock
{
	ObjectInfo Objects[];
};
layout(binding = 1) uniform sampler2D DepthBuffer;
layout(binding = 2) uniform isampler2D ObjectIdBuffer;
#if ENABLE_SUN_SHADOWS
layout(std430, binding = 3) readonly buffer ShadowCoverageBlock
{
	ShadowCoverageInfo ShadowCoverage[];
};
#endif // ENABLE_SUN_SHADOWS


vec3 GetRayDir()
{
	const vec2 NDC = gl_FragCoord.xy * ScreenSize.zw * 2.0 - 1.0;
	vec4 View = ClipToView * vec4(NDC.xy, -1.0, 1.0);
	View = vec4(normalize(vec3(View.x, View.y, View.z) / View.w), 1.0);
	vec4 World = ViewToWorld * View;
	return normalize(vec3(World.xyz / World.w) - CameraOrigin.xyz);
}


void Reconstitute(out vec3 Position, out int ObjectId)
{
	const vec2 UV = gl_FragCoord.xy * ScreenSize.zw;
	const float Depth = texture(DepthBuffer, UV).r;
	if (Depth == 0)
	{
		Position = vec3(0.0);
		ObjectId = -1;
	}
	else
	{
		const vec3 RayDir = GetRayDir();
		const float Travel = 1.0 / Depth;
		Position = RayDir * Travel + CameraOrigin.xyz;
		ObjectId = texture(ObjectIdBuffer, UV).r;
	}
}


#if ENABLE_SOFT_SHADOWS
vec2 Noise(vec2 Point)
{
    Point = fract(Point * 0.1) + 1.0 + Point * vec2(2.0, 3.0) / 1e4;
    Point = fract(1e5 / (0.1 * Point.x * (Point.y + vec2(0.0, 1.0)) + 1.0));
    Point = fract(1e5 / (Point * vec2(0.1234, 2.35) + 1.0));
    return Point;
}
#endif // ENABLE_SOFT_SHADOWS


void main ()
{
	vec3 Position;
	int ObjectId;
	Reconstitute(Position, ObjectId);

	if (ObjectId == -1)
	{
		OutColor = vec4(0.729, 0.861, 0.951, 1.0);
	}
	else
	{
#if VISUALIZE_ALIASING_GRADIENT
		OutColor = vec4(0.0, 1.0, 0.0, 1.0);
		const float Scale = 10.0;
		if (dFdx(gl_FragCoord.x) == 1.0)
		{
			OutColor.g -= 0.5;
			OutColor.r = length(dFdx(Position)) * Scale;
		}
		if (dFdy(gl_FragCoord.y) == 1.0)
		{
			OutColor.g -= 0.5;
			OutColor.b = length(dFdy(Position)) * Scale;
		}
#else
		ObjectInfo Object = Objects[ObjectId];

#if VISUALIZE_SHADOW_COVERAGE
		int CoverageCount = 0;
#endif // VISUALIZE_SHADOW_COVERAGE

#if ENABLE_SUN_SHADOWS
		float LightIntensity = 1.0;
		{
			ivec4 ShadowCasters = ShadowCoverage[ObjectId].ShadowCasters;
			const vec3 WorldRayStart = Position;
#if ENABLE_SOFT_SHADOWS
			const vec3 LightDir = normalize(vec3(SUN_DIR));
			const float Scattering = 1.0;
			const int RayCount = 4;
			const vec3 RayOffsets[4] = \
			{
				vec3(Noise(Position.xy + vec2( 0.0, -1.0)), 0.0),
				vec3(Noise(Position.xy + vec2( 0.0,  1.0)), 0.0),
				vec3(Noise(Position.xy + vec2( 1.0,  0.0)), 0.0),
				vec3(Noise(Position.xy + vec2(-1.0,  0.0)), 0.0)
			};
			vec3 WorldRayDirs[RayCount];
			for (int i=0; i<RayCount; ++i)
			{
				const float Scale = (float(i) / float(RayCount - 1)) * Scattering;
				const vec3 Offset = RayOffsets[i % 4];
				WorldRayDirs[i] = normalize(Offset * Scattering + LightDir);
			}
#else
			const vec3 WorldRayDir = normalize(vec3(SUN_DIR));
#endif // ENABLE_SOFT_SHADOWS

#if VISUALIZE_SHADOW_COVERAGE
			for (int i=0; i<4; ++i)
			{
				if (ShadowCasters[i] > 0)
				{
					++CoverageCount;
				}
			}
#endif // VISUALIZE_SHADOW_COVERAGE

			for (int i=0; i<4 && LightIntensity > 0.0; ++i)
			{
				int CasterId = ShadowCasters[i];
				if (CasterId == 0)
				{
					break;
				}
				ObjectInfo Caster = Objects[CasterId];
				const vec3 LocalRayStart = Transform3(Caster.WorldToLocal, WorldRayStart);
#if ENABLE_SOFT_SHADOWS
				float RayIntensity = 0.0;
				for (int r=0; r<RayCount; ++r)
				{
					const vec3 LocalRayDir = normalize(Transform3(Caster.WorldToLocal, WorldRayStart + WorldRayDirs[r]) - LocalRayStart);
					const RayData Ray = RayData(WorldRayDirs[r], WorldRayStart, LocalRayDir, LocalRayStart);
					RayIntensity += SoftRayMarch(Caster, Ray);
				}
				RayIntensity /= float(RayCount);
				LightIntensity = min(LightIntensity, RayIntensity);
#else
				const vec3 LocalRayDir = normalize(Transform3(Caster.WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);
				const RayData Ray = RayData(WorldRayDir, WorldRayStart, LocalRayDir, LocalRayStart);
				LightIntensity = min(LightIntensity, SoftRayMarch(Caster, Ray));
#endif // ENABLE_SOFT_SHADOWS
			}
		}
#if ENABLE_SOFT_SHADOWS
		LightIntensity = min(LightIntensity * 4.0, 1.0);
#else
		LightIntensity = LightIntensity == 0.0 ? 0.0 : 1.0;
#endif // ENABLE_SOFT_SHADOWS
#else
		const float LightIntensity = 1.0;
#endif // ENABLE_SUN_SHADOWS

#if VISUALIZE_SHADOW_COVERAGE
		if (CoverageCount > 0)
		{
			float Heat = 1.0 - (float(CoverageCount) / 4.0);
			if (LightIntensity < 1.0)
			{
				OutColor = vec4(0.0, 1.0, Heat, 1.0);
			}
			else
			{
				OutColor = vec4(1.0, 0.0, Heat, 1.0);
			}
		}
		else
		{
			const vec3 PaintColor = Paint(Object, Position, false);
			const float Gray = (PaintColor.x + PaintColor.y + PaintColor.z) / 3.0;
			OutColor = vec4(vec3(Gray), 1.0);
		}
#else
		OutColor = vec4(Paint(Object, Position, LightIntensity), 1.0);
#if ENABLE_ANTIALIASING
		float Count = 1.0;
		const float Samples = 8.0;
		const float InvSamples = 1.0 / Samples;
		if (dFdx(gl_FragCoord.x) == 1.0)
		{
			const vec3 Offset = dFdx(Position);
			for (float i = 0.0; i < Samples; ++i)
			{
				const float Scale = i * InvSamples * 0.75;
				OutColor.xyz += Paint(Object, Offset * Scale + Position, LightIntensity);
				OutColor.xyz += Paint(Object, -Offset * Scale + Position, LightIntensity);
			}
			Count += Samples * 2.0;
		}
		if (dFdy(gl_FragCoord.y) == 1.0)
		{
			const vec3 Offset = dFdy(Position);
			for (float i = 0.0; i < Samples; ++i)
			{
				const float Scale = i * InvSamples * 0.75;
				OutColor.xyz += Paint(Object, Offset * Scale + Position, LightIntensity);
				OutColor.xyz += Paint(Object, -Offset * Scale + Position, LightIntensity);
			}
			Count += Samples * 2.0;
		}
		OutColor.xyz /= Count;
#endif // ENABLE_ANTIALIASING
#endif // VISUALIZE_SHADOW_COVERAGE
#endif // VISUALIZE_ALIASING_GRADIENT
	}
}
