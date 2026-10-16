# BF Clicker - a pure-Python mod chart.
# Place this file at mods/bf-clicker/data/bf-clicker/bf-clicker.py and play
# the "bf-clicker" song from Freeplay. All gameplay logic lives here
# (Hython - no Lua). Click on BF as many times as you can in 45 seconds.
#
# Runs through the engine's PythonScript modding system.

# ---------------------------------------------------------------- //
#                     SETTINGS / MODULE STATE                      //
# State is module-scoped; callbacks declare globals when they update it. //
# ---------------------------------------------------------------- //
ROUND_TIME = 45.0

g_started = False
g_resumeFramePending = False
g_finished = False
g_clicks = 0
g_misses = 0
g_best = 0
g_baseY = 0.0
g_floatPhase = 0.0
g_lastShown = -1
g_roundElapsed = 0.0
g_previousMusicVolume = None
g_previousMouseVisible = None
g_mouseVisibilityCaptured = False


# ---------------------------------------------------------------- //
#                              HELPERS                              //
# ---------------------------------------------------------------- //
def hideIfExists(target):
	# target is a dot-path like 'scoreTxt.visible'
	if getProperty(target) != None:
		setProperty(target, False)


# ---------------------------------------------------------------- //
#                              SETUP                              //
# ---------------------------------------------------------------- //
def onCreatePost():
	global g_baseY, g_best, g_previousMusicVolume, g_previousMouseVisible
	global g_mouseVisibilityCaptured

	# hide the rhythm-game opponents
	setProperty('dad.visible', False)
	if getProperty('gf') != None:
		setProperty('gf.visible', False)

	# hide the rhythm-game HUD
	hideIfExists('scoreTxt.visible')
	hideIfExists('healthBar.visible')
	hideIfExists('healthBarBG.visible')
	hideIfExists('iconP1.visible')
	hideIfExists('iconP2.visible')
	hideIfExists('strumLineNotes.visible')
	hideIfExists('timeBar.visible')
	hideIfExists('timeBarBG.visible')
	hideIfExists('timeTxt.visible')
	hideIfExists('songName.visible')
	hideIfExists('comboGroup.visible')
	hideIfExists('ratingsGroup.visible')

	# giant BF right in the middle of the screen
	scaleObject('boyfriend', 2, 2, True)
	screenCenter('boyfriend')
	g_baseY = getProperty('boyfriend.y')

	# lock the camera onto the screen center
	setProperty('camFollow.x', getPropertyFromClass('flixel.FlxG', 'width') / 2)
	setProperty('camFollow.y', getPropertyFromClass('flixel.FlxG', 'height') / 2)
	setProperty('camFollowPos.x', getPropertyFromClass('flixel.FlxG', 'width') / 2)
	setProperty('camFollowPos.y', getPropertyFromClass('flixel.FlxG', 'height') / 2)

	# keep the background music quiet, then restore the player's setting on exit
	g_previousMusicVolume = getPropertyFromClass('flixel.FlxG', 'sound.music.volume')
	if g_previousMusicVolume != None:
		setPropertyFromClass('flixel.FlxG', 'sound.music.volume', 0.5)

	# Capture before changing visibility. FlxG.mouse.visible is a Bool in this
	# engine; if a host cannot provide it, leave the cursor untouched.
	g_previousMouseVisible = getPropertyFromClass('flixel.FlxG', 'mouse.visible')
	if g_previousMouseVisible != None:
		g_mouseVisibilityCaptured = True
		setPropertyFromClass('flixel.FlxG', 'mouse.visible', True)

	# HUD texts
	makeLuaText('clicksTxt', 'CLICKS: 0', 600, 0, 16)
	setTextAlignment('clicksTxt', 'center')
	setTextSize('clicksTxt', 42)
	setTextBorder('clicksTxt', 3, '000000')
	screenCenter('clicksTxt', 'x')

	makeLuaText('timeTxt2', 'GET READY!', 600, 0, 70)
	setTextAlignment('timeTxt2', 'center')
	setTextSize('timeTxt2', 30)
	setTextBorder('timeTxt2', 3, '000000')
	screenCenter('timeTxt2', 'x')

	makeLuaText('bestTxt', 'BEST: 0', 600, 0, 112)
	setTextAlignment('bestTxt', 'center')
	setTextSize('bestTxt', 24)
	setTextBorder('bestTxt', 3, '000000')
	screenCenter('bestTxt', 'x')

	makeLuaText('missTxt', 'MISSES: 0', 600, 0, 146)
	setTextAlignment('missTxt', 'center')
	setTextSize('missTxt', 22)
	setTextBorder('missTxt', 3, '000000')
	screenCenter('missTxt', 'x')

	makeLuaText('helpTxt', 'CLICK BF!', 600, 0, 620)
	setTextAlignment('helpTxt', 'center')
	setTextSize('helpTxt', 24)
	setTextBorder('helpTxt', 3, '000000')
	screenCenter('helpTxt', 'x')

	# load the saved best score
	if getPropertyFromClass('flixel.FlxG', 'save.data.bfClickerBest') != None:
		g_best = int(getPropertyFromClass('flixel.FlxG', 'save.data.bfClickerBest'))
	else:
		g_best = 0
	setTextString('bestTxt', 'BEST: ' + str(g_best))


# ---------------------------------------------------------------- //
#                            SONG START                            //
# ---------------------------------------------------------------- //
def onSongStart():
	global g_started, g_roundElapsed, g_lastShown
	g_started = True
	g_roundElapsed = 0.0
	g_lastShown = 45
	setTextString('timeTxt2', 'TIME: 45')


def onResume():
	global g_resumeFramePending
	# The first update after a pause can carry the pause interval in elapsed on
	# some hosts. Drop just that sample; keep the accumulated round time intact.
	g_resumeFramePending = True


