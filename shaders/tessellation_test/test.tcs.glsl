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
	vec2 Scratch;
} tcs_out[];


layout (vertices = 3) out;


void main()
{
	gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
	tcs_out[gl_InvocationID].Normal = tcs_in[gl_InvocationID].Normal;
	tcs_out[gl_InvocationID].CutShape = tcs_in[gl_InvocationID].CutShape;

	vec4 NDC = ViewToClip * WorldToView * gl_in[gl_InvocationID].gl_Position;
	tcs_out[gl_InvocationID].Scratch = ((NDC.xy / NDC.w) * 0.5) * ScreenSize.xy;
	barrier();

	vec2 ScreenA = tcs_out[(gl_InvocationID + 2) % 3].Scratch;
	vec2 ScreenB = tcs_out[(gl_InvocationID + 1) % 3].Scratch;
	float Edge = distance(ScreenA, ScreenB);
	gl_TessLevelOuter[gl_InvocationID] = ceil(max(Edge, 1.0));
	barrier();

	if (gl_InvocationID == 0)
	{
		gl_TessLevelInner[0] = max(max(gl_TessLevelOuter[0], gl_TessLevelOuter[1]), gl_TessLevelOuter[2]);
	}
}
