package;

import JSEZip;
import Prompt;
import flixel.addons.display.FlxBackdrop;
import flixel.ui.FlxBar;
import flixel.util.FlxAxes;
import haxe.Http;
import haxe.zip.Compress;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.zip.Uncompress;
import haxe.zip.Writer;
import lime.app.Application;
import lime.app.Event;
import lime.utils.Bytes;
import openfl.display.BlendMode;
import openfl.events.ProgressEvent;
import openfl.net.URLLoader;
import openfl.net.URLRequest;
import openfl.utils.ByteArray;

class UpdateState extends MusicBeatState
{
	var progressText:FlxText;
	var progBar_bg:FlxSprite;
	var progressBar:FlxBar;
	var entire_progress:Float = 0; // 0 to 100;
	var download_info:FlxText;

	public var online_url:String = "";

	var downloadedSize:Float = 0;
	var content:String = "";
	var maxFileSize:Float = 0;

	var zip:URLLoader;
	var text:FlxText;

	var currentTask:String = "download_update"; // download_update,install_update

	var checker:FlxBackdrop;
	override function create()
	{
		super.create();
		FlxG.sound.playMusic(Paths.music('updateSong', "shared"), 0);
		FlxG.sound.music.pitch = 1;

		FlxG.sound.music.fadeIn(4, 0, 0.7);
		var bg:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image("aboutMenu", "preload"));
		bg.color = 0xFFFF8C19;
		bg.scale.set(1.1, 1.1);
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		checker = new FlxBackdrop(Paths.image('checker', 'preload'), FlxAxes.XY);
		checker.scale.set(1.4, 1.4);
		checker.color = 0xFF006AFF;
		checker.blend = BlendMode.LAYER;
		add(checker);
		checker.scrollFactor.set(0, 0.07);
		checker.alpha = 0.2;
		checker.updateHitbox();

		text = new FlxText(0, 0, 0, "Please wait, JS Engine is updating...", 18);
		text.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(text);
		text.screenCenter(X);
		text.y = 290;

		progBar_bg = new FlxSprite(FlxG.width / 2, text.y + 50).makeGraphic(500, 20, FlxColor.BLACK);
		add(progBar_bg);
		progBar_bg.x -= 250;
		progressBar = new FlxBar(progBar_bg.x + 5, progBar_bg.y + 5, LEFT_TO_RIGHT, Std.int(progBar_bg.width - 10), Std.int(progBar_bg.height - 10), this,
			"entire_progress", 0, 100);
		progressBar.numDivisions = 3000;
		progressBar.createFilledBar(0xFF8F8F8F, 0xFFAD4E00);
		add(progressBar);

		progressText = new FlxText(progressBar.x, progressBar.y - 20, 0, "0%", 16);
		progressText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(progressText);

		download_info = new FlxText(progressBar.x + progBar_bg.width, progressBar.y + progBar_bg.height, 0, "0B / 0B", 16);
		download_info.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(download_info);

		zip = new URLLoader();
		zip.dataFormat = BINARY;
		zip.addEventListener(ProgressEvent.PROGRESS, onDownloadProgress);
		zip.addEventListener(openfl.events.Event.COMPLETE, onDownloadComplete);

