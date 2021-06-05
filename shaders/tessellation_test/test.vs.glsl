--------------------------------------------------------------------------------

out gl_PerVertex
{
  vec4 gl_Position;
  float gl_PointSize;
  float gl_ClipDistance[];
};


void main()
{
	const vec4 Verts[3] = {
		vec4(-0.9, -0.75, 0.0, 1.0),
		vec4(0.0, 0.8, 0.0, 1.0),
		vec4(0.9, -0.75, 0.0, 1.0)
	};
	gl_Position = Verts[gl_VertexID];
	//gl_Position = vec4(-1.0 + float((gl_VertexID & 1) << 2), -1.0 + float((gl_VertexID & 2) << 1), 0, 1);
}

