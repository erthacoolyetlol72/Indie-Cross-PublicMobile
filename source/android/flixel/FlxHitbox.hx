package android.flixel;

import android.TouchKeys;
import android.flixel.FlxButton;
import flash.display.BitmapData;
import flash.display.Shape;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * Which extra Indie Cross mechanic buttons a song needs.
 */
enum HitboxMechanics
{
	NONE;
	DODGE; // SPACE
	ATTACK; // SHIFT (Sans attack / Cuphead shooting)
	ATTACK_DODGE; // SHIFT + SPACE
	ATTACK_SIDES_DODGE; // left SHIFT + SPACE + right SHIFT (Bendy: Striker on the left, Piper on the right)
}

typedef MechanicButtonInfo =
{
	var text:String;
	var keyCode:Int;
	var location:Int;
	var color:Int;
}

/**
 * A zone with 4 hint's (A hitbox).
 * It's really easy to customize the layout.
 *
 * Indie Cross: when a song has dodge / attack mechanics, a row of big buttons is put along
 * the top of the screen and the four note lanes fill the rest, so they never overlap.
 *
 * @author Mihai Alexandru (M.A. Jigsaw)
 */
class FlxHitbox extends FlxSpriteGroup
{
	public var buttonLeft:FlxButton = new FlxButton(0, 0);
	public var buttonDown:FlxButton = new FlxButton(0, 0);
	public var buttonUp:FlxButton = new FlxButton(0, 0);
	public var buttonRight:FlxButton = new FlxButton(0, 0);

	public var buttonAttackLeft:FlxButton;
	public var buttonAttackRight:FlxButton;
	public var buttonDodge:FlxButton;

	/** Height of the mechanics row (0 when the song has no mechanics). */
	public var mechanicsHeight(default, null):Int = 0;

	/** Space kept free at the right end of the mechanics row (for the pause button). */
	public static inline var PAUSE_SPACE:Int = 120;

	/**
	 * Create the zone.
	 */
	public function new(?mechanics:HitboxMechanics)
	{
		super();

		if (mechanics == null)
			mechanics = NONE;

		var row:Array<MechanicButtonInfo> = [];
		var attack:MechanicButtonInfo = {text: 'ATTACK', keyCode: TouchKeys.KEY_SHIFT, location: TouchKeys.LOCATION_LEFT, color: 0xFF3333};
		var dodge:MechanicButtonInfo = {text: 'DODGE', keyCode: TouchKeys.KEY_SPACE, location: TouchKeys.LOCATION_STANDARD, color: 0x3399FF};
		switch (mechanics)
		{
			case DODGE:
				row = [dodge];
			case ATTACK:
				row = [attack];
			case ATTACK_DODGE:
				row = [attack, dodge];
			case ATTACK_SIDES_DODGE:
				attack.text = '< ATTACK';
				row = [
					attack,
					dodge,
					{text: 'ATTACK >', keyCode: TouchKeys.KEY_SHIFT, location: TouchKeys.LOCATION_RIGHT, color: 0xFF3333}
				];
			case NONE:
		}

		if (row.length > 0)
			mechanicsHeight = Std.int(FlxG.height * 0.22);

		var laneY:Int = mechanicsHeight;
		var laneH:Int = FlxG.height - mechanicsHeight;
		var laneW:Int = Std.int(FlxG.width / 4);

		add(buttonLeft = createHint(0, laneY, laneW, laneH, 0xFF00FF, TouchKeys.KEY_LEFT));
		add(buttonDown = createHint(FlxG.width / 4, laneY, laneW, laneH, 0x00FFFF, TouchKeys.KEY_DOWN));
		add(buttonUp = createHint(FlxG.width / 2, laneY, laneW, laneH, 0x00FF00, TouchKeys.KEY_UP));
		add(buttonRight = createHint((FlxG.width / 2) + (FlxG.width / 4), laneY, laneW, laneH, 0xFF0000, TouchKeys.KEY_RIGHT));

		var rowW:Float = (FlxG.width - PAUSE_SPACE) / Math.max(1, row.length);
		for (i in 0...row.length)
		{
			var info = row[i];
			var button = createMechanicButton(rowW * i, 0, Std.int(rowW), mechanicsHeight, info);
			if (info.keyCode == TouchKeys.KEY_SPACE)
				buttonDodge = button;
			else if (info.location == TouchKeys.LOCATION_RIGHT)
				buttonAttackRight = button;
			else
				buttonAttackLeft = button;
		}

		scrollFactor.set();
	}

	/**
	 * Clean up memory.
	 */
	override function destroy()
	{
		super.destroy();

		buttonLeft = null;
		buttonDown = null;
		buttonUp = null;
		buttonRight = null;
		buttonAttackLeft = null;
		buttonAttackRight = null;
		buttonDodge = null;
	}

	private function createHintGraphic(Width:Int, Height:Int, Color:Int = 0xFFFFFF):BitmapData
	{
		var shape:Shape = new Shape();
		shape.graphics.beginFill(Color);
		shape.graphics.lineStyle(10, Color, 1);
		shape.graphics.drawRect(0, 0, Width, Height);
		shape.graphics.endFill();

		var bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape);
		return bitmap;
	}

	private function createHint(X:Float, Y:Float, Width:Int, Height:Int, Color:Int = 0xFFFFFF, KeyCode:Int = -1):FlxButton
	{
		var hint:FlxButton = new FlxButton(X, Y);
		hint.loadGraphic(createHintGraphic(Width, Height, Color));
		hint.solid = false;
		hint.immovable = true;
		hint.scrollFactor.set();
		hint.alpha = 0.00001;
		hint.onDown.callback = function()
		{
			if (hint.alpha != AndroidControls.getOpacity(true))
				hint.alpha = AndroidControls.getOpacity(true);
		}
		hint.onUp.callback = function()
		{
			if (hint.alpha != 0.00001)
				hint.alpha = 0.00001;
		}
		hint.onOut.callback = hint.onUp.callback;
		hint.onOver.callback = hint.onDown.callback;
		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end
		if (KeyCode != -1)
			TouchKeys.register(hint, KeyCode);
		return hint;
	}

	/** An always-visible labelled button for a mechanic (dodge / attack). */
	private function createMechanicButton(X:Float, Y:Float, Width:Int, Height:Int, info:MechanicButtonInfo):FlxButton
	{
		var idleAlpha:Float = 0.25;
		var button:FlxButton = new FlxButton(X, Y);
		button.loadGraphic(createHintGraphic(Width, Height, info.color));
		button.solid = false;
		button.immovable = true;
		button.scrollFactor.set();
		button.alpha = idleAlpha;
		button.onDown.callback = function() button.alpha = 0.6;
		button.onUp.callback = function() button.alpha = idleAlpha;
		button.onOut.callback = button.onUp.callback;
		button.onOver.callback = button.onDown.callback;
		#if FLX_DEBUG
		button.ignoreDrawDebug = true;
		#end
		add(button);
		TouchKeys.register(button, info.keyCode, info.location);

		var label:FlxText = new FlxText(X, Y + Height / 2 - 24, Width, info.text, 40);
		label.setFormat(null, 40, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		label.borderSize = 3;
		label.alpha = 0.8;
		label.scrollFactor.set();
		add(label);

		return button;
	}
}
