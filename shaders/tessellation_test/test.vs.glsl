prepend: shaders/tessellation_test/icosphere.glsl
prepend: shaders/tessellation_test/sdf.glsl
--------------------------------------------------------------------------------

out gl_PerVertex
{
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[];
};


out VS_Out
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
