--------------------------------------------------------------------------------

struct ObjectInfo
{
	vec4 ClipBounds; // (MinX, MinY, MaxX, MaxY)
	vec4 DepthRange; // (Min, Max, 0.0, 0.0)
	vec4 ShapeParams; // (AABB Extent, ShapeFn)
	mat4 LocalToWorld;
	mat4 WorldToLocal;
};


#if ENABLE_SUN_SHADOWS
struct ShadowCoverageInfo
{
	ivec4 ShadowCasters;
};
#endif //ENABLE_SUN_SHADOWS
