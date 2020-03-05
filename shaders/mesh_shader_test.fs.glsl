--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;


in flat vec2 Fnord;

void main()
{
    OutColor = vec4(Fnord.x, 0.0, Fnord.y, 1.0);
}
