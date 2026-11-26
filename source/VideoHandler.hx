package;

#if !mobile

import flixel.input.gamepad.FlxGamepad;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.events.Event;
import vlc.VlcBitmap;

// THIS IS FOR TESTING
// DONT STEAL MY CODE >:(
class VideoHandler
{
	public var finishCallback:Void->Void;
	public var stateCallback:FlxState;

	public var bitmap:VlcBitmap;

	public var sprite:FlxSprite;

	public var fadeToBlack:Bool = false;

	public var fadeFromBlack:Bool = false;

	public var allowSkip:Bool = false;

	public function new()
	{
		FlxG.autoPause = false;
	}

	public function playMP4(path:String, ?repeat:Bool = false, ?outputTo:FlxSprite = null, ?isWindow:Bool = false, ?isFullscreen:Bool = false,
			?midSong:Bool = false):Void
	{
		#if cpp
		if (!midSong)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
			}
		}

		bitmap = new VlcBitmap();
		bitmap.set_height(FlxG.stage.stageHeight);
		bitmap.set_width(FlxG.stage.stageHeight * (16 / 9));

		trace("Setting width to " + FlxG.stage.stageHeight * (16 / 9));
		trace("Setting height to " + FlxG.stage.stageHeight);

		bitmap.onVideoReady = onVLCVideoReady;
		bitmap.onComplete = onVLCComplete;
		bitmap.onError = onVLCError;

		FlxG.stage.addEventListener(Event.ENTER_FRAME, update);
		FlxG.stage.addEventListener(Event.ENTER_FRAME, fixVolume);
		fixVolume(null);

		if (repeat)
			bitmap.repeat = -1;
		else
			bitmap.repeat = 0;

		bitmap.inWindow = isWindow;
		bitmap.fullscreen = isFullscreen;

		FlxG.addChildBelowMouse(bitmap);
		bitmap.play(checkFile(path));

		if (outputTo != null)
		{
			// lol this is bad kek
			bitmap.alpha = 0;

			sprite = outputTo;
		}

		#end
	}

	function checkFile(fileName:String):String
	{
		var pDir = "";
		var appDir = "file:///" + Sys.getCwd() + "/";

		if (fileName.indexOf(":") == -1) // Not a path
			pDir = appDir;
		else if (fileName.indexOf("file://") == -1 || fileName.indexOf("http") == -1) // C:, D: etc? ..missing "file:///" ?
			pDir = "file:///";

		return pDir + fileName;
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function onVLCVideoReady()
	{
		trace("video loaded!");

		#if cpp
		if (sprite != null)
			sprite.loadGraphic(bitmap.bitmapData);
		#end

		if (fadeFromBlack)
		{
			FlxG.camera.fade(FlxColor.BLACK, 0, false);
		}
	}

	function fixVolume(e:Event)
	{
		bitmap.volume = 0;
		if (!FlxG.sound.muted && FlxG.sound.volume > 0.01) 
		{
			bitmap.volume = FlxG.sound.volume * 0.5 + 0.5;
		}
	}

	public function onVLCComplete()
	{
		#if cpp
		bitmap.stop();

		// Clean player, just in case! Actually no.

		if (fadeToBlack)
		{
			FlxG.camera.fade(FlxColor.BLACK, 0, false);
		}

		if (fadeFromBlack)
		{
			FlxG.camera.fade(FlxColor.BLACK, 1, true);
		}

		trace("Big, Big Chungus, Big Chungus!");

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			if (finishCallback != null)
			{
				finishCallback();
			}
			else if (stateCallback != null)
			{
				LoadingState.loadAndSwitchState(stateCallback);
			}

			bitmap.dispose();

			if (FlxG.game.contains(bitmap))
			{
				FlxG.game.removeChild(bitmap);
			}
		});
		#end
	}

	public function kill()
	{
		#if cpp
		bitmap.stop();

		if (finishCallback != null)
		{
			finishCallback();
		}

		bitmap.visible = false;
		#end
	}

	function onVLCError()
	{
		if (finishCallback != null)
		{
			finishCallback();
		}
		else if (stateCallback != null)
		{
			LoadingState.loadAndSwitchState(stateCallback);
		}
	}

	function update(e:Event)
	{
		if (FlxG.keys.justPressed.ENTER)
		{
			trySkip();
		}
		
		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.B)
			{
				trySkip();
			}
		}

		bitmap.volume = FlxG.sound.volume + 0.3; // shitty volume fix. then make it louder.

		if (FlxG.sound.volume <= 0.1)
			bitmap.volume = 0;
	}

	function trySkip()
	{
		if (allowSkip)
		{
			if (bitmap.isPlaying)
			{
				onVLCComplete();
			}
		}
	}
}
#end

