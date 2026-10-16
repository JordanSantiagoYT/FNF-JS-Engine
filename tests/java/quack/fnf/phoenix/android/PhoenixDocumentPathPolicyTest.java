package quack.fnf.phoenix.android;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;

/**
 * Host-JVM tests for the exact filesystem policy called by
 * PhoenixDocumentsProvider. Run through test_android_documents_provider.py.
 */
public final class PhoenixDocumentPathPolicyTest
{
	private static int assertions;

	public static void main(String[] args) throws Exception
	{
		Path sandbox = Files.createTempDirectory("phoenix-document-provider-");
		try
		{
			testRelativePathsAndDisplayNames();
			testCanonicalFilesystemConfinement(sandbox);
		}
		finally
		{
			deleteTree(sandbox.toFile());
		}
		System.out.println("PhoenixDocumentPathPolicy: " + assertions + " assertions passed");
	}

	private static void testRelativePathsAndDisplayNames()
	{
		check(PhoenixDocumentPathPolicy.isSafeRelativePath("mod/pack.json"), "normal nested path is accepted");
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath(null), "null path is rejected");
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath(""), "empty path is rejected");
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath("/outside"), "absolute path is rejected");
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath("../outside"), "parent traversal is rejected");
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath("mod/../outside"), "nested traversal is rejected");
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath("mod/./pack.json"), "dot segments are rejected");
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath("mod//pack.json"), "empty path segments are rejected");
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath("mod\\\\pack.json"), "backslash paths are rejected");
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath("mod/\u0000pack.json"), "NUL bytes are rejected");

		String encodedTraversal = Base64.getUrlEncoder().withoutPadding()
			.encodeToString("../outside".getBytes(StandardCharsets.UTF_8));
		String decodedTraversal = new String(Base64.getUrlDecoder().decode(encodedTraversal), StandardCharsets.UTF_8);
		check(!PhoenixDocumentPathPolicy.isSafeRelativePath(decodedTraversal), "URL-safe Base64 traversal is rejected after decoding");

		check(PhoenixDocumentPathPolicy.isValidDisplayName("Cool Mod.zip"), "ordinary display name is accepted");
		check(!PhoenixDocumentPathPolicy.isValidDisplayName(null), "null display name is rejected");
		check(!PhoenixDocumentPathPolicy.isValidDisplayName(""), "empty display name is rejected");
		check(!PhoenixDocumentPathPolicy.isValidDisplayName("."), "dot display name is rejected");
		check(!PhoenixDocumentPathPolicy.isValidDisplayName(".."), "parent display name is rejected");
		check(!PhoenixDocumentPathPolicy.isValidDisplayName("a/b"), "slash in display name is rejected");
		check(!PhoenixDocumentPathPolicy.isValidDisplayName("a\\\\b"), "backslash in display name is rejected");
		check(!PhoenixDocumentPathPolicy.isValidDisplayName("a\u0000b"), "NUL in display name is rejected");
	}

	private static void testCanonicalFilesystemConfinement(Path sandbox) throws IOException
	{
		File mods = sandbox.resolve("app-files/mods").toFile();
		File outside = sandbox.resolve("unrelated-private-data").toFile();
		check(mods.mkdirs(), "mods directory is created");
		check(outside.mkdir(), "outside directory is created");

		File safeFile = new File(mods, "safe.txt");
		check(safeFile.createNewFile(), "fixture file is created");
		check(PhoenixDocumentPathPolicy.isSafeFile(mods, mods), "root path is safe");
		check(PhoenixDocumentPathPolicy.isSafeFile(mods, safeFile), "in-root file is safe");
		check(PhoenixDocumentPathPolicy.isSafeFile(mods, new File(mods, "new-folder/new-file.txt")),
			"a not-yet-created in-root destination remains valid for create");
		check(!PhoenixDocumentPathPolicy.isSafeFile(mods, new File(mods, "../unrelated-private-data/secret.txt")),
			"canonical path check rejects an escaping path");
		check(!PhoenixDocumentPathPolicy.isWithin(mods.getAbsolutePath(),
			new File(mods.getParentFile(), "mods-backup").getAbsolutePath()),
			"path-prefix siblings are not treated as descendants");

		File outsideFile = new File(outside, "secret.txt");
		check(outsideFile.createNewFile(), "outside fixture is created");
		Path link = new File(mods, "escape").toPath();
		Files.createSymbolicLink(link, outside.toPath());
		check(!PhoenixDocumentPathPolicy.isSafeFile(mods, link.toFile()), "symlink itself is rejected");
		check(!PhoenixDocumentPathPolicy.isSafeFile(mods, link.resolve("secret.txt").toFile()),
			"symlink traversal to an unrelated directory is rejected");

		File aliasedRoot = sandbox.resolve("mods-alias").toFile();
		Files.createSymbolicLink(aliasedRoot.toPath(), mods.toPath());
		check(!PhoenixDocumentPathPolicy.isSafeFile(aliasedRoot, aliasedRoot), "a symlinked root is rejected");
	}

	private static void check(boolean condition, String message)
	{
		assertions++;
		if (!condition)
			throw new AssertionError(message);
	}

	private static void deleteTree(File file)
	{
		if (Files.isSymbolicLink(file.toPath()))
		{
			file.delete();
			return;
		}
		File[] children = file.listFiles();
		if (children != null)
			for (File child : children)
				deleteTree(child);
		file.delete();
	}
}
