package quack.fnf.phoenix.android;

import java.io.File;
import java.io.IOException;

/**
 * Filesystem path checks shared by the Android provider and host-JVM tests.
 *
 * This rejects traversal and stable symlink escapes. Because java.io.File
 * performs path-based operations, callers must validate as close as possible
 * to each operation; this is not an atomic defense against a concurrent actor
 * with write access to the same directories.
 */
final class PhoenixDocumentPathPolicy
{
	private PhoenixDocumentPathPolicy() {}

	static boolean isSafeFile(File rootDirectory, File file)
	{
		try
		{
			String rootPath = rootDirectory.getCanonicalPath();
			String rootAbsolutePath = rootDirectory.getAbsolutePath();
			String absolutePath = file.getAbsolutePath();
			String canonicalPath = file.getCanonicalPath();

			// Reject traversal, symlinks, and paths outside the requested root.
			if (!isWithin(rootPath, absolutePath) || !isWithin(rootPath, canonicalPath)
				|| !absolutePath.equals(canonicalPath) || !isWithin(rootAbsolutePath, absolutePath))
				return false;
			if (!rootAbsolutePath.equals(absolutePath)
				&& !isSafeRelativePath(absolutePath.substring(rootAbsolutePath.length() + 1)))
				return false;
			return true;
		}
		catch (IOException | SecurityException e)
		{
			return false;
		}
	}

	static boolean isWithin(String rootPath, String path)
	{
		if (rootPath == null || path == null)
			return false;
		if (rootPath.equals(path))
			return true;

		String prefix = rootPath.endsWith(File.separator) ? rootPath : rootPath + File.separator;
		return path.startsWith(prefix);
	}

	static boolean isSafeRelativePath(String path)
	{
		if (path == null || path.length() == 0 || path.startsWith("/") || path.indexOf('\\') >= 0 || path.indexOf('\0') >= 0)
			return false;

		String[] segments = path.split("/", -1);
		for (String segment : segments)
		{
			if (segment.length() == 0 || ".".equals(segment) || "..".equals(segment))
				return false;
		}
		return true;
	}

	static boolean isValidDisplayName(String name)
	{
		return name != null && name.length() > 0 && !".".equals(name) && !"..".equals(name)
			&& name.indexOf('/') < 0 && name.indexOf('\\') < 0 && name.indexOf('\0') < 0;
	}
}
