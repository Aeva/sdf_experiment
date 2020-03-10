prepend: shaders/defs.glsl
prepend: shaders/screen.glsl
--------------------------------------------------------------------------------

layout(binding = 1) uniform sampler2D DepthBuffer;
layout(binding = 0, rg32f) uniform writeonly image2D DepthRange;

shared float Tile[64];

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main()
{
	ivec2 UV = min(ivec2(gl_GlobalInvocationID.xy), ivec2(ScreenSize.xy));
	Tile[gl_LocalInvocationIndex] = texelFetch(DepthBuffer, UV, 0).r;
	memoryBarrierShared();
	barrier();
	if (gl_LocalInvocationIndex == 0)
	{
	    vec2 MinMax = vec2(Tile[0], Tile[0]);
		for (int i=1; i<64; ++i)
		{
			MinMax.x = min(MinMax.x, Tile[i]);
			MinMax.y = max(MinMax.y, Tile[i]);
		}
		imageStore(DepthRange, ivec2(gl_GlobalInvocationID.xy / 8), MinMax.xyxy);
	}
}
