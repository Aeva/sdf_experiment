prepend: shaders/standard_boilerplate.glsl
prepend: shaders/tessellation_test/sdf.glsl
prepend: shaders/view.glsl
--------------------------------------------------------------------------------

in TES_IN
{
	vec3 Normal;
	int CutShape;
	vec3 Scratch;
} tes_in[];


out TES_OUT
{
	vec4 Position;
	vec3 Barycenter;
	int CutShape;
};


layout (triangles, equal_spacing, ccw) in;


void main()
{
	Barycenter = gl_TessCoord;
	Position = (
		gl_TessCoord.x * gl_in[0].gl_Position +
		gl_TessCoord.y * gl_in[1].gl_Position +
		gl_TessCoord.z * gl_in[2].gl_Position);

	vec3 Normal = normalize(
		gl_TessCoord.x * tes_in[0].Normal +
		gl_TessCoord.y * tes_in[1].Normal +
		gl_TessCoord.z * tes_in[2].Normal);

	CutShape = tes_in[0].CutShape;

	if (CutShape > -1)
	{
		FineCut(Position.xyz, Normal, CutShape);
	}
	else
	{
		Fine(Position.xyz, Normal);
	}
	gl_Position = ViewToClip * WorldToView * vec4(Position.xyz, 1.0);
}
