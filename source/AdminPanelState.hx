package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.utils.Assets;
#if mobile
import android.flixel.FlxVirtualPad;
#end

using StringTools;

typedef AdminSong =
{
	var name:String;
	var week:Int;
	var group:String;
	var hardOnly:Bool;
}

/**
 * Testing panel: play any song or cutscene straight away and switch test settings.
 * Everything is tapped (or clicked); the phone's back button / ESCAPE goes back to the main menu.
 */
class AdminPanelState extends MusicBeatState
{
	/** When on, the player cannot die in songs (read by PlayState). */
	public static var godMode:Bool = false;

	static var difficulty:Int = 2;
	static var tab:Int = 0; // 0 = songs, 1 = cutscenes

	static final SONGS:Array<AdminSong> = [
		{name: 'Snake-Eyes', week: 0, group: 'CUPHEAD', hardOnly: false},
		{name: 'Technicolor-Tussle', week: 0, group: 'CUPHEAD', hardOnly: false},
		{name: 'Knockout', week: 0, group: 'CUPHEAD', hardOnly: false},
		{name: 'Whoopee', week: 1, group: 'SANS', hardOnly: false},
		{name: 'Sansational', week: 1, group: 'SANS', hardOnly: false},
		{name: 'Burning-In-Hell', week: 1, group: 'SANS', hardOnly: false},
		{name: 'Final-Stretch', week: 1, group: 'SANS', hardOnly: false},
		{name: 'Imminent-Demise', week: 2, group: 'BENDY', hardOnly: false},
		{name: 'Terrible-Sin', week: 2, group: 'BENDY', hardOnly: false},
		{name: 'Last-Reel', week: 2, group: 'BENDY', hardOnly: false},
		{name: 'Nightmare-Run', week: 2, group: 'BENDY', hardOnly: false},
		{name: 'Satanic-Funkin', week: 0, group: 'BONUS', hardOnly: false},
		{name: 'Bad-To-The-Bone', week: 1, group: 'BONUS', hardOnly: false},
		{name: 'Bonedoggle', week: 1, group: 'BONUS', hardOnly: false},
		{name: 'Ritual', week: 2, group: 'BONUS', hardOnly: false},
		{name: 'Freaky-Machine', week: 2, group: 'BONUS', hardOnly: false},
		{name: 'Devils-Gambit', week: 0, group: 'NIGHTMARE', hardOnly: true},
		{name: 'Bad-Time', week: 1, group: 'NIGHTMARE', hardOnly: true},
		{name: 'Despair', week: 2, group: 'NIGHTMARE', hardOnly: true}
	];

	static inline var LIST_X:Float = 40;
	static inline var LIST_TOP:Float = 150;
	static inline var ROW_H:Float = 58;

	var rows:FlxTypedGroup<FlxText>;
	var rowActions:Array<Void->Void> = [];
	var listHeight:Float = 0;
	var scroll:Float = 0;

	var buttons:Array<FlxText> = [];
	var buttonActions:Array<Void->Void> = [];
	var buttonIds:Array<String> = [];
	var status:FlxText;

	var pressY:Float = 0;
	var pressScroll:Float = 0;
	var dragged:Bool = false;
	var busy:Bool = false;
	var video:VideoHandler;

	override function create()
	{
		super.create();

		FlxG.mouse.visible = true;

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF101018);
		bg.scrollFactor.set();
		add(bg);

		var panel = new FlxSprite(FlxG.width - 440, 0).makeGraphic(440, FlxG.height, 0xFF1C1C2C);
		panel.scrollFactor.set();
		add(panel);

		rows = new FlxTypedGroup<FlxText>();
		add(rows);

		// header drawn over the list so scrolled rows slide under it
		var header = new FlxSprite().makeGraphic(FlxG.width - 440, Std.int(LIST_TOP - 10), 0xFF101018);
		header.scrollFactor.set();
		add(header);

		var title = new FlxText(LIST_X, 18, 0, 'ADMIN PANEL', 44);
		title.setFormat(null, 44, FlxColor.YELLOW, LEFT, OUTLINE, FlxColor.BLACK);
		add(title);

		addButton(LIST_X, 82, '[ SONGS ]', function() switchTab(0), 300);
		addButton(LIST_X + 300, 82, '[ CUTSCENES ]', function() switchTab(1), 330);

