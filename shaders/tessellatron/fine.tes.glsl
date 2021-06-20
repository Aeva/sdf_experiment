prepend: shaders/standard_boilerplate.glsl
prepend: shaders/tessellatron/sdf.glsl
prepend: shaders/view.glsl
--------------------------------------------------------------------------------

in TES_IN
{
	vec3 Normal;
	int ShapeID;
	vec3 Scratch;
} tes_in[];


out TES_OUT
{
	vec4 Position;
	int ShapeID;
};


layout (triangles, equal_spacing, ccw) in;


void main()
{
	Position = (
		gl_TessCoord.x * gl_in[0].gl_Position +
		gl_TessCoord.y * gl_in[1].gl_Position +
		gl_TessCoord.z * gl_in[2].gl_Position);

	vec3 Normal = normalize(
		gl_TessCoord.x * tes_in[0].Normal +
		gl_TessCoord.y * tes_in[1].Normal +
		gl_TessCoord.z * tes_in[2].Normal);

	ShapeID = tes_in[0].ShapeID;

	for (int i = 0; i < 5; ++i)
	{
		vec3 Gradient = normalize(EdgeGradient(Position.xyz));
		float Dist = EdgeMagnet(Position.xyz);
		if (Dist < 0.1)
		{
			Position.xyz -= Gradient * Dist;
		}
	}

	Fine(Position.xyz, Normal, ShapeID);
}
