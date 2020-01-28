prepend: shaders/shapes.glsl
--------------------------------------------------------------------------------


vec3 PaintTangerine(const ColorSDF Shape, const vec3 Flesh, const vec3 Fnord, const vec3 Rind)
{
	if (Shape.InnerDistance > -0.1)
	{
		return Rind;
	}
	else if (Shape.InnerDistance > -0.13)
	{
		return Fnord;
	}
	else
	{
		vec3 Test = vec3(abs(Shape.Local.x), -abs(Shape.Local.y), Shape.Local.z);
		ColorSDF Shape = Wedge(Test, 30.0);
		Shape = Union(Shape, Wedge(RotateZ(Test, RADIANS(30)), 30.0));
		Shape = Union(Shape, Wedge(RotateZ(Test, RADIANS(60)), 30.0));
		Shape = Union(Shape, Wedge(RotateZ(Test, RADIANS(90)), 30.0));
		if (IS_SOLID(Shape.Distance))
		{
			return Flesh;
		}
		return Fnord;
	}
}


vec3 PaintAxis(const ColorSDF Shape)
{
	float Inner = max(min(-Shape.InnerDistance, 1.0), 0.0);
	Inner = sin(Inner * 35.0) * 0.5 + 0.5;
	Inner = round(Inner);
	if (Shape.PaintFn == PAINT_X_AXIS)
	{
		return vec3(1.0, Inner, Inner);
	}
	else if (Shape.PaintFn == PAINT_Y_AXIS)
	{
		return vec3(Inner, 1.0, Inner);
	}
	else if (Shape.PaintFn == PAINT_Z_AXIS)
	{
		return vec3(Inner, Inner, 1.0);
	}
}


vec3 Illuminate(const vec3 BaseColor, const vec3 WorldPosition, const vec3 WorldNormal, const TRANSMISSION_TYPE Transmission, bool bIsTransmissive)
{
	const vec3 ShadowColor = BaseColor * 0.5;

#if VISUALIZE_NORMAL_LENGTH
	const float Magnitude = length(WorldNormal);
	if (Magnitude >= 1.0 - AlmostZero && Magnitude <= 1.0 + AlmostZero)
	{
		return vec3(1.0);
	}
	else if (Magnitude != Magnitude)
	{
		return vec3(1.0, 0.0, 0.0);
	}
	else if (isinf(Magnitude))
	{
		return vec3(0.0, 0.0, 1.0);
	}
	else
	{
		return vec3(0.0, 1.0, 0.0);
	}
#endif // VISUALIZE_NORMAL_LENGTH

	// Sun Light
	const vec3 LightRay = normalize(SUN_DIR);
	const float CosAngleToLight = dot(LightRay, WorldNormal);
	vec3 LightAlpha = vec3(0.0, 0.0, 0.0);

#if ENABLE_LIGHT_TRANSMISSION
	if (CosAngleToLight <= 0 && bIsTransmissive)
	{
		LightAlpha = Transmission * abs(CosAngleToLight);
	}
	else
#endif // ENABLE_LIGHT_TRANSMISSION
	{
		LightAlpha = vec3(Transmission * max(CosAngleToLight, 0.0));
	}

#if VISUALIZE_TRANSMISSION
	return LightAlpha;
#else
	return mix(ShadowColor, BaseColor, LightAlpha);
#endif // VISUALIZE_TRANSMISSION
}


