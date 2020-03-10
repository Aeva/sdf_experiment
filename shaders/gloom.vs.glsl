prepend: shaders/defs.glsl
prepend: shaders/screen.glsl
prepend: shaders/objects.glsl
prepend: shaders/math.glsl
prepend: shaders/scene.glsl
prepend: shaders/raymarch.glsl
--------------------------------------------------------------------------------

out gl_PerVertex
{
  vec4 gl_Position;
  float gl_PointSize;
  float gl_ClipDistance[];
};


out flat ObjectInfo ShadowCaster;
out flat int ShadowCasterId;


layout(std430, binding = 0) readonly buffer ShadowCastersBlock
{
	ObjectInfo ShadowCasters[];
};


#if ENABLE_TILED_GLOOM
layout(binding = 3) uniform sampler2D DepthRange;


vec3 GetRayDir(const vec2 NDC)
{
	vec4 View = ClipToView * vec4(NDC.xy, -1.0, 1.0);
	View = vec4(normalize(vec3(View.x, View.y, View.z) / View.w), 1.0);
	vec4 World = ViewToWorld * View;
	return normalize(vec3(World.xyz / World.w) - CameraOrigin.xyz);
}


RayData GetOcclusionRay(vec3 WorldRayStart, const vec3 WorldRayDir)
{
	WorldRayStart += WorldRayDir * AlmostZero * 2.0;
	const vec3 LocalRayStart = Transform3(ShadowCaster.WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(ShadowCaster.WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);
	return RayData(WorldRayDir, WorldRayStart, LocalRayDir, LocalRayStart);
}
#endif // ENABLE_TILED_GLOOM


void main()
{
	ShadowCaster = ShadowCasters[gl_InstanceID];
	ShadowCasterId = int(ShadowCaster.DepthRange.w);
#if ENABLE_TILED_GLOOM
    const int BoardWidth = DIV_UP(int(ScreenSize.x), 8);
    const int BoardHeight = DIV_UP(int(ScreenSize.y), 8);
    const int TileID = gl_VertexID / 6;
    const int TileX = TileID % BoardWidth;
    const int TileY = TileID / BoardWidth;
    vec2 DepthMinMax = texelFetch(DepthRange, ivec2(TileX, TileY), 0).xy;
    if (DepthMinMax.y == 0)
    {
        // Discard!
        gl_Position = vec4(0.0 / 0.0);
    }
    else
    {
        const vec2 TileSize = vec2(2.0) / vec2(BoardWidth, BoardHeight);
        const vec2 Low = vec2(TileX, TileY) * TileSize - 1.0;
        const vec2 Center = TileSize * 0.5 + Low;
        DepthMinMax = 1.0 / DepthMinMax;
        const float Depth = (DepthMinMax.x + DepthMinMax.y) * 0.5;
        const float Diameter = distance(DepthMinMax.x, DepthMinMax.y);
        const vec3 Origin = GetRayDir(Center) * Depth + CameraOrigin.xyz;
        const vec3 RayDir = normalize(vec3(SUN_DIR));
	    const RayData Ray = GetOcclusionRay(Origin, RayDir);
        const vec3 Extent = Diameter * 0.5 + ShadowCaster.ShapeParams.xyz;
        if (CubeTrace(Extent, Ray) >= 0.0)
        {
            int VertexId = gl_VertexID % 6;
            vec2 Alpha = vec2(float(((VertexId % 3) & 1) << 2), float(((VertexId % 3) & 2) << 1)) * 0.25;
	        if (VertexId > 2)
	        {
		        Alpha = 1.0 - Alpha;
            }
            const vec2 High = Low + TileSize;
	        gl_Position = vec4(mix(Low, High, Alpha), 0.0, 1.0);
        }
        else
        {
            // Discard!
            gl_Position = vec4(0.0 / 0.0);
        }
    }
#else
    gl_Position = vec4(-1.0 + float((gl_VertexID & 1) << 2), -1.0 + float((gl_VertexID & 2) << 1), 0, 1);
#endif // ENABLE_TILED_GLOOM
}
