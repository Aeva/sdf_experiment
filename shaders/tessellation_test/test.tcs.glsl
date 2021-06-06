--------------------------------------------------------------------------------

in gl_PerVertex
{
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[];
} gl_in[gl_MaxPatchVertices];


in VS_Out
{
	vec3 Normal;
} tcs_in[];


out gl_PerVertex
{
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[];
} gl_out[];


out TCS_Out
{
	vec3 Normal;
} tcs_out[];


layout (vertices = 3) out;


void main()
{
	gl_TessLevelInner[gl_InvocationID] = 10.0;
	gl_TessLevelOuter[gl_InvocationID] = 10.0;
	gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
	tcs_out[gl_InvocationID].Normal = tcs_in[gl_InvocationID].Normal;
}
