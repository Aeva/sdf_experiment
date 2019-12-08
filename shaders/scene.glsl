--------------------------------------------------------------------------------

float SceneHull(vec3 Local)
{
	if (ShapeFn == SHAPE_ORIGIN)
	{
		return FancyBoxHull(Local, ShapeBounds);
	}
	else if (ShapeFn == SHAPE_X_AXIS)
	{
		return TangerineHull(Local);
	}
	else if (ShapeFn == SHAPE_Y_AXIS)
	{
		return LimeHull(Local);
	}
	else if (ShapeFn == SHAPE_Z_AXIS)
	{
		return OnionHull(Local);
	}
	else if (ShapeFn == SHAPE_TREE)
	{
		return TreeHull(Local);
	}
#if !ENABLE_CUBETRACE
	else if (ShapeFn > CUBE_TRACEABLES)
	{
		return sdBox(Local, ShapeBounds);
	}
#endif
}


ColorSDF SceneColor(vec3 Local)
{
	if (ShapeFn == SHAPE_ORIGIN)
	{
		return FancyBoxColor(Local, ShapeBounds);
	}
	else if (ShapeFn == SHAPE_X_AXIS)
	{
		return TangerineColor(Local);
	}
	else if (ShapeFn == SHAPE_Y_AXIS)
	{
		return LimeColor(Local);
	}
	else if (ShapeFn == SHAPE_Z_AXIS)
	{
		return OnionColor(Local);
	}
	else if (ShapeFn == SHAPE_TREE)
	{
		return TreeColor(Local);
	}
#if !ENABLE_CUBETRACE
	else if (ShapeFn > CUBE_TRACEABLES)
	{
		return Box(Local, ShapeBounds, PAINT_CUBE);
	}
#endif
}
