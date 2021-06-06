--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
in vec4 gl_FragCoord;


in TES_OUT
{
	vec3 Normal;
};


void main ()
{
	OutColor = vec4((Normal + 1.0) * 0.5, 1.0);
}
