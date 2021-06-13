prepend: shaders/standard_boilerplate.glsl
prepend: shaders/tessellatron/icosphere.glsl
prepend: shaders/tessellation_test/sdf.glsl
--------------------------------------------------------------------------------

out VS_OUT
{
	vec3 Normal;
	int CutShape;
};


void main()
{
	vec4 Sphere = SphereParams[gl_InstanceID];
	int Face = gl_VertexID / 3;
	int Vert = gl_VertexID % 3;
	CutShape = Sphere.w < 0.0 ? gl_InstanceID : -1;
	if (CutShape > -1)
	{
		Vert = 2 - Vert;
	}
	Normal = Normals[NormalIndexes[Face][Vert]];
	vec3 Vertex = Vertices[VertexIndexes[Face][Vert]];
	if (CutShape > -1)
	{
		Normal *= -1.0;
		Vertex *= 1.5;
	}
	gl_Position = vec4(Vertex * abs(Sphere.w) + Sphere.xyz, 1.0);
	if (CutShape > -1)
	{
		CoarseCut(gl_Position.xyz, Normal, CutShape);
	}
	else
	{
		Coarse(gl_Position.xyz, Normal);
	}
}
