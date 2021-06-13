--------------------------------------------------------------------------------

layout(std430, binding = 0) restrict buffer TriangleMeta
{
	uint StreamStop;
	uint StreamNext;
};

layout(std430, binding = 1) writeonly buffer TriangleStream
{
	vec4 StreamOut[];
};
