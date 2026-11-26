package;

import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

/**
 * File checks that also work on Android, where the game's files are packed inside the APK
 * and cannot be seen with sys.FileSystem.
 */
class AssetCheck
{
	public static function exists(path:String):Bool
	{
		#if mobile
		if (path.startsWith('./'))
			path = path.substr(2);

		// a video is shipped as a folder of pictures on phones
		if (path.endsWith('.mp4'))
		{
			var at = path.indexOf('videos/');
			var name = at == -1 ? path : path.substr(at + 'videos/'.length);
			return OpenFlAssets.exists('assets/videoframes/' + name.substr(0, name.length - 4) + '/info.txt');
		}

		if (OpenFlAssets.exists(path))
			return true;

		// files of a library ("assets/songs/...") are listed as "songs:assets/songs/..."
		var parts = path.split('/');
		if (parts.length > 2 && parts[0] == 'assets' && path.indexOf(':') == -1)
			return OpenFlAssets.exists(parts[1] + ':' + path);

		return false;
		#else
		return sys.FileSystem.exists(path);
		#end
	}

	public static function bitmap(path:String):BitmapData
	{
		#if mobile
		if (path.startsWith('./'))
			path = path.substr(2);
		return OpenFlAssets.getBitmapData(path, false);
		#else
		return BitmapData.fromFile(path);
		#end
	}
}
