--------------------------------------------------------------------------------

layout(local_size_x=1) in;
layout(max_vertices=4, max_primitives=2) out;
layout(triangles) out;

out gl_MeshPerVertexNV {
    vec4 gl_Position;
} gl_MeshVerticesNV[];

out uint gl_PrimitiveCountNV;
out uint gl_PrimitiveIndicesNV[];

// If we don't redeclare gl_PerVertex, compilation fails with the following error:
// error C7592: ARB_separate_shader_objects requires built-in block gl_PerVertex to be redeclared before accessing its members
out gl_PerVertex {
    vec4 gl_Position;
} gl_Why;


void main()
{
    //gl_LocalInvocationID.x
    gl_MeshVerticesNV[0].gl_Position = vec4(-1.0, -1.0, 0.0, 1.0); // Upper Left
    gl_MeshVerticesNV[1].gl_Position = vec4( 1.0, -1.0, 0.0, 1.0); // Upper Right
    gl_MeshVerticesNV[2].gl_Position = vec4(-1.0,  1.0, 0.0, 1.0); // Bottom Left
    gl_MeshVerticesNV[3].gl_Position = vec4( 1.0,  1.0, 0.0, 1.0); // Bottom Right
    gl_PrimitiveIndicesNV[0] = 0;
    gl_PrimitiveIndicesNV[1] = 1;
    gl_PrimitiveIndicesNV[2] = 2;
    gl_PrimitiveIndicesNV[3] = 2;
    gl_PrimitiveIndicesNV[4] = 1;
    gl_PrimitiveIndicesNV[5] = 3;
    gl_PrimitiveCountNV += 2;
}
