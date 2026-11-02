package mobile.backend;

/**
 * A value that changes on every compile. The asset extractor stores it next to the extracted files,
 * so installing a new build always refreshes the files that came with it.
 */
class BuildStamp
{
	public static final ID:String = BuildStampMacro.get();
}
