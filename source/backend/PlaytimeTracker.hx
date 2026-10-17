package backend;

#if ACHIEVEMENTS_ALLOWED
import flixel.FlxBasic;
#if !flash
import lime.app.Application;
#end

/**
 * Tracks cumulative time spent with the game running and awards the playtime badge.
 */
class PlaytimeTracker extends FlxBasic
{
	static inline var ACHIEVEMENT_ID:String = 'lol';
	static inline var TARGET_HOURS:Float = 50;
	static inline var SAVE_INTERVAL_SECONDS:Float = 60;

	private var pendingSeconds:Float = 0;

	public function new()
	{
		super();

		#if !flash
		if (Application.current != null && Application.current.onExit != null)
			Application.current.onExit.add(onApplicationExit);
		#end
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (elapsed <= 0 || Math.isNaN(elapsed) || Achievements.isUnlocked(ACHIEVEMENT_ID))
			return;

		pendingSeconds += elapsed;

		// Persist at least once a minute, but award the badge as soon as its threshold is reached.
		if (Achievements.getScore(ACHIEVEMENT_ID) + pendingSeconds / 3600 >= TARGET_HOURS
			|| pendingSeconds >= SAVE_INTERVAL_SECONDS)
			savePendingTime();
	}

	private function onApplicationExit(_:Int):Void
	{
		savePendingTime();
	}

	private function savePendingTime():Void
	{
		if (pendingSeconds <= 0)
			return;

		final elapsedHours:Float = pendingSeconds / 3600;
		pendingSeconds = 0;
		Achievements.addScore(ACHIEVEMENT_ID, elapsedHours, false);

		// addScore flushes automatically when it unlocks the achievement.
		if (!Achievements.isUnlocked(ACHIEVEMENT_ID))
			FlxG.save.flush();
	}
}
#end
