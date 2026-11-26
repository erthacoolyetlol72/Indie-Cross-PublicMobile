package android;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;

/**
 * Turns finger touches on registered on-screen buttons into real keyboard presses.
 *
 * Indie Cross reads notes, dodging (SPACE), Bendy's left/right attacks (left/right SHIFT),
 * pausing (ESCAPE) and all its menus (arrow keys, ENTER, ESCAPE) straight from the keyboard,
 * so pressing the same keys from the touch screen makes every mechanic work unchanged.
 *
 * Touches that start on a button are hidden from the emulated mouse, so tapping a
 * virtual pad button never also "clicks" the menu behind it.
 */
class TouchKeys
{
	public static inline var KEY_LEFT:Int = 37;
	public static inline var KEY_UP:Int = 38;
	public static inline var KEY_RIGHT:Int = 39;
	public static inline var KEY_DOWN:Int = 40;
	public static inline var KEY_ENTER:Int = 13;
	public static inline var KEY_ESCAPE:Int = 27;
	public static inline var KEY_SPACE:Int = 32;
	public static inline var KEY_SHIFT:Int = 16;

	public static inline var LOCATION_STANDARD:Int = 0;
	public static inline var LOCATION_LEFT:Int = 1;
	public static inline var LOCATION_RIGHT:Int = 2;

	/** keyCode OpenFL gives the Android back button */
	static inline var ANDROID_BACK:Int = 0x01000016;

	static var zones:Array<TouchZone> = [];
	static var touchZones:Map<Int, TouchZone> = new Map();
	static var heldCount:Map<String, Int> = new Map();
	static var started:Bool = false;
	static var mouseBlocked:Bool = false;
	static var pendingUps:Array<Array<Int>> = [];

