--------------------------------------------------------------------------------

layout(std140, binding = 1)
uniform ScreenInfoBlock
{
	vec4 ScreenSize; // (Width, Height, InvWidth, InvHeight)
};

layout(std140, binding = 4)
uniform ClipInfoBlock
{
	vec4 ClipBounds; // (MinX, MinY, MaxX, MaxY)
	vec4 DepthRange; // (Min, Max, 0.0, 0.0)
};
