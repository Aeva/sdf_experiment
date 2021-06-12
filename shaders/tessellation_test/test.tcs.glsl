prepend: shaders/screen.glsl
prepend: shaders/view.glsl
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
	vec3 Scratch;
} tcs_out[];


layout (vertices = 3) out;


void main()
{
	gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
	tcs_out[gl_InvocationID].Normal = tcs_in[gl_InvocationID].Normal;
	tcs_out[gl_InvocationID].CutShape = tcs_in[gl_InvocationID].CutShape;

	bool Positive = tcs_in[0].CutShape < 0;
	gl_TessLevelOuter[gl_InvocationID] = Positive ? 20.0 : 56.0;
	if (gl_InvocationID == 0)
	{
		gl_TessLevelInner[0] = Positive ? 20.0 : 56.0;
	}
}
