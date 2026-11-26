package android;

import android.flixel.FlxVirtualPad;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.group.FlxGroup;

/**
 * Puts a virtual pad (from the Kade Engine Android port) on a menu.
 * The pad gets its own camera, created after the menu's own cameras so it is always on top.
 * Its buttons press real keys through `TouchKeys` (arrows, A = ENTER, B = ESCAPE).
 */
class MobilePad
{
	public static function create(parent:FlxGroup, dpad:FlxDPadMode, action:FlxActionMode):FlxVirtualPad
	{
		TouchKeys.init();

		var cam:FlxCamera = new FlxCamera();
		cam.bgColor.alpha = 0;
		FlxG.cameras.add(cam, false); // false: other sprites keep drawing on the menu cameras

		var pad:FlxVirtualPad = new FlxVirtualPad(dpad, action);
		pad.padCamera = cam;
		pad.cameras = [cam];
		parent.add(pad);
		return pad;
	}
}