#if mobile
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.system.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.geom.Point;
import openfl.utils.Assets;

using StringTools;

/**
 * Phones have no video player, so on mobile every cutscene is played as pictures plus its sound.
 * The build turns `assets/videos/NAME.mp4` into `assets/videoframes/NAME/` holding
 * `f0001.jpg ...`, `audio.ogg` (when the video has sound) and `info.txt` ("fps frames width height audio").
 * Same functions and fields as the desktop (VLC) version, so the game code is unchanged.
 */
class VideoHandler
{
	public var finishCallback:Void->Void;
	public var stateCallback:FlxState;

	public var bitmap:VideoFrames;

	public var sprite:FlxSprite;

	public var fadeToBlack:Bool = false;

	public var fadeFromBlack:Bool = false;

	public var allowSkip:Bool = false;

	var overlay:Bitmap;
	var completed:Bool = false;
	var listening:Bool = false;

	public function new()
	{
		FlxG.autoPause = false;
	}

	public function playMP4(path:String, ?repeat:Bool = false, ?outputTo:FlxSprite = null, ?isWindow:Bool = false, ?isFullscreen:Bool = false,
			?midSong:Bool = false):Void
	{
		if (!midSong)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
			}
		}

		bitmap = new VideoFrames(path, repeat);
		trace('VIDEO play ' + path + ' ok=' + bitmap.ok + ' frames=' + bitmap.frameCount + ' fps=' + bitmap.fps);

		if (!bitmap.ok)
		{
			// no pictures for this video: carry on as if it ended
			new FlxTimer().start(0.05, function(tmr:FlxTimer) onVLCError());
			return;
		}

		if (outputTo != null)
		{
			sprite = outputTo;
			sprite.loadGraphic(bitmap.canvas);
			// pictures are stored smaller than the video: draw them back at the video's size
			sprite.origin.set(0, 0);
			sprite.offset.set(0, 0);
			sprite.scale.set(bitmap.videoWidth / bitmap.canvas.width, bitmap.videoHeight / bitmap.canvas.height);
		}
		else
		{
			overlay = new Bitmap(bitmap.canvas, null, true);
			FlxG.addChildBelowMouse(overlay);
			fitOverlay();
		}

		FlxG.stage.addEventListener(Event.ENTER_FRAME, update);
		listening = true;

		bitmap.play();
		onVLCVideoReady();
	}

	function fitOverlay()
	{
		if (overlay == null)
			return;

		var scale:Float = Math.min(FlxG.stage.stageWidth / bitmap.canvas.width, FlxG.stage.stageHeight / bitmap.canvas.height);
		overlay.scaleX = overlay.scaleY = scale;
		overlay.x = (FlxG.stage.stageWidth - bitmap.canvas.width * scale) / 2;
		overlay.y = (FlxG.stage.stageHeight - bitmap.canvas.height * scale) / 2;
	}

	function onVLCVideoReady()
	{
		trace("video loaded!");

		if (fadeFromBlack)
		{
			FlxG.camera.fade(FlxColor.BLACK, 0, false);
		}
	}

	public function onVLCComplete()
	{
		if (completed)
			return;
		completed = true;

		stopListening();
		bitmap.stop();

		if (fadeToBlack)
		{
			FlxG.camera.fade(FlxColor.BLACK, 0, false);
		}

		if (fadeFromBlack)
		{
			FlxG.camera.fade(FlxColor.BLACK, 1, true);
		}

		trace('VIDEO done');

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			if (finishCallback != null)
			{
				finishCallback();
			}
			else if (stateCallback != null)
			{
				LoadingState.loadAndSwitchState(stateCallback);
			}

			removeOverlay();
		});
	}

	public function kill()
	{
		if (completed)
			return;
		completed = true;

		stopListening();
		if (bitmap != null)
			bitmap.stop();

		if (finishCallback != null)
		{
			finishCallback();
		}

		removeOverlay();
	}

	function onVLCError()
	{
		if (completed)
			return;
		completed = true;

		if (finishCallback != null)
		{
			finishCallback();
		}
		else if (stateCallback != null)
		{
			LoadingState.loadAndSwitchState(stateCallback);
		}
	}

	function removeOverlay()
	{
		if (overlay != null)
		{
			if (overlay.parent != null)
				overlay.parent.removeChild(overlay);
			overlay = null;
		}
	}

	function stopListening()
	{
		if (listening)
		{
			FlxG.stage.removeEventListener(Event.ENTER_FRAME, update);
			listening = false;
		}
	}

	function update(e:Event)
	{
		if (completed)
			return;

		// skip: tap the screen, ENTER or the phone's back button (ESCAPE)
		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE || FlxG.mouse.justPressed)
		{
			trySkip();
			if (completed)
				return;
		}

		fitOverlay();
		bitmap.update();

		if (bitmap.finished)
			onVLCComplete();
	}

	function trySkip()
	{
		if (allowSkip)
		{
			if (bitmap.isPlaying)
			{
				onVLCComplete();
			}
		}
	}
}

