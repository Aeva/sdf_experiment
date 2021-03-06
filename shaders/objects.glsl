--------------------------------------------------------------------------------

struct ObjectInfo
{
	vec4 ClipBounds; // (MinX, MinY, MaxX, MaxY)
	vec4 DepthRange; // (Min, Max, 0.0, 0.0)
	vec4 ShapeParams; // (AABB Extent, ShapeFn)
	mat4 LocalToWorld;
	mat4 WorldToLocal;
};
