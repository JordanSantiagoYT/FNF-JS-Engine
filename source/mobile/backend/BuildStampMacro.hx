package mobile.backend;

import haxe.macro.Expr;

class BuildStampMacro
{
	public static macro function get():Expr
	{
		final stamp = Std.string(Std.int(Date.now().getTime() / 1000));
		return macro $v{stamp};
	}
}
