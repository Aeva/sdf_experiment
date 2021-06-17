prepend: shaders/standard_boilerplate.glsl
prepend: shaders/screen.glsl
prepend: shaders/view.glsl
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
	vec3 Scratch;
} tcs_out[];


layout (vertices = 3) out;


void main()
{
	gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
	tcs_out[gl_InvocationID].Normal = tcs_in[gl_InvocationID].Normal;
	tcs_out[gl_InvocationID].CutShape = tcs_in[gl_InvocationID].CutShape;

	vec3 EyeRay = normalize(CameraOrigin.xyz - gl_in[gl_InvocationID].gl_Position.xyz);
	tcs_out[gl_InvocationID].Scratch.x = dot(EyeRay, tcs_in[gl_InvocationID].Normal);
	barrier();

	if (gl_InvocationID == 0)
	{
		bool Cull = \
			tcs_out[0].Scratch.x <= 0.0 != tcs_in[0].CutShape > -1 && \
			tcs_out[1].Scratch.x <= 0.0 != tcs_in[0].CutShape > -1 && \
			tcs_out[2].Scratch.x <= 0.0 != tcs_in[0].CutShape > -1;
		float Rate = Cull ? 0.0 : 2.0;
		gl_TessLevelInner[0] = Rate;
		gl_TessLevelOuter[0] = Rate;
		gl_TessLevelOuter[1] = Rate;
		gl_TessLevelOuter[2] = Rate;
	}
}
