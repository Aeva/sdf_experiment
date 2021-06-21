prepend: shaders/standard_boilerplate.glsl
prepend: shaders/screen.glsl
prepend: shaders/view.glsl
prepend: shaders/tessellatron/sdf.glsl
--------------------------------------------------------------------------------

in TCS_IN
{
	vec3 Normal;
	int ShapeID;
} tcs_in[];


out TCS_OUT
{
	vec3 Normal;
	int ShapeID;
	vec3 Scratch;
} tcs_out[];


layout (vertices = 3) out;


void main()
{
	gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
	tcs_out[gl_InvocationID].Normal = tcs_in[gl_InvocationID].Normal;
	tcs_out[gl_InvocationID].ShapeID = tcs_in[gl_InvocationID].ShapeID;
	bool CutShape = IsCutShape(tcs_in[0].ShapeID);
	if (CutShape)
	{
		tcs_out[gl_InvocationID].Scratch.x = SceneFn(gl_in[gl_InvocationID].gl_Position.xyz, tcs_in[0].ShapeID);
	}
	else
	{
		tcs_out[gl_InvocationID].Scratch.x = Sphere(gl_in[gl_InvocationID].gl_Position.xyz, tcs_in[0].ShapeID);
	}
	vec3 EyeRay = normalize(CameraOrigin.xyz - gl_in[gl_InvocationID].gl_Position.xyz);
	tcs_out[gl_InvocationID].Scratch.y = dot(EyeRay, tcs_in[gl_InvocationID].Normal);
	barrier();

	float Threshold = distance(
		gl_in[(gl_InvocationID + 1) % 3].gl_Position.xyz,
		gl_in[(gl_InvocationID + 2) % 3].gl_Position.xyz) / 4.0;
	bool A = tcs_out[(gl_InvocationID + 1) % 3].Scratch.x < Threshold;
	bool B = tcs_out[(gl_InvocationID + 2) % 3].Scratch.x < Threshold;

	float Rate = (A || B) ? 7.0 : 1.0;

	{
		float Angle = min(
			tcs_out[(gl_InvocationID + 1) % 3].Scratch.y,
			tcs_out[(gl_InvocationID + 2) % 3].Scratch.y);
		float Alpha = clamp(Angle, 0.0, 0.25) * 4.0;
		Rate = mix(4.0, Rate, Alpha);
	}

	gl_TessLevelOuter[gl_InvocationID] = Rate;

	if (gl_InvocationID == 0)
	{
		gl_TessLevelInner[0] = max(max(gl_TessLevelOuter[0], gl_TessLevelOuter[1]), gl_TessLevelOuter[2]);
	}
}
