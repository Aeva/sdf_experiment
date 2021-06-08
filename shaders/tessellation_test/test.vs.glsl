prepend: shaders/tessellation_test/icosphere.glsl
prepend: shaders/tessellation_test/sdf.glsl
prepend: shaders/view.glsl
--------------------------------------------------------------------------------

out gl_PerVertex
{
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[];
};


out VS_Out
{
	vec3 Position;
	vec3 Normal;
};


void main()
{
	int Face = gl_VertexID / 3;
	int Vert = gl_VertexID % 3;
	Normal = Normals[NormalIndexes[Face][Vert]];
	Position = Vertices[VertexIndexes[Face][Vert]];
	gl_Position = vec4(Position, 1.0);
	Coarse(gl_Position.xyz, Normal);
}