		var x = FlxG.width - 420;
		addButton(x, 20, '< BACK TO MENU', goBack);
		addButton(x, 110, '', cycleDifficulty, 400, 'diff');
		addButton(x, 175, '', cycleMechanics, 400, 'mech');
		addButton(x, 240, '', function()
		{
			FlxG.save.data.botplay = !FlxG.save.data.botplay;
			FlxG.save.flush();
		}, 400, 'bot');
		addButton(x, 305, '', function() godMode = !godMode, 400, 'god');
		addButton(x, 370, '', function() MainMenuState.debugTools = !MainMenuState.debugTools, 400, 'debug');
		addButton(x, 455, 'UNLOCK ALL SONGS', unlockAll);

		status = new FlxText(x, FlxG.height - 120, 400, '', 22);
		status.setFormat(null, 22, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		add(status);

		switchTab(tab);
		refreshLabels();

		#if mobile
		addVirtualPad(NONE, B);
		#end
	}

	function addButton(x:Float, y:Float, text:String, action:Void->Void, width:Float = 400, ?id:String)
	{
		var b = new FlxText(x, y, width, text, 30);
		b.setFormat(null, 30, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		b.borderSize = 2;
		b.scrollFactor.set();
		b.ID = buttons.length;
		buttonIds.push(id);
		add(b);
		buttons.push(b);
		buttonActions.push(function()
		{
			action();
			refreshLabels();
		});
	}

	function refreshLabels()
	{
		for (b in buttons)
		{
			switch (buttonIds[b.ID])
			{
				case 'diff':
					b.text = 'Difficulty: ' + HelperFunctions.difficultyFromInt(difficulty).toUpperCase();
				case 'mech':
					b.text = 'Mechanics: ' + HelperFunctions.mechDifficultyFromInt(FreeplayState.curMechDifficulty).toUpperCase();
				case 'bot':
					b.text = 'Botplay: ' + onOff(FlxG.save.data.botplay == true);
				case 'god':
					b.text = 'God mode: ' + onOff(godMode);
				case 'debug':
					b.text = 'Debug tools: ' + onOff(MainMenuState.debugTools);
			}
		}
	}

	function onOff(v:Bool):String
		return v ? 'ON' : 'OFF';

	function cycleDifficulty()
	{
		difficulty = (difficulty + 1) % 3;
	}

	function cycleMechanics()
	{
		// Standard -> Hell -> Off
		FreeplayState.curMechDifficulty = switch (FreeplayState.curMechDifficulty)
		{
			case 1: 0;
			case 0: 2;
			default: 1;
		}
	}

	function unlockAll()
	{
		FlxG.save.data.freeplaylocked = [false, false, false];
		FlxG.save.data.weeksbeat = [true, true, true];
		FlxG.save.data.weeksbeatonhard = [true, true, true];
		FlxG.save.data.shownalerts = [true, true, true];
		FlxG.save.data.hasgenocided = true;
		FlxG.save.data.haspacifisted = true;
		FlxG.save.flush();
		setStatus('Everything unlocked.');
	}

	function setStatus(text:String)
	{
		status.text = text;
		trace('ADMIN ' + text);
	}

	function switchTab(t:Int)
	{
		tab = t;
		scroll = 0;
		rowActions = [];
		for (row in rows.members)
			if (row != null)
				row.destroy();
		rows.clear();

		var y:Float = 0;
		if (tab == 0)
		{
			var lastGroup = '';
			for (song in SONGS)
			{
				if (song.group != lastGroup)
				{
					lastGroup = song.group;
					addRow(y, '- ' + song.group + ' -', null, FlxColor.GRAY);
					y += ROW_H;
				}
				var s = song;
				addRow(y, song.name.replace('-', ' ') + (song.hardOnly ? '  (hard)' : ''), function() playSong(s), FlxColor.WHITE);
				y += ROW_H;
			}
		}
		else
		{
			var names = videoNames();
			if (names.length == 0)
				addRow(y, 'No cutscenes found in this build.', null, FlxColor.GRAY);
			for (name in names)
			{
				var n = name;
				addRow(y, name, function() playCutscene(n), FlxColor.WHITE);
				y += ROW_H;
			}
		}
		listHeight = y;
		positionRows();
	}

	function addRow(y:Float, text:String, action:Void->Void, color:FlxColor)
	{
		var row = new FlxText(LIST_X, LIST_TOP + y, FlxG.width - 440 - LIST_X * 2, text, 34);
		row.setFormat(null, 34, color, LEFT, OUTLINE, FlxColor.BLACK);
		row.borderSize = 2;
		row.scrollFactor.set();
		row.ID = rowActions.length;
		rows.add(row);
		rowActions.push(action);
	}

	function positionRows()
	{
		var maxScroll = Math.max(0, listHeight - (FlxG.height - LIST_TOP - 20));
		if (scroll < 0)
			scroll = 0;
		if (scroll > maxScroll)
			scroll = maxScroll;

		var i = 0;
		for (row in rows.members)
		{
			if (row == null)
				continue;
			row.y = LIST_TOP + i * ROW_H - scroll;
			row.visible = row.y > LIST_TOP - ROW_H && row.y < FlxG.height;
			i++;
		}
	}

	/** Cutscene names, e.g. "bendy/1" (pictures on phones, mp4 files on PC). */
	function videoNames():Array<String>
	{
		var names:Array<String> = [];
		for (id in Assets.list())
		{
			var name:String = null;
			if (id.startsWith('assets/videoframes/') && id.endsWith('/info.txt'))
				name = id.substring('assets/videoframes/'.length, id.length - '/info.txt'.length);
			else if (id.startsWith('assets/videos/') && id.endsWith('.mp4'))
				name = id.substring('assets/videos/'.length, id.length - '.mp4'.length);
			if (name != null && names.indexOf(name) == -1)
				names.push(name);
		}
		names.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return names;
	}

	function playSong(song:AdminSong)
	{
		if (busy)
			return;
		busy = true;

		var diff = song.hardOnly ? 2 : difficulty;
		setStatus('Loading ' + song.name + ' (' + HelperFunctions.difficultyFromInt(diff) + ')...');
		FlxG.sound.play(Paths.sound('confirmMenu'));

		HelperFunctions.checkExistingChart(song.name, Highscore.formatSong(song.name, diff));

		StoryMenuState.leftDuringWeek = false;
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = diff;
		PlayState.difficulty = diff;
		PlayState.storyWeek = song.week;
		PlayState.mechanicType = FreeplayState.curMechDifficulty;
		PlayState.geno = false;
		PlayState.playCutscene = false;
		PlayState.storyIndex = 0;

		LoadingState.target = new PlayState();
		LoadingState.stopMusic = true;
		Main.switchState(new LoadingState());
	}

	function playCutscene(name:String)
	{
		if (busy)
			return;
		busy = true;
		setStatus('Playing ' + name + ' (tap to skip)');

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		video = new VideoHandler();
		video.allowSkip = true;
		video.finishCallback = function()
		{
			busy = false;
			video = null;
			setStatus('Finished ' + name);
			FlxG.sound.playMusic(Paths.music(Main.menuMusic), 0.7);
		};
		video.playMP4(Paths.video(name), false, null, false, true, false);
	}

	function goBack()
	{
		if (busy)
			return;
		busy = true;
		Main.switchState(new MainMenuState());
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (busy)
			return;

		if (controls.BACK)
		{
			goBack();
			return;
		}

		// drag the list up and down, tap a row or a button
		if (FlxG.mouse.justPressed)
		{
			pressY = FlxG.mouse.screenY;
			pressScroll = scroll;
			dragged = false;
		}

		if (FlxG.mouse.pressed && FlxG.mouse.screenX < FlxG.width - 440)
		{
			var dy = FlxG.mouse.screenY - pressY;
			if (Math.abs(dy) > 15)
				dragged = true;
			if (dragged)
			{
				scroll = pressScroll - dy;
				positionRows();
			}
		}

		if (FlxG.mouse.wheel != 0)
		{
			scroll -= FlxG.mouse.wheel * ROW_H;
			positionRows();
		}

		if (FlxG.mouse.justReleased && !dragged)
		{
			var mx = FlxG.mouse.screenX;
			var my = FlxG.mouse.screenY;

			for (b in buttons)
			{
				if (hit(b, mx, my))
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					buttonActions[b.ID]();
					return;
				}
			}

			if (my >= LIST_TOP)
			{
				for (row in rows.members)
				{
					if (row != null && row.visible && hit(row, mx, my) && rowActions[row.ID] != null)
					{
						rowActions[row.ID]();
						return;
					}
				}
			}
		}
	}

	function hit(t:FlxText, x:Float, y:Float):Bool
	{
		return x >= t.x && x <= t.x + t.width && y >= t.y - 6 && y <= t.y + t.height + 6;
	}
}
