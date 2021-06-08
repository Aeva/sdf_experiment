prepend: shaders/tessellation_test/sdf.glsl
prepend: shaders/view.glsl
--------------------------------------------------------------------------------

in gl_PerVertex
{
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[];
} gl_in[gl_MaxPatchVertices];


in TCS_Out
{
	vec3 Normal;
} tes_in[];


out gl_PerVertex {
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[];
};


out TES_OUT
{
	vec3 Normal;
};


layout (triangles, equal_spacing, ccw) in;


void main()
{
	vec4 Position = (
		gl_TessCoord.x * gl_in[0].gl_Position +
		gl_TessCoord.y * gl_in[1].gl_Position +
		gl_TessCoord.z * gl_in[2].gl_Position);

	Normal = normalize(
		gl_TessCoord.x * tes_in[0].Normal +
		gl_TessCoord.y * tes_in[1].Normal +
		gl_TessCoord.z * tes_in[2].Normal);

	Fine(Position.xyz, Normal);
	gl_Position = ViewToClip * WorldToView * Position;
}
