prepend: shaders/defs.glsl
prepend: shaders/math.glsl
prepend: shaders/scene.glsl
prepend: shaders/raymarch.glsl
--------------------------------------------------------------------------------

layout(location = 0) out float OutLightIntensity;
layout(binding = 1) uniform sampler2D DepthBuffer;
layout(binding = 2) uniform isampler2D ObjectIdBuffer;


in vec4 gl_FragCoord;
in flat ObjectInfo ShadowCaster;
in flat int ShadowCasterId;


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


void main ()
{
	vec3 Position;
	int ObjectId;
	Reconstitute(Position, ObjectId);

	if (ObjectId == -1 || ObjectId == ShadowCasterId)
	{
		OutLightIntensity = 1.0;
	}
	else
	{
		const vec3 WorldRayStart = Position;
		const vec3 WorldRayDir = normalize(vec3(SUN_DIR));
		const vec3 LocalRayStart = Transform3(ShadowCaster.WorldToLocal, WorldRayStart);
		const vec3 LocalRayDir = normalize(Transform3(ShadowCaster.WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);
		const RayData Ray = RayData(WorldRayDir, WorldRayStart, LocalRayDir, LocalRayStart);
		OutLightIntensity = SoftRayMarch(ShadowCaster, Ray) == 0.0 ? 0.0 : 1.0;
	}
}