vec3 PaintCube(ObjectInfo Object, vec3 WorldPosition, const TRANSMISSION_TYPE Transmission)
{
	int ShapeFn = int(Object.ShapeParams.w);
	const bool bIsTransmissive = ShapeIsTransmissive(Object.ShapeParams);
	const vec3 LocalPosition = Transform3(Object.WorldToLocal, WorldPosition);
	const vec3 WorldNormal = CubeWorldNormal(Object, LocalPosition);
#if VISUALIZE_NORMAL
	return WorldNormal * 0.5 + 0.5;
#else
	vec3 Color = vec3(0.0);

	if (ShapeFn == SHAPE_GRASS_CUBE_1)
	{
		Color = vec3(0.0, 0.75, 0.0);
	}
	else if (ShapeFn == SHAPE_GRASS_CUBE_2)
	{
		Color = vec3(0.0, 0.5, 0.0);
	}
	else if (ShapeFn == SHAPE_WATER_CUBE_1)
	{
		Color = vec3(0.0, 0.0, abs(WorldPosition.z) / 2.0);
	}
	else if (ShapeFn == SHAPE_WATER_CUBE_2)
	{
		Color = vec3(0.0, 0.0, abs(WorldPosition.z) / 2.0) + 0.2;
	}
	else if (ShapeFn == SHAPE_WHITE_SLAB)
	{
		Color = vec3(1.0);
	}
	else if (ShapeFn == SHAPE_CYAN_SLAB)
	{
		Color = vec3(0.0, 1.0, 1.0);
	}
	else if (ShapeFn == SHAPE_YELLOW_SLAB)
	{
		Color = vec3(1.0, 1.0, 0.0);
	}
	else if (ShapeFn == SHAPE_MAGENTA_SLAB)
	{
		Color = vec3(1.0, 0.0, 1.0);
	}
	else
	{
		return vec3(1.0, 0.0, 0.0);
	}
	return Illuminate(Color, WorldPosition, WorldNormal, Transmission, bIsTransmissive);
#endif // VISUALIZE_NORMAL
}


vec3 Paint(ObjectInfo Object, vec3 Point, const TRANSMISSION_TYPE Transmission)
{
	int ShapeFn = int(Object.ShapeParams.w);

	if (ShapeFn > CUBE_TRACEABLES)
	{
		return PaintCube(Object, Point, Transmission);
	}
	const bool bIsTransmissive = ShapeIsTransmissive(Object.ShapeParams);
	
	ColorSDF Shape = SceneColor(Object.ShapeParams, Transform3(Object.WorldToLocal, Point));

    // UVW should be about -1.0 to 1.0 in range, but may go over.
    const vec3 UVW = Shape.Local / Shape.Extent;

	const vec3 WorldNormal = WorldNormal(Object, Point);
#if VISUALIZE_NORMAL
	return WorldNormal * 0.5 + 0.5;
#else

	vec3 Color = vec3(0.0);

	if (Shape.PaintFn >= PAINT_X_AXIS && Shape.PaintFn <= PAINT_Z_AXIS)
	{
		Color = PaintAxis(Shape);
	}
	else if (Shape.PaintFn == PAINT_WHITE)
	{
		Color = vec3(1.0);
	}
	else if (Shape.PaintFn == PAINT_ONION1)
	{
		Color = vec3(0.0, 0.0, 1.0);
	}
	else if (Shape.PaintFn == PAINT_ONION2)
	{
		Color = vec3(0.088, 0.656, 0.939);
	}
	else if (Shape.PaintFn == PAINT_TANGERINE)
	{
		const vec3 Flesh = vec3(0.935, 0.453, 0.08);
		const vec3 Fnord = vec3(0.953, 0.891, 0.767);
		const vec3 Rind  = vec3(1.0, 0.767, 0.0);
		Color = PaintTangerine(Shape, Flesh, Fnord, Rind);
	}
	else if (Shape.PaintFn == PAINT_LIME)
	{
		const vec3 Flesh = vec3(0.651, 0.771, 0.137);
		const vec3 Fnord = vec3(0.89, 0.945, 0.71);
		const vec3 Rind  = vec3(0.552, 0.736, 0.193);
		Color = PaintTangerine(Shape, Flesh, Fnord, Rind);
	}
	else if (Shape.PaintFn == PAINT_TREE_TRUNK)
	{
		Color = vec3(0.627, 0.471, 0.094);
	}
	else if (Shape.PaintFn == PAINT_TREE_LEAVES)
	{
		Color = vec3(0.376, 0.784, 0.031);
	}
    else
    {
        return vec3(1.0, 0.0, 0.0);
    }

	return Illuminate(Color, Point, WorldNormal, Transmission, bIsTransmissive);
#endif // VISUALIZE_NORMAL
}
