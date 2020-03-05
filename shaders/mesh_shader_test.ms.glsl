--------------------------------------------------------------------------------

#define THREADS 32
#define VERTS 4
#define PRIMS 2
#define INDICES PRIMS * 3
#define MAX_VERTS THREADS * VERTS
#define MAX_PRIMS THREADS * PRIMS

layout(local_size_x=THREADS) in;
layout(max_vertices=MAX_VERTS, max_primitives=MAX_PRIMS) out;
layout(triangles) out;

out gl_MeshPerVertexNV {
    vec4 gl_Position;
} gl_MeshVerticesNV[]; // MAX_VERTS

out uint gl_PrimitiveCountNV;
out uint gl_PrimitiveIndicesNV[]; // MAX_PRIMS * 3

out Interpolant {
    vec2 Fnord;
} Fnords[]; // MAX_VERTS


// If we don't redeclare gl_PerVertex, compilation fails with the following error:
// error C7592: ARB_separate_shader_objects requires built-in block gl_PerVertex to be redeclared before accessing its members
out gl_PerVertex {
    vec4 gl_Position;
} gl_Why;


void main()
{
    const float TileX = float(gl_LocalInvocationIndex % 8);
    const float TileY = float(gl_LocalInvocationIndex / 8);
    const vec2 TileSize = 2.0 / vec2(8.0, 4.0);
    const float X1 = TileX * TileSize.x - 1.0;
    const float Y1 = TileY * TileSize.y - 1.0;
    const float X2 = X1 + TileSize.x;
    const float Y2 = Y1 + TileSize.y;
    const vec2 Fnord = vec2(TileX / 8.0, TileY / 4.0);
    const uint TriangleOffset = gl_LocalInvocationIndex * VERTS;
    const uint IndexOffset = gl_LocalInvocationIndex * INDICES;
    gl_MeshVerticesNV[TriangleOffset + 0].gl_Position = vec4(X1, Y1, 0.0, 1.0); // Upper Left
    gl_MeshVerticesNV[TriangleOffset + 1].gl_Position = vec4(X2, Y1, 0.0, 1.0); // Upper Right
    gl_MeshVerticesNV[TriangleOffset + 2].gl_Position = vec4(X1, Y2, 0.0, 1.0); // Bottom Left
    gl_MeshVerticesNV[TriangleOffset + 3].gl_Position = vec4(X2, Y2, 0.0, 1.0); // Bottom Right
    Fnords[TriangleOffset + 0].Fnord = Fnord;
    Fnords[TriangleOffset + 1].Fnord = Fnord;
    Fnords[TriangleOffset + 2].Fnord = Fnord;
    Fnords[TriangleOffset + 3].Fnord = Fnord;
    gl_PrimitiveIndicesNV[IndexOffset + 0] = TriangleOffset + 0;
    gl_PrimitiveIndicesNV[IndexOffset + 1] = TriangleOffset + 1;
    gl_PrimitiveIndicesNV[IndexOffset + 2] = TriangleOffset + 2;
    gl_PrimitiveIndicesNV[IndexOffset + 3] = TriangleOffset + 2;
    gl_PrimitiveIndicesNV[IndexOffset + 4] = TriangleOffset + 1;
    gl_PrimitiveIndicesNV[IndexOffset + 5] = TriangleOffset + 3;
    if (gl_LocalInvocationIndex == 0)
    {
      gl_PrimitiveCountNV = MAX_PRIMS;
    }
}
