prepend: shaders/screen.glsl
prepend: shaders/sdf.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
layout(depth_any) out float gl_FragDepth;

layout(std140, binding = 5)
uniform ObjectInfoBlock
{
	mat4 LocalToWorld;
	mat4 WorldToLocal;
	int ShapeFn;
};


ColorSDF LerpTest(vec3 Point, float Alpha, int PaintFn)
{
    ColorSDF a = Sphere(Point, 1.0, PaintFn);
    ColorSDF b = Box(Point, vec3(1.0), PaintFn);
    b.Distance = mix(a.Distance, b.Distance, Alpha);
    return b;
}


ColorSDF SceneSDF(vec3 Point)
{
	if (ShapeFn == 0)
	{
		return LerpTest(Transform3(WorldToLocal, Point), 0.0, 0);
	}
	else if (ShapeFn == 1)
	{
		return LerpTest(Transform3(WorldToLocal, Point), 0.5, 1);
	}
	else if (ShapeFn == 2)
	{
		return LerpTest(Transform3(WorldToLocal, Point), 1.0, 2);
	}
}


vec3 Paint(vec3 Point, ColorSDF Shape)
{
    // UVW should be about -1.0 to 1.0 in range, but may go over.
    vec3 UVW = Shape.Local / Shape.Extent;
	/*if (Shape.Distance < -AlmostZero)
	{
		return vec3(1.0, 0.0, 0.0);
	}*/
	if (Shape.PaintFn == 0)
    {
        return vec3(1.0, 0.5, 0.0);
    }
    else if (Shape.PaintFn == 1)
    {
        return vec3(0.0, 1.0, 0.5);
    }
    else if (Shape.PaintFn == 2)
    {
        return vec3(0.5, 0.0, 1.0);
    }
    else if (Shape.PaintFn == -1)
    {
		discard;
    }
    else
    {
        return vec3(1.0, 0.0, 0.0);
    }   
}


void main()
{
    vec3 Position;
    ColorSDF Scene;
    RayTrace(Position, Scene);
	OutColor = vec4(Paint(Position, Scene), 1.0);
	gl_FragDepth = 1.0 / distance(Position, CameraOrigin.xyz);
}