		getUpdateLink();
		prepareUpdate();
		checkAndStartDownload(online_url);
	}

	var lastVare:Float = 0;

	var lastTrackedBytes:Float = 0;
	var lastTime:Float = 0;
	var time:Float = 0;
	var speed:Float = 0;

	var downloadTime:Float = 0;

	var currentFile:String = "";

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		checker.x += 0.45 / (ClientPrefs.framerate / 60);
		checker.y += (0.16 / (ClientPrefs.framerate / 60));
		switch (currentTask)
		{
			case "download_update":
				time += elapsed;
				if (time > 1)
				{
					speed = downloadedSize - lastTrackedBytes;
					lastTime = time;
					lastTrackedBytes = downloadedSize;
					time = 0;

					// Divide file size by data speed to obtain download time.
					downloadTime = ((maxFileSize-downloadedSize) / (speed));
				}

				if (downloadedSize != lastVare)
				{
					lastVare = downloadedSize;
					download_info.text = convert_size(Std.int(downloadedSize)) + " / " + convert_size(Std.int(maxFileSize));
					download_info.x = (progBar_bg.x + progBar_bg.width) - download_info.width;

					entire_progress = (downloadedSize / maxFileSize) * 100;
				}

				progressText.text = FlxMath.roundDecimal(entire_progress, 2) + "%" + " - " + convert_size(Std.int(speed)) + "/s" + " - "
					+ convert_time(downloadTime) + " remaining";
			case "install_update":
				entire_progress = (downloadedSize / maxFileSize) * 100;
				progressText.text = FlxMath.roundDecimal(entire_progress, 2) + "%";
				download_info.text = currentFile;
				download_info.x = (progBar_bg.x + progBar_bg.width) - download_info.width;
			default:
		}
	}

	inline function getPlatform():String
	{
		#if windows
		return 'windows';
		#elseif linux
		return 'linux';
		#elseif android
		return 'android';
		/*
		#elseif ios
		return 'iOS';
		*/
		#else
		return '';
		#end
	}

	inline function getUpdateLink()
	{
		var fileEnd = #if android 'apk' #else 'zip' #end;
		online_url = "https://github.com/JordanSantiagoYT/FNF-JS-Engine/releases/download/" + TitleState.updateVersion + '/FNF-JS-Engine-${getPlatform()}.$fileEnd';
		trace("update url: " + online_url);
	}

	function prepareUpdate()
	{
		trace("preparing update...");
		trace("checking if update folder exists...");

		if (!FileSystem.exists("./update/"))
		{
			trace("update folder not found, creating the directory...");
			FileSystem.createDirectory("./update");
			FileSystem.createDirectory("./update/temp/");
			FileSystem.createDirectory("./update/raw/");
		}
		else
		{
			trace("update folder found");
			// delete any dirs if the update got interrupted
			if (FileSystem.exists("./update/temp/")) FileSystem.deleteDirectory("./update/temp/");
			if (FileSystem.exists("./update/raw/")) FileSystem.deleteDirectory("./update/raw/");
			FileSystem.createDirectory("./update/temp/");
			FileSystem.createDirectory("./update/raw/");
		}
	}

	var httpHandler:Http;
	var fatalError:Bool = false;
	var requestFinished:Bool = false;

	public function startDownload(url:String)
	{
			if (fatalError)
					return;

			trace("starting actual file download via URLLoader...");
			try {
					zip.load(new URLRequest(url));
			} catch (e:Dynamic) {
					trace('Failed to initiate URLLoader download: ' + e);
					Application.current.window.alert('Failed to start the download. Please try again.');
					FlxG.resetGame();
			}
	}

	public function checkAndStartDownload(url:String, redirects:Int = 0) {
			if (fatalError) return;

			if (redirects > 5) {
		        fatalError = true;
		        Application.current.window.alert("Too many redirects while trying to download the update.");
		        FlxG.resetGame();
		        return;
		    }

			trace("Checking update URL existence...");
			var httpCheck = new Http(url);

			httpCheck.onStatus = function(status:Int):Void {
					trace('HTTP Status for URL check: ' + status);
					switch(status) {
							case 200: // OK
							requestFinished = true;
							trace("Update file found. Initiating download...");
							startDownload(url); // Now proceed with the actual download

							case 301, 302, 303, 307, 308: //Redirect codes
			                var newURL = httpCheck.responseHeaders.get("Location");
							if (newURL == null) newURL = httpCheck.responseHeaders.get("location"); // lowercase URL if "location" is lowercase

			                if (newURL != null && newURL != "")
			                {
			                    trace("The update link has been redirected to:" + newURL);
			                    checkAndStartDownload(newURL, redirects + 1);
			                }
			                else
			                {
			                    fatalError = true;
			                    Application.current.window.alert("The update link was redirected but its Location header wasn't found.\nTry downloading the update manually from GitHub.");
			                    FlxG.resetGame();
			                }

							case 404: // Not Found
							trace('File not found at URL: ' + url);
							fatalError = true;
							Application.current.window.alert('Couldn\'t find the update file! The file may have been moved or doesn\'t exist for this version. Please check for a new version manually or report this issue.');
							FlxG.resetGame();

							default: //Any other HTTP errors
							trace('Unexpected HTTP status for URL check: ' + status);
							fatalError = true;
							Application.current.window.alert('An error occurred while checking for updates (Status: ' + status + '). Please try again later.');
							FlxG.resetGame();
					}
			}

			httpCheck.onError = function(msg:String):Void {
					if (requestFinished) return;
					trace('HTTP Error during URL check: ' + msg);
					fatalError = true;
					Application.current.window.alert('A network error occurred while checking for updates: ' + msg + '. Please check your internet connection.');
					FlxG.resetGame();
			}

			try {
					// Use customRequest with HEAD method for efficiency
					httpCheck.customRequest(false, null, "HEAD");
			} catch (e:Dynamic) {
					trace('Failed to send HEAD request: ' + e);
					fatalError = true;
					Application.current.window.alert('Failed to connect to the update server. Please check your internet connection.');
					FlxG.resetGame();
			}
	}

	function convert_size(bytes:Int)
	{
		if (bytes == 0)
		{
			return "0B";
		}

		var size_name:Array<String> = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
		var digit:Int = Std.int(Math.log(bytes) / Math.log(1024));
		return FlxMath.roundDecimal(bytes / Math.pow(1024, digit), 2) + " " + size_name[digit];
	}

	function convert_time(time:Float)
	{
		var seconds = Std.int(time % 60);
		var minutes = Std.int((time / 60) % 60);
		var hours = Std.int((time / (60 * 60)) % 24);

		var secStr:String = (seconds < 10) ? "0" + seconds : Std.string(seconds);
		var minStr:String = (minutes < 10) ? "0" + minutes : Std.string(minutes);
		var hoeStr:String = (hours < 10) ? "0" + hours : Std.string(hours);

		return hoeStr + ':' + minStr + ':' + secStr;
	}

	function onDownloadProgress(result:ProgressEvent)
	{
		downloadedSize = result.bytesLoaded;
		maxFileSize = result.bytesTotal;
	}

	function onDownloadComplete(result:openfl.events.Event)
	{
		var path:String = './update/temp/'; // JS Engine ' + TitleState.onlineVer + ".zip";

		if (!FileSystem.exists(path))
		{
			FileSystem.createDirectory(path);
		}

		if (!FileSystem.exists("./update/raw/"))
		{
			FileSystem.createDirectory("./update/raw/");
		}

		var fileBytes:Bytes = cast(zip.data, ByteArray);
		text.text = "Update downloaded successfully, saving update file...";
		text.screenCenter(X);
		File.saveBytes(path + "JS Engine v" + TitleState.updateVersion + ".zip", fileBytes);
		text.text = "Unpacking update file...";
		text.screenCenter(X);

		JSEZip.unzip(path + "JS Engine v" + TitleState.updateVersion + ".zip", "./update/raw/");
		text.text = "Update has finished! The update will be installed shortly..";
		text.screenCenter(X);

		zip.removeEventListener(ProgressEvent.PROGRESS, onDownloadProgress);
		zip.removeEventListener(openfl.events.Event.COMPLETE, onDownloadComplete);

		progressText.text = 'Complete';
		progressText.screenCenter(X);

		currentTask = 'complete';

		FlxG.sound.play(Paths.sound('confirmMenu'));

		new FlxTimer().start(3, function(e:FlxTimer)
		{
			installUpdate("./update/raw/");
		});
	}

	function installUpdate(updateFolder:String)
	{
		CoolUtil.updateTheEngine();
	}
}
