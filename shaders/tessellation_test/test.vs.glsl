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
	vec3 Normal;
};


void main()
{
	vec4 Sphere = SphereParams[gl_InstanceID];
	int Face = gl_VertexID / 3;
	int Vert = gl_VertexID % 3;
	Normal = Normals[NormalIndexes[Face][Vert]];
	vec3 Vertex = Vertices[VertexIndexes[Face][Vert]];
	gl_Position = vec4(Vertex * Sphere.w + Sphere.xyz, 1.0);
	Coarse(gl_Position.xyz, Normal);
}
