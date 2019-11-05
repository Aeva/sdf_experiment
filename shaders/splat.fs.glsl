prepend: shaders/screen.glsl
prepend: shaders/sdf.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;


const vec4 BackgroundColor = vec4(0.1, 0.1, 0.1, 1.0);

const mat4 LocalToWorld1 = TRAN(4.0, 0.0, 0.0);
const mat4 WorldToLocal1 = inverse(LocalToWorld1);

const mat4 LocalToWorld2 = TRAN(4.0, 0.0, 0.0) * ROTZ(RADIANS(45.0));
const mat4 WorldToLocal2 = inverse(LocalToWorld2);

const mat4 LocalToWorld3 = TRAN(4.0, 0.0, 0.0) * ROTZ(RADIANS(90.0));
const mat4 WorldToLocal3 = inverse(LocalToWorld3);


ColorSDF LerpTest(vec3 Point, float Alpha, int PaintFn)
{
    ColorSDF a = Sphere(Point, 1.0, PaintFn);
    ColorSDF b = Box(Point, vec3(1.0), PaintFn);
    b.Distance = mix(a.Distance, b.Distance, Alpha);
    return b;
}


ColorSDF SceneSDF(vec3 Point, bool bInterior)
{
	ColorSDF a = LerpTest(Transform3(WorldToLocal1, Point), 0.0, 1);
	ColorSDF b = LerpTest(Transform3(WorldToLocal2, Point), 0.5, 2);
    ColorSDF c = LerpTest(Transform3(WorldToLocal3, Point), 1.0, 3);
	return Union(a, Union(b, c));
}


vec3 Paint(vec3 Point, ColorSDF Shape)
{
    // UVW should be about -1.0 to 1.0 in range, but may go over.
    vec3 UVW = Shape.Local / Shape.Extent;
    if (Shape.PaintFn == 1)
    {
        return vec3(1.0, 0.5, 0.0);
    }
    else if (Shape.PaintFn == 2)
    {
        return vec3(0.0, 1.0, 0.5);
    }
    else if (Shape.PaintFn == 3)
    {
        return vec3(0.5, 0.0, 1.0);
    }
    else if (Shape.PaintFn == -1)
    {
        // shhhhh
        return BackgroundColor.rgb;
    }
    else
    {
        return vec3(1.0, 0.0, 0.0);
    }   
}


void main()
{
    vec3 Position = CameraOrigin.xyz;
    int PaintFn = 0;
    ColorSDF Scene;
    RayTrace(Position, PaintFn, Scene);
	OutColor = (Scene.Distance < AlmostZero) ? vec4(Paint(Position, Scene), 1.0) : BackgroundColor;
}