/**
 * Plays one cutscene's pictures in time with its sound (or with a clock when it has no sound).
 * Only one picture is decoded at a time.
 */
class VideoFrames
{
	public var ok(default, null):Bool = false;
	public var fps(default, null):Float = 15;
	public var frameCount(default, null):Int = 0;
	public var videoWidth(default, null):Int = 1280;
	public var videoHeight(default, null):Int = 720;
	public var canvas(default, null):BitmapData;
	public var isPlaying(default, null):Bool = false;
	public var finished(default, null):Bool = false;

	var dir:String;
	var repeat:Bool;
	var sound:FlxSound;
	var clockStart:Float = 0;
	var pausedAt:Float = -1;
	var shownFrame:Int = -1;
	var zero:Point = new Point(0, 0);

	public function new(videoPath:String, repeat:Bool)
	{
		this.repeat = repeat;

		// assets/videos/bendy/1.mp4 -> assets/videoframes/bendy/1/
		var name = videoPath;
		var at = name.indexOf('videos/');
		if (at != -1)
			name = name.substr(at + 'videos/'.length);
		if (name.endsWith('.mp4'))
			name = name.substr(0, name.length - 4);
		dir = 'assets/videoframes/' + name + '/';

		if (!Assets.exists(dir + 'info.txt'))
			return;

		var info = Assets.getText(dir + 'info.txt').trim().split(' ');
		fps = Std.parseFloat(info[0]);
		frameCount = Std.parseInt(info[1]);
		videoWidth = Std.parseInt(info[2]);
		videoHeight = Std.parseInt(info[3]);
		var hasAudio = info.length > 4 && info[4] == '1';

		if (frameCount <= 0 || Math.isNaN(fps) || fps <= 0)
			return;

		var first:BitmapData = loadFrame(1);
		if (first == null)
			return;
		canvas = new BitmapData(first.width, first.height, false, 0xFF000000);
		canvas.copyPixels(first, first.rect, zero);
		first.dispose();
		shownFrame = 1;

		if (hasAudio && Assets.exists(dir + 'audio.ogg'))
		{
			sound = new FlxSound().loadEmbedded(Assets.getSound(dir + 'audio.ogg', false), repeat);
			FlxG.sound.list.add(sound);
		}

		ok = true;
	}

	/* play / pause / resume / stop keep the calls the game makes on the VLC bitmap working */
	public function play()
	{
		isPlaying = true;
		finished = false;
		clockStart = Lib.getTimer();
		if (sound != null)
			sound.play(true);
	}

	public function pause()
	{
		if (!isPlaying)
			return;
		isPlaying = false;
		pausedAt = Lib.getTimer();
		if (sound != null)
			sound.pause();
	}

	public function resume()
	{
		if (isPlaying || finished)
			return;
		isPlaying = true;
		if (pausedAt >= 0)
			clockStart += Lib.getTimer() - pausedAt;
		pausedAt = -1;
		if (sound != null)
			sound.resume();
	}

	public function stop()
	{
		isPlaying = false;
		if (sound != null)
		{
			sound.stop();
			FlxG.sound.list.remove(sound, true);
			sound.destroy();
			sound = null;
		}
	}

	public function dispose()
	{
		stop();
	}

	public function update()
	{
		if (!ok || !isPlaying)
			return;

		var seconds:Float = (Lib.getTimer() - clockStart) / 1000;
		if (sound != null && sound.playing)
			seconds = sound.time / 1000; // stay in sync with the sound

		var frame:Int = Std.int(seconds * fps) + 1;
		if (frame > frameCount)
		{
			if (repeat)
			{
				clockStart = Lib.getTimer();
				if (sound != null && !sound.playing)
					sound.play(true);
				frame = 1;
			}
			else
			{
				isPlaying = false;
				finished = true;
				return;
			}
		}

		if (frame != shownFrame)
		{
			var picture:BitmapData = loadFrame(frame);
			if (picture != null)
			{
				canvas.copyPixels(picture, picture.rect, zero);
				picture.dispose();
			}
			shownFrame = frame;
		}
	}

	function loadFrame(index:Int):BitmapData
	{
		var path = dir + 'f' + StringTools.lpad(Std.string(index), '0', 4) + '.jpg';
		if (!Assets.exists(path))
			return null;
		return Assets.getBitmapData(path, false);
	}
}
#end
