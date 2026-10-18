package play;

typedef RatingQuote = {quote:String, threshold:Float}

class RatingQuotes {
	static final DEFAULT_RATING_QUOTES:Array<RatingQuote> = [
		{quote: 'How are you this bad?', threshold: 0.1},
		{quote: 'You Suck!', threshold: 0.2},
		{quote: 'Horribly shit', threshold: 0.3},
		{quote: 'Shit', threshold: 0.4},
		{quote: 'Bad', threshold: 0.5},
		{quote: 'Bruh', threshold: 0.6},
		{quote: 'Meh', threshold: 0.69},
		{quote: 'Nice', threshold: 0.7},
		{quote: 'Good', threshold: 0.8},
		{quote: 'Great', threshold: 0.9},
		{quote: 'Sick!', threshold: 1},
		{quote: 'Perfect!!', threshold: 1}
	];

	public static function loadRatingQuotes():Array<RatingQuote>
	{
		final lines:Array<String> = Mods.mergeAllTextsNamed('data/ratingQuotes/${ClientPrefs.rateNameStuff}.txt', '', true);
		if (lines == null)
		{
			FlxG.log.warn('Failed to find quotes for ratings!');
			return DEFAULT_RATING_QUOTES.copy();
		}

		final result:Array<RatingQuote> = [];
		for (rawLine in lines)
		{
			if (rawLine == null) continue;
			final line = rawLine.trim();
			if (line == '') continue;

			// Split on the LAST comma so quotes themselves may contain commas
			final split = line.lastIndexOf(',');
			final threshold = (split == -1) ? Math.NaN : Std.parseFloat(line.substr(split + 1).trim());
			if (Math.isNaN(threshold))
			{
				FlxG.log.warn('Invalid rating quote line: "$line"');
				continue;
			}

			result.push({quote: line.substr(0, split).trim(), threshold: threshold});
		}

		if (result.length == 0)
		{
			FlxG.log.warn('No valid rating quotes found!');
			return DEFAULT_RATING_QUOTES.copy();
		}
		return result;
	}
}