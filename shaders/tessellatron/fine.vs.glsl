prepend: shaders/standard_boilerplate.glsl
prepend: shaders/tessellation_test/sdf.glsl
--------------------------------------------------------------------------------


layout(std430, binding = 2) Readonly buffer TriangleStream
{
	vec4 StreamIn[];
};


out VS_OUT
{
	vec3 Normal;
	int CutShape;
};


void main()
{
	vec4 Data = StreamIn[gl_VertexID];
	gl_Position = vec4(Data.xyz, 1.0);
	Normal = GradientFinal(Data.xyz);
	CutShape = floatBitsToInt(Data.w);
	if (CutShape > -1)
	{
		Normal *= -1.0;
	}
}
