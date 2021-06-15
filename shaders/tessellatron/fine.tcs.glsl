prepend: shaders/standard_boilerplate.glsl
prepend: shaders/screen.glsl
prepend: shaders/view.glsl
prepend: shaders/tessellation_test/sdf.glsl
--------------------------------------------------------------------------------

in TCS_IN
{
	vec3 Normal;
	int CutShape;
} tcs_in[];


out TCS_OUT
{
	vec3 Normal;
	int CutShape;
	float Weight;
} tcs_out[];


layout (vertices = 3) out;


void main()
{
	gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
	tcs_out[gl_InvocationID].Normal = tcs_in[gl_InvocationID].Normal;
	tcs_out[gl_InvocationID].CutShape = tcs_in[gl_InvocationID].CutShape;
	tcs_out[gl_InvocationID].Weight = SceneCutFn(gl_in[gl_InvocationID].gl_Position.xyz) <= 0.0001 ? 1.0 : 0.0;

	gl_TessLevelOuter[gl_InvocationID] = 8.0;
	if (gl_InvocationID == 0)
	{
		gl_TessLevelInner[0] = 8.0;
	}
}
