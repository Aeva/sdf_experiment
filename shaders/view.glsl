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
