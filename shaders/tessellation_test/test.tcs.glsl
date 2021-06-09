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
	int CutShape;
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
	int CutShape;
} tcs_out[];


layout (vertices = 3) out;


void main()
{
	float Rate = 17.0;
	gl_TessLevelInner[gl_InvocationID] = Rate;
	gl_TessLevelOuter[gl_InvocationID] = Rate;
	tcs_out[gl_InvocationID].Normal = tcs_in[gl_InvocationID].Normal;
	tcs_out[gl_InvocationID].CutShape = tcs_in[gl_InvocationID].CutShape;
	gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
}