	/** Starts listening to the touch screen. Safe to call more than once. */
	public static function init():Void
	{
		if (started)
			return;
		started = true;

		var stage = FlxG.stage;
		// high priority so these run before Flixel's own mouse listeners
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin, false, 100);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove, false, 100);
		stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd, false, 100);
		stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 100);
		stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 100);
		stage.addEventListener(KeyboardEvent.KEY_UP, onBackKey, false, 100);

		FlxG.signals.preStateSwitch.add(releaseAll);
		FlxG.signals.preUpdate.add(sendPendingUps);
	}

	/** Makes `sprite` press `keyCode` while a finger is on it. */
	public static function register(sprite:FlxSprite, keyCode:Int, location:Int = 0):Void
	{
		init();
		unregister(sprite);
		zones.push(new TouchZone(sprite, keyCode, location));
	}

	public static function unregister(sprite:FlxSprite):Void
	{
		var i = zones.length;
		while (i-- > 0)
		{
			var zone = zones[i];
			if (zone.sprite != sprite)
				continue;

			var ids:Array<Int> = [for (id in touchZones.keys()) if (touchZones.get(id) == zone) id];
			for (id in ids)
			{
				touchZones.remove(id);
				release(zone);
			}
			zones.splice(i, 1);
		}
	}

	/** Lets go of every key held by a finger (used when the screen changes). */
	public static function releaseAll():Void
	{
		var held:Array<TouchZone> = [for (zone in touchZones) zone];
		touchZones = new Map();
		for (zone in held)
		{
			if (zone != null)
				release(zone);
		}
	}

	/** Presses a key for one frame, the same way a keyboard does. */
	public static function tapKey(keyCode:Int, location:Int = 0):Void
	{
		sendKey(KeyboardEvent.KEY_DOWN, keyCode, location);
		pendingUps.push([keyCode, location]);
	}

	static function sendPendingUps():Void
	{
		if (pendingUps.length == 0)
			return;

		var ups = pendingUps;
		pendingUps = [];
		for (up in ups)
			sendKey(KeyboardEvent.KEY_UP, up[0], up[1]);
	}

	static function onTouchBegin(e:TouchEvent):Void
	{
		var zone = zoneAt(e.stageX, e.stageY);
		var old = touchZones.get(e.touchPointID);
		if (old != null)
			release(old);

		touchZones.set(e.touchPointID, zone);
		if (zone != null)
			press(zone);
	}

	static function onTouchMove(e:TouchEvent):Void
	{
		if (!touchZones.exists(e.touchPointID))
			return;

		var old = touchZones.get(e.touchPointID);
		var zone = zoneAt(e.stageX, e.stageY);
		if (zone == old)
			return;

		// sliding a finger from one lane to the next
		if (old != null)
			release(old);
		touchZones.set(e.touchPointID, zone);
		if (zone != null)
			press(zone);
	}

	static function onTouchEnd(e:TouchEvent):Void
	{
		var zone = touchZones.get(e.touchPointID);
		touchZones.remove(e.touchPointID);
		if (zone != null)
			release(zone);
	}

	static function onMouseDown(e:MouseEvent):Void
	{
		if (zoneAt(e.stageX, e.stageY) != null)
		{
			mouseBlocked = true;
			e.stopImmediatePropagation();
		}
	}

	static function onMouseUp(e:MouseEvent):Void
	{
		if (mouseBlocked)
		{
			mouseBlocked = false;
			e.stopImmediatePropagation();
		}
	}

	static function onBackKey(e:KeyboardEvent):Void
	{
		// the phone's back button acts like ESCAPE: back in menus, pause in songs
		if (e.keyCode == ANDROID_BACK)
			tapKey(KEY_ESCAPE);
	}

	static function press(zone:TouchZone):Void
	{
		var id = zone.id();
		var count = heldCount.exists(id) ? heldCount.get(id) : 0;
		heldCount.set(id, count + 1);
		if (count == 0)
			sendKey(KeyboardEvent.KEY_DOWN, zone.keyCode, zone.location);
	}

	static function release(zone:TouchZone):Void
	{
		var id = zone.id();
		var count = heldCount.exists(id) ? heldCount.get(id) : 0;
		if (count <= 0)
			return;

		heldCount.set(id, count - 1);
		if (count == 1)
			sendKey(KeyboardEvent.KEY_UP, zone.keyCode, zone.location);
	}

	static function sendKey(type:String, keyCode:Int, location:Int):Void
	{
		if (FlxG.stage == null)
			return;

		FlxG.stage.dispatchEvent(new KeyboardEvent(type, true, false, 0, keyCode, cast location, false, false, keyCode == KEY_SHIFT));
	}

	/** The top-most active button under a point given in stage pixels. */
	static function zoneAt(stageX:Float, stageY:Float):TouchZone
	{
		if (FlxG.game == null || FlxG.scaleMode == null)
			return null;

		// stage pixels -> game pixels (the game is scaled and may have black bars)
		var gameX = (stageX - FlxG.game.x) / FlxG.scaleMode.scale.x;
		var gameY = (stageY - FlxG.game.y) / FlxG.scaleMode.scale.y;

		var i = zones.length;
		while (i-- > 0)
		{
			var zone = zones[i];
			if (zone.contains(gameX, gameY))
				return zone;
		}
		return null;
	}
}

private class TouchZone
{
	public var sprite:FlxSprite;
	public var keyCode:Int;
	public var location:Int;

	public function new(sprite:FlxSprite, keyCode:Int, location:Int)
	{
		this.sprite = sprite;
		this.keyCode = keyCode;
		this.location = location;
	}

	public function id():String
		return keyCode + '_' + location;

	public function contains(gameX:Float, gameY:Float):Bool
	{
		if (sprite == null || !sprite.exists || !sprite.alive || !sprite.visible)
			return false;

		var cam:FlxCamera = (sprite.cameras != null && sprite.cameras.length > 0) ? sprite.cameras[0] : FlxG.camera;
		if (cam == null || !cam.visible || !cam.exists)
			return false;

		// game pixels -> this camera's screen pixels (controls cameras are not zoomed or scrolled)
		var x = (gameX - cam.x) / cam.zoom;
		var y = (gameY - cam.y) / cam.zoom;
		var left = sprite.x - cam.scroll.x * sprite.scrollFactor.x;
		var top = sprite.y - cam.scroll.y * sprite.scrollFactor.y;
		return x >= left && x < left + sprite.width && y >= top && y < top + sprite.height;
	}
}
