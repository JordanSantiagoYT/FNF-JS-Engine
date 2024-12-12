package editors;

import flixel.FlxG;
import flixel.FlxState;
import model.objects.flixel.Flixel;
import flixel.text.FlxText;
import flixel.util.FlxDestroyUtil;

class BenchmarkState extends FlxState
{
	var daFlixelLogo:Flixel;

	//this is so its actually possible to leave the state
	private var controls(get, never):Controls;
	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	override public function create()
	{
		super.create();

		// TODO: add debug info and such
		final text:FlxText = new FlxText();
		text.text = 'Press ESCAPE to leave.';
		text.screenCenter(X);
		text.y = FlxG.height * 0.89;
		text.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		add(text);

		daFlixelLogo = new Flixel();
		add(daFlixelLogo);
	}

	override function destroy()
	{
		if (daFlixelLogo != null) {
			@:privateAccess {
				for (mesh in daFlixelLogo.meshs) {
					if (mesh != null) {
						// Dispose material first, as it may rely on geometry
						if (mesh.material != null) {
							mesh.material.dispose();
							mesh.material = null;
						}
						
						// Dispose geometry next
						if (mesh.geometry != null) {
							mesh.geometry.dispose();
							mesh.geometry = null;
						}

						// Finally, dispose of the mesh itself
						mesh.dispose();
						mesh = null;
					}
				}

				// Dispose the 3D view (if it exists)
				if (daFlixelLogo.view != null) {
					daFlixelLogo.view.dispose();
					daFlixelLogo.view = null;
				}
			}

			// Destroy the Flixel object
			daFlixelLogo = FlxDestroyUtil.destroy(daFlixelLogo);
		}

		super.destroy();
	}
	override function update(elapsed:Float)
	{
		if(controls.BACK)
		{
			FlxG.switchState(new MasterEditorMenu());
			FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
		}
		super.update(elapsed);
	}
}
