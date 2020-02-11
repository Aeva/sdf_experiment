prepend: shaders/defs.glsl
prepend: shaders/math.glsl
prepend: shaders/screen.glsl
prepend: shaders/objects.glsl
prepend: shaders/scene.glsl
prepend: shaders/paint.glsl
prepend: shaders/raymarch.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec3 OutNormal;
layout(location = 1) out vec4 OutColor;
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


void main()
{
	vec3 Position;
	int ObjectId;
	Reconstitute(Position, ObjectId);

	if (ObjectId == -1)
	{
		OutNormal = vec3(0.0, 0.0, 0.0);
		OutColor = vec4(0.0, 0.0, 0.0, 0.0);
	}
	else
	{
		const ObjectInfo Object = Objects[ObjectId];
		const int ShapeFn = int(Object.ShapeParams.w);
		OutColor.a = float(ShapeIsTransmissive(Object.ShapeParams));
		if (ShapeFn > CUBE_TRACEABLES)
		{
			const vec3 LocalPosition = Transform3(Object.WorldToLocal, Position);
			OutNormal = CubeWorldNormal(Object, LocalPosition);
			OutColor.rgb = PaintCube(Object, Position);
		}
		else
		{
			OutNormal = WorldNormal(Object, Position);
            OutColor.rgb = Paint(Object, Position);
		}
	}
}
