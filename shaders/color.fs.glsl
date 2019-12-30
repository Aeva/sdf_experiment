prepend: shaders/defs.glsl
prepend: shaders/math.glsl
prepend: shaders/screen.glsl
prepend: shaders/objects.glsl
prepend: shaders/scene.glsl
prepend: shaders/paint.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
layout(std430, binding = 0) readonly buffer ObjectsBlock
{
	ObjectInfo Objects[];
};
layout(binding = 1) uniform sampler2D DepthBuffer;
layout(binding = 2) uniform isampler2D ObjectIdBuffer;


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
		OutColor = vec4(Paint(Object, Position), 1.0);
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
				OutColor.xyz += Paint(Object, Offset * Scale + Position);
				OutColor.xyz += Paint(Object, -Offset * Scale + Position);
			}
			Count += Samples * 2.0;
		}
		if (dFdy(gl_FragCoord.y) == 1.0)
		{
			const vec3 Offset = dFdy(Position);
			for (float i = 0.0; i < Samples; ++i)
			{
				const float Scale = i * InvSamples * 0.75;
				OutColor.xyz += Paint(Object, Offset * Scale + Position);
				OutColor.xyz += Paint(Object, -Offset * Scale + Position);
			}
			Count += Samples * 2.0;
		}
		OutColor.xyz /= Count;
#endif // ENABLE_ANTIALIASING
#endif // VISUALIZE_ALIASING_GRADIENT
	}
}
