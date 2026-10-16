# Python stuff
# The function properties still work if you change the function names.
# For example:
#   def onEvent(name, v1, v2, strumTime):
#       # value 1 is the camera flash length, value 2 is the flash color
#       if name == 'flashCamera':
#           cameraFlash('camGame', v2, v1)
#
# The functions still work, its just with different function names.

def onCreate():
	# When the python file is started/created, some variables weren't created yet
	pass

def onCreatePost():
	# End of "create", all variables have already been loaded, recommended.
	pass

def onDestroy():
	# When the python file is ended (Song fade out finished)
	pass


# Gameplay/Song interactions
def onBeatHit():
	# Triggered 4 times per section
	pass

def onStepHit():
	# Triggered 16 times per section
	pass

def onUpdate(elapsed):
	# Start of "update", some variables weren't updated yet
	pass

def onUpdatePost(elapsed):
	# End of "update"
	pass

def onStartCountdown():
	# Countdown started, duh
	# Return Function_Stop if you want to stop the countdown from happening (Can be used to trigger dialogues and stuff! You can trigger the countdown with startCountdown())
	return Function_Continue

def onCountdownTick(counter):
	# counter = 0 -> "Three"
	# counter = 1 -> "Two"
	# counter = 2 -> "One"
	# counter = 3 -> "Go!"
	# counter = 4 -> Nothing happens lol, tho it is triggered at the same time as onSongStart i think
	pass

def onSongStart():
	# Inst and Vocals start playing, songPosition = 0
	pass

def onEndSong():
	# Song ended/starting transition (Will be delayed if you're unlocking an achievement)
	# return Function_Stop to stop the song from ending for playing a cutscene or something.
	return Function_Continue


# Substate interactions
def onPause():
	# Called when you press Pause while not on a cutscene/etc
	# return Function_Stop if you want to stop the player from pausing the game
	return Function_Continue

def onResume():
	# Called after the game has been resumed from a pause (WARNING: Not necessarily from the pause screen, but most likely is!!!)
	pass

def onGameOver():
	# You died! Called every single frame your health is lower (or equal to) zero
	# return Function_Stop if you want to stop the player from going into the game over screen
	return Function_Continue

def onGameOverConfirm(retry):
	# Called when you Press Enter/Esc on Game Over
	# If you've pressed Esc, value "retry" will be False
	pass


# Dialogue (When a dialogue is finished, it calls startCountdown again)
def onNextDialogue(line):
	# Triggered when the next dialogue line starts, dialogue line starts with 1
	pass

def onSkipDialogue(line):
	# Triggered when you press Enter and skip a dialogue line that was still being typed, dialogue line starts with 1
	pass


# Note miss/hit
def goodNoteHit(id, direction, noteType, isSustainNote):
	# Function called when you hit a note (after note hit calculations)
	# id: The note member id, you can get whatever variable you want from this note, example: "getPropertyFromGroup('notes', id, 'strumTime')"
	# direction: 0 = Left, 1 = Down, 2 = Up, 3 = Right
	# noteType: The note type string/tag
	# isSustainNote: If it's a hold note, can be either True or False
	pass

def opponentNoteHit(id, direction, noteType, isSustainNote):
	# Works the same as goodNoteHit, but for Opponent's notes being hit
	pass

def noteMissPress(direction):
	# Called after the note press miss calculations
	# Player pressed a button, but there was no note to hit (ghost miss)
	pass

def noteMiss(id, direction, noteType, isSustainNote):
	# Called after the note miss calculations
	# Player missed a note by letting it go offscreen
	pass


# Other function hooks
def onRecalculateRating():
	# return Function_Stop if you want to do your own rating calculation,
	# use setRatingPercent() to set the number on the calculation and setRatingString() to set the funny rating name
	# NOTE: THIS IS CALLED BEFORE THE CALCULATION!!!
	return Function_Continue

def onMoveCamera(focus):
	if focus == 'boyfriend':
		# called when the camera focus on boyfriend
		pass
	elif focus == 'dad':
		# called when the camera focus on dad
		pass


# Event notes hooks
def onEvent(name, value1, value2, strumTime):
	# event note triggered
	# triggerEvent() does not call this function!!

	# print('Event triggered: ', name, value1, value2)
	pass

def eventEarlyTrigger(name, value1, value2, strumTime):
	# Here's a port of the Kill Henchmen early trigger but on Python instead of Haxe:
	#
	# if name == 'Kill Henchmen':
	#     return 280
	#
	# This makes the "Kill Henchmen" event be triggered 280 miliseconds earlier so that the kill sound is perfectly timed with the song

	# write your shit under this line, the new return value will override the ones hardcoded on the engine
	pass


# Tween/Timer hooks
def onTweenCompleted(tag):
	# A tween you called has been completed, value "tag" is it's tag
	pass

def onTimerCompleted(tag, loops, loopsLeft):
	# A loop from a timer you called has been completed, value "tag" is it's tag
	# loops = how many loops it will have done when it ends completely
	# loopsLeft = how many are remaining
	pass
