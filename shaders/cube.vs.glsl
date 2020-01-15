prepend: shaders/view.glsl
--------------------------------------------------------------------------------

out gl_PerVertex
{
  vec4 gl_Position;
  float gl_PointSize;
  float gl_ClipDistance[];
};


const vec4 WorldCorners[4] = \
{
    vec4( 4.0,  4.0, 0.0, 1.0),
    vec4(-4.0,  4.0, 0.0, 1.0),
    vec4(-4.0, -4.0, 0.0, 1.0),
    vec4( 4.0, -4.0, 0.0, 1.0)
};

const int Indices[6] = { 0, 1, 2, 0, 2, 3 };


void main()
{
    const int Vertex = Indices[gl_VertexID % 6];
    const vec4 WorldSpace = WorldCorners[Vertex];
    gl_Position = ViewToClip * WorldToView * WorldSpace;
}
