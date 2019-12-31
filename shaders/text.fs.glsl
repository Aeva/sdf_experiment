prepend: shaders/screen.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
layout(binding = 0) uniform sampler2D Atlas;
layout(binding = 3) uniform sampler2D Slug;


layout(std140, binding = 2)
uniform TextInfoBlock
{
    float Line;
    float Width;
};


in vec2 UV;

const vec2 AtlasSize = vec2(95.0 * 9.0, 20.0);


const float CharCodeMin = 32.0; // ' '
const float CharCodeMax = 126.0; // '~'
const float QuestionMark = 63.0; // '?'


void main ()
{
    const float Cursor = floor(UV.x * Width);
    const float AtlasWidth = (95.0 * 9.0);
    const float InvAtlasWidth = 1.0 / AtlasWidth;
    const vec2 GlyphUV = vec2(mod(UV.x * Width * 9.0, 9.0)/9.0, UV.y);
    float CharCode = floor(texelFetch(Slug, ivec2(Cursor, 0), 0).r * 255.0);
    if (CharCode < CharCodeMin || CharCode > CharCodeMax)
    {
        CharCode = QuestionMark;
    }
    const float GlyphOffset = (CharCode - CharCodeMin + GlyphUV.x) * 9.0 * InvAtlasWidth;
    const vec2 AtlasUV = vec2(GlyphOffset, GlyphUV.y);
    OutColor = texture(Atlas, AtlasUV);
}
