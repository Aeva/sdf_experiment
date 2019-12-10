--------------------------------------------------------------------------------

layout(std140, binding = 2)
uniform ViewInfoBlock
{
	mat4 WorldToView;
	mat4 ViewToWorld;
	mat4 ViewToClip;
	mat4 ClipToView;
	vec4 CameraOrigin; // The w component packs the elapsed time in seconds.
};
#define Time CameraOrigin.w


in vec4 gl_FragCoord;
in flat mat4 LocalToWorld;
in flat mat4 WorldToLocal;
in flat vec2 DepthRange;
in flat vec3 ShapeBounds;
in flat int ShapeFn;
