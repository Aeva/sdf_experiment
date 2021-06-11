prepend: shaders/tessellation_test/sdf.glsl
prepend: shaders/view.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
in vec4 gl_FragCoord;


in TES_OUT
{
	vec3 Position;
	flat int CutShape;
};


void main ()
{
	if (SceneCutFn(Position) > 0.0001)
	{
		discard;
	}
	vec3 Normal = normalize(GradientFinal(Position));
	OutColor = vec4((Normal + 1.0) * 0.5, 1.0);
}
