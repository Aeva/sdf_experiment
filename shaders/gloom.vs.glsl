prepend: shaders/objects.glsl
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


void main()
{
	ShadowCaster = ShadowCasters[gl_InstanceID];
	ShadowCasterId = int(ShadowCaster.DepthRange.w);
	gl_Position = vec4(-1.0 + float((gl_VertexID & 1) << 2), -1.0 + float((gl_VertexID & 2) << 1), 0, 1);
}
