prepend: shaders/defs.glsl
prepend: shaders/screen.glsl
prepend: shaders/objects.glsl
prepend: shaders/math.glsl
prepend: shaders/scene.glsl
prepend: shaders/raymarch.glsl
--------------------------------------------------------------------------------

#ifdef VERTEX_SHADER
out gl_PerVertex
{
  vec4 gl_Position;
  float gl_PointSize;
  float gl_ClipDistance[];
};

out flat ObjectInfo ShadowCaster;
out flat int ShadowCasterId;
#endif // VERTEX_SHADER


#ifdef MESH_SHADER
#define THREADS 32
#define VERTS 4
#define PRIMS 2
#define INDICES PRIMS * 3
#define MAX_VERTS THREADS * VERTS
#define MAX_PRIMS THREADS * PRIMS
layout(local_size_x=THREADS) in;
layout(max_vertices=MAX_VERTS, max_primitives=MAX_PRIMS) out;
layout(triangles) out;
out uint gl_PrimitiveCountNV;
out uint gl_PrimitiveIndicesNV[];
shared uint PrimitiveCount;

out gl_MeshPerVertexNV
{
    vec4 gl_Position;
} gl_MeshVerticesNV[];

perprimitiveNV out InterpolantsBlock
{
    //ObjectInfo ShadowCaster;
    int ShadowCasterId;
} Interpolants[];

// If we don't redeclare gl_PerVertex, compilation fails with the following error:
// error C7592: ARB_separate_shader_objects requires built-in block gl_PerVertex to be redeclared before accessing its members
out gl_PerVertex
{
    vec4 gl_Position;
} gl_Why;

#endif // MESH_SHADER


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


RayData GetOcclusionRay(vec3 WorldRayStart, const vec3 WorldRayDir, const ObjectInfo ShadowCaster)
{
	WorldRayStart += WorldRayDir * AlmostZero * 2.0;
	const vec3 LocalRayStart = Transform3(ShadowCaster.WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(ShadowCaster.WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);
	return RayData(WorldRayDir, WorldRayStart, LocalRayDir, LocalRayStart);
}


vec4 GloomTile(const int BoardWidth, const int BoardHeight, const ivec2 Tile, vec2 DepthMinMax, const ObjectInfo ShadowCaster)
{
    if (DepthMinMax.y > 0)
    {
        const vec2 TileSize = vec2(2.0) / vec2(BoardWidth, BoardHeight);
        const vec2 Low = vec2(Tile) * TileSize - 1.0;
        const vec2 Center = TileSize * 0.5 + Low;
        DepthMinMax = 1.0 / DepthMinMax;
        const float Depth = (DepthMinMax.x + DepthMinMax.y) * 0.5;
        const float Diameter = distance(DepthMinMax.x, DepthMinMax.y);
        const vec3 Origin = GetRayDir(Center) * Depth + CameraOrigin.xyz;
        const vec3 RayDir = normalize(vec3(SUN_DIR));
	    const RayData Ray = GetOcclusionRay(Origin, RayDir, ShadowCaster);
        const vec3 Extent = Diameter * 0.5 + ShadowCaster.ShapeParams.xyz;
        if (CubeTrace(Extent, Ray) >= 0.0)
        {
            const vec2 High = Low + TileSize;
            return vec4(Low, High);
        }
    }
    return vec4(0.0 / 0.0);
}
#endif // ENABLE_TILED_GLOOM


#ifdef VERTEX_SHADER
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
    vec4 Corners = GloomTile(BoardWidth, BoardHeight, ivec2(TileX, TileY), DepthMinMax, ShadowCaster);
    int VertexId = gl_VertexID % 6;
    vec2 Alpha = vec2(float(((VertexId % 3) & 1) << 2), float(((VertexId % 3) & 2) << 1)) * 0.25;
	if (VertexId > 2)
	{
	    Alpha = 1.0 - Alpha;
    }
    gl_Position = vec4(mix(Corners.xy, Corners.zw, Alpha), 0.0, 1.0);
#else
    gl_Position = vec4(-1.0 + float((gl_VertexID & 1) << 2), -1.0 + float((gl_VertexID & 2) << 1), 0, 1);
#endif // ENABLE_TILED_GLOOM
}
#endif // VERTEX_SHADER


#ifdef MESH_SHADER
void main()
{
    if (gl_LocalInvocationIndex == 0)
    {
        gl_PrimitiveCountNV = 64;
    }
    const int BoardWidth = DIV_UP(int(ScreenSize.x), 8);
    const int BoardHeight = DIV_UP(int(ScreenSize.y), 8);
    const int Tiles = BoardWidth * BoardHeight;
    const int ShadowCasterId = int(gl_GlobalInvocationID.x) / Tiles;
    const int ShadowTile = int(gl_GlobalInvocationID.x) % Tiles;
    const ivec2 Tile = ivec2(ShadowTile % BoardWidth, ShadowTile / BoardWidth);
    const ObjectInfo ShadowCaster = ShadowCasters[ShadowCasterId];
    const int ShadowCasterObjectId = int(ShadowCaster.DepthRange.w);
    vec2 DepthMinMax = texelFetch(DepthRange, Tile, 0).xy;
    vec4 Corners = vec4(0.0 / 0.0);//GloomTile(BoardWidth, BoardHeight, Tile, DepthMinMax, ShadowCaster);
    const uint QuadId = ShadowTile * 2;
    const uint VertexOffset = QuadId * 4;
    const uint IndexOffset = QuadId * 6;
    gl_MeshVerticesNV[VertexOffset + 0].gl_Position = vec4(Corners.x, Corners.y, 0.0, 1.0); // Upper Left
    gl_MeshVerticesNV[VertexOffset + 1].gl_Position = vec4(Corners.z, Corners.y, 0.0, 1.0); // Upper Right
    gl_MeshVerticesNV[VertexOffset + 2].gl_Position = vec4(Corners.x, Corners.w, 0.0, 1.0); // Bottom Left
    gl_MeshVerticesNV[VertexOffset + 3].gl_Position = vec4(Corners.z, Corners.w, 0.0, 1.0);
    gl_PrimitiveIndicesNV[IndexOffset + 0] = VertexOffset + 0;
    gl_PrimitiveIndicesNV[IndexOffset + 1] = VertexOffset + 1;
    gl_PrimitiveIndicesNV[IndexOffset + 2] = VertexOffset + 2;
    gl_PrimitiveIndicesNV[IndexOffset + 3] = VertexOffset + 2;
    gl_PrimitiveIndicesNV[IndexOffset + 4] = VertexOffset + 1;
    gl_PrimitiveIndicesNV[IndexOffset + 5] = VertexOffset + 3;
    //Interpolants[QuadId + 0].ShadowCaster = ShadowCaster;
    Interpolants[QuadId + 0].ShadowCasterId = ShadowCasterObjectId;
    //Interpolants[QuadId + 1].ShadowCaster = ShadowCaster;
    Interpolants[QuadId + 1].ShadowCasterId = ShadowCasterObjectId;
}
#endif // MESH_SHADER