def restoreMouseVisibility():
	# A separate captured flag preserves an original False value and avoids
	# changing anything if the host did not provide a readable saved state.
	if g_mouseVisibilityCaptured:
		setPropertyFromClass('flixel.FlxG', 'mouse.visible', g_previousMouseVisible)


def saveBestScore():
	global g_best
	if g_clicks > g_best:
		g_best = g_clicks
		setPropertyFromClass('flixel.FlxG', 'save.data.bfClickerBest', g_best)
		flushGlobalSave()


# ---------------------------------------------------------------- //
#                              FRAME                               //
# ---------------------------------------------------------------- //
def onUpdate(elapsed):
	global g_clicks, g_misses, g_best, g_floatPhase, g_roundElapsed
	global g_lastShown, g_finished, g_resumeFramePending

	# Check PlayState directly instead of relying on elapsed being frozen by the
	# host. This also blocks clicks if an update is dispatched during a pause.
	paused = getPropertyFromClass('play.PlayState', 'instance.paused')
	if g_finished or paused == True:
		return
	if g_resumeFramePending:
		g_resumeFramePending = False
		elapsed = 0.0

	# keep the camera pinned to the center of the screen
	setProperty('camFollow.x', getPropertyFromClass('flixel.FlxG', 'width') / 2)
	setProperty('camFollow.y', getPropertyFromClass('flixel.FlxG', 'height') / 2)
	setProperty('camFollowPos.x', getPropertyFromClass('flixel.FlxG', 'width') / 2)
	setProperty('camFollowPos.y', getPropertyFromClass('flixel.FlxG', 'height') / 2)

	# gentle idle float so BF feels alive
	g_floatPhase = g_floatPhase + elapsed * 0.5
	if g_floatPhase >= 2.0:
		g_floatPhase = g_floatPhase - 2.0
	dy = 0.0
	if g_floatPhase < 1.0:
		dy = g_floatPhase * 10.0
	else:
		dy = (2.0 - g_floatPhase) * 10.0
	setProperty('boyfriend.y', g_baseY + dy)

	# Count only active gameplay time. PlayState normally stops updating while
	# paused, and the explicit state check above guards any dispatched updates.
	if g_started:
		g_roundElapsed = g_roundElapsed + elapsed
		if g_roundElapsed > ROUND_TIME:
			g_roundElapsed = ROUND_TIME

		# Integer round length minus elapsed whole seconds is equivalent to
		# ceil(remaining): show 45 at start, then 44 after the first full second.
		secondsLeft = int(ROUND_TIME) - int(g_roundElapsed)
		if secondsLeft < 0:
			secondsLeft = 0
		if secondsLeft != g_lastShown:
			g_lastShown = secondsLeft
			setTextString('timeTxt2', 'TIME: ' + str(g_lastShown))

	# PyCameraLib's getMouseX/Y return Flixel screen-space pointer coordinates.
	# Add camGame.scroll to convert them to world space, matching BF's x/y.
	# Flixel updateHitbox() has already incorporated scaleObject's 2x scale into
	# width and height, so use those dimensions once. FlxObject x/y are top-left.
	if g_started and paused != True and g_roundElapsed < ROUND_TIME and mouseClicked('left'):
		mx = getMouseX('game') + getProperty('camGame.scroll.x')
		my = getMouseY('game') + getProperty('camGame.scroll.y')
		bfx = getProperty('boyfriend.x')
		bfy = getProperty('boyfriend.y')
		bw = getProperty('boyfriend.width')
		bh = getProperty('boyfriend.height')
		if mx >= bfx and mx < bfx + bw and my >= bfy and my < bfy + bh:
			g_clicks = g_clicks + 1
			addScore(1)
			setTextString('clicksTxt', 'CLICKS: ' + str(g_clicks))
			if g_clicks > g_best:
				setTextString('bestTxt', 'BEST: ' + str(g_clicks) + ' (LIVE!)')
			else:
				setTextString('bestTxt', 'BEST: ' + str(g_best))
			playAnim('boyfriend', 'singUP', True)
			setProperty('boyfriend.scale.x', 2.35)
			setProperty('boyfriend.scale.y', 2.35)
			playSound('clickText', 0.6)
		else:
			g_misses = g_misses + 1
			setTextString('missTxt', 'MISSES: ' + str(g_misses))
			playSound('cancelMenu', 0.5)

	# ease the click-bounce back down to 2x
	sc = getProperty('boyfriend.scale.x')
	if sc > 2.0:
		nsc = sc - (sc - 2.0) * 0.2
		if nsc < 2.0:
			nsc = 2.0
		setProperty('boyfriend.scale.x', nsc)
		setProperty('boyfriend.scale.y', nsc)

	# time's up! wrap up the round
	if g_started and g_roundElapsed >= ROUND_TIME:
		g_finished = True
		setTextString('timeTxt2', 'TIME UP!')
		saveBestScore()
		setTextString('bestTxt', 'BEST: ' + str(g_best))
		restoreMouseVisibility()
		endSong()
		# endSong may unload/reset Flixel's cursor, so restore once more after it.
		restoreMouseVisibility()


# ---------------------------------------------------------------- //
#                             CLEANUP                              //
# ---------------------------------------------------------------- //
def onDestroy():
	global g_best

	# keep and flush the best score even if the player leaves mid-round
	saveBestScore()
	# Restore input state even if setup failed partway through; the helper is a
	# no-op unless the original cursor state was successfully captured.
	restoreMouseVisibility()
	if g_previousMusicVolume != None:
		setPropertyFromClass('flixel.FlxG', 'sound.music.volume', g_previousMusicVolume)
