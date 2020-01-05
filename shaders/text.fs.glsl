prepend: shaders/screen.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
layout(binding = 0) uniform sampler2D Atlas;
layout(binding = 3) uniform isampler2D Slug;


layout(std140, binding = 2)
uniform TextInfoBlock
{
    float Line;
    float Width;
};


in vec2 UV;

const vec2 AtlasSize = vec2(95.0 * 9.0, 20.0);


const int CharCodeMin = 32; // ' '
const int CharCodeMax = 126; // '~'
const int QuestionMark = 63; // '?'


void main ()
{
    const float Cursor = floor(UV.x * Width);
    const float AtlasWidth = (95.0 * 9.0);
    const float InvAtlasWidth = 1.0 / AtlasWidth;
    const vec2 GlyphUV = vec2(mod(UV.x * Width * 9.0, 9.0)/9.0, UV.y);
    int CharCode = texelFetch(Slug, ivec2(Cursor, 0), 0).r;
    if (CharCode < CharCodeMin || CharCode > CharCodeMax)
    {
        CharCode = QuestionMark;
    }
    const float GlyphOffset = (float(CharCode - CharCodeMin) + GlyphUV.x) * 9.0 * InvAtlasWidth;
    const vec2 AtlasUV = vec2(GlyphOffset, GlyphUV.y);
    OutColor = texture(Atlas, AtlasUV);
}
