prepend: shaders/standard_boilerplate.glsl
prepend: shaders/tessellatron/icosphere.glsl
prepend: shaders/tessellatron/sdf.glsl
--------------------------------------------------------------------------------

out VS_OUT
{
	vec3 Normal;
	int ShapeID;
};


void main()
{
	vec4 Sphere = SphereParams[gl_InstanceID];
	int Face = gl_VertexID / 3;
	int Vert = gl_VertexID % 3;
	ShapeID = gl_InstanceID;
	bool CutShape = IsCutShape(ShapeID);
	if (CutShape)
	{
		Vert = 2 - Vert;
	}
	Normal = Normals[NormalIndexes[Face][Vert]];
	vec3 Vertex = Vertices[VertexIndexes[Face][Vert]];
	if (CutShape)
	{
		Normal *= -1.0;
		Vertex *= 1.5;
	}
	gl_Position = vec4(Vertex * abs(Sphere.w) + Sphere.xyz, 1.0);

	Coarse(gl_Position.xyz, Normal, ShapeID);
}
