package quack.fnf.phoenix.android;

import android.content.ContentResolver;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.Build;
import android.os.CancellationSignal;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract;
import android.provider.DocumentsProvider;
import android.util.Base64;
import android.webkit.MimeTypeMap;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * SAF view of the user-managed files Phoenix stores in its app-specific
 * external directory. It deliberately exposes only crash logs and mods,
 * rather than the whole app-private storage tree.
 *
 * The provider is accessed by Android's system DocumentsUI through SAF URI
 * grants; apps must not access it directly. See docs/ANDROID_PLATFORM.md.
 */
public final class PhoenixDocumentsProvider extends DocumentsProvider
{
	private static final String ROOT_MODS = "mods";
	private static final String ROOT_CRASH = "crash";
	private static final int DOCUMENT_ID_FLAGS = Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP;
	private static final String FALLBACK_MIME_TYPE = "application/octet-stream";
	// A filesystem path is bounded to 4096 bytes on Android/Linux. Base64 URL
	// encoding needs at most about 5462 characters; keep a little headroom but
	// reject arbitrarily large provider-supplied IDs before decoding them.
	private static final int MAX_ENCODED_RELATIVE_PATH_LENGTH = 6000;

	private static final String[] DEFAULT_ROOT_PROJECTION = {
		DocumentsContract.Root.COLUMN_ROOT_ID,
		DocumentsContract.Root.COLUMN_FLAGS,
		DocumentsContract.Root.COLUMN_ICON,
		DocumentsContract.Root.COLUMN_TITLE,
		DocumentsContract.Root.COLUMN_SUMMARY,
		DocumentsContract.Root.COLUMN_DOCUMENT_ID,
		DocumentsContract.Root.COLUMN_MIME_TYPES,
		DocumentsContract.Root.COLUMN_AVAILABLE_BYTES
	};

	private static final String[] DEFAULT_DOCUMENT_PROJECTION = {
		DocumentsContract.Document.COLUMN_DOCUMENT_ID,
		DocumentsContract.Document.COLUMN_DISPLAY_NAME,
		DocumentsContract.Document.COLUMN_MIME_TYPE,
		DocumentsContract.Document.COLUMN_FLAGS,
		DocumentsContract.Document.COLUMN_SIZE,
		DocumentsContract.Document.COLUMN_LAST_MODIFIED
	};

	private static final class RootInfo
	{
		final String id;
		final File directory;
		final String title;
		final String summary;
		final boolean writable;

		RootInfo(String id, File directory, String title, String summary, boolean writable)
		{
			this.id = id;
			this.directory = directory;
			this.title = title;
			this.summary = summary;
			this.writable = writable;
		}
	}

	private static final class DocumentInfo
	{
		final RootInfo root;
		final File file;
		final boolean rootDocument;

		DocumentInfo(RootInfo root, File file, boolean rootDocument)
		{
			this.root = root;
			this.file = file;
			this.rootDocument = rootDocument;
		}
	}

	private static final class PermissionTarget
	{
		final String documentId;
		final File file;

		PermissionTarget(String documentId, File file)
		{
			this.documentId = documentId;
			this.file = file;
		}
	}

	@Override public boolean onCreate()
	{
		return getContext() != null;
	}

	@Override public Cursor queryRoots(String[] projection)
	{
		MatrixCursor cursor = newCursor(projection, DEFAULT_ROOT_PROJECTION);
		File storageDirectory = getStorageDirectory();
		if (storageDirectory != null)
		{
			RootInfo[] roots = getRoots(storageDirectory);
			for (RootInfo root : roots)
			{
				// A missing root is valid (it is created on first SAF write),
				// but do not advertise a root replaced by a file or symlink.
				if (!isUsableRoot(root))
					continue;

				Map<String, Object> values = new HashMap<String, Object>();
				values.put(DocumentsContract.Root.COLUMN_ROOT_ID, root.id);
				values.put(DocumentsContract.Root.COLUMN_DOCUMENT_ID, root.id);
				values.put(DocumentsContract.Root.COLUMN_TITLE, root.title);
				values.put(DocumentsContract.Root.COLUMN_SUMMARY, root.summary);
				values.put(DocumentsContract.Root.COLUMN_FLAGS, getRootFlags(root));
				values.put(DocumentsContract.Root.COLUMN_MIME_TYPES, "*/*");
				values.put(DocumentsContract.Root.COLUMN_AVAILABLE_BYTES,
					root.writable ? Long.valueOf(storageDirectory.getUsableSpace()) : null);

				int icon = getContext().getApplicationInfo().icon;
				values.put(DocumentsContract.Root.COLUMN_ICON, icon == 0 ? null : Integer.valueOf(icon));
				addProjectedRow(cursor, values);
			}
		}

		setNotificationUri(cursor, DocumentsContract.buildRootsUri(getAuthority()));
		return cursor;
	}

	@Override public Cursor queryDocument(String documentId, String[] projection) throws FileNotFoundException
	{
		DocumentInfo document = resolveDocumentId(documentId);
		if (!isUsableRoot(document.root) || !isSafeFile(document.root, document.file)
			|| (!document.rootDocument && (!document.file.exists() || (!document.file.isDirectory() && !document.file.isFile())))
			|| (document.rootDocument && document.file.exists() && !document.file.isDirectory()))
			throw new FileNotFoundException("Document does not exist: " + documentId);

		MatrixCursor cursor = newCursor(projection, DEFAULT_DOCUMENT_PROJECTION);
		addDocumentRow(cursor, document);
		setNotificationUri(cursor, DocumentsContract.buildDocumentUri(getAuthority(), documentId));
		return cursor;
	}

	@Override public Cursor queryChildDocuments(String parentDocumentId, String[] projection, String sortOrder) throws FileNotFoundException
	{
		DocumentInfo parent = resolveDocumentId(parentDocumentId);
		if (!isUsableRoot(parent.root) || !isSafeFile(parent.root, parent.file)
			|| (!parent.rootDocument && (!parent.file.exists() || !parent.file.isDirectory()))
			|| (parent.rootDocument && parent.file.exists() && !parent.file.isDirectory()))
			throw new FileNotFoundException("Not a directory: " + parentDocumentId);

		MatrixCursor cursor = newCursor(projection, DEFAULT_DOCUMENT_PROJECTION);
		if (!parent.file.exists())
		{
			setNotificationUri(cursor, DocumentsContract.buildChildDocumentsUri(getAuthority(), parentDocumentId));
			return cursor;
		}

		File[] children;
		try
		{
			children = parent.file.listFiles();
		}
		catch (SecurityException e)
		{
			throw fileNotFound("Could not list directory: " + parentDocumentId, e);
		}
		if (children == null)
			throw new FileNotFoundException("Could not list directory: " + parentDocumentId);

		// The system UI may impose its own ordering. Return a predictable
		// directory-first order without interpreting an SQL sort string.
		Arrays.sort(children, new Comparator<File>()
		{
			@Override public int compare(File left, File right)
			{
				if (left.isDirectory() != right.isDirectory())
					return left.isDirectory() ? -1 : 1;
				return left.getName().compareToIgnoreCase(right.getName());
			}
		});

		for (File child : children)
		{
			if (!isSafeFile(parent.root, child) || (!child.isDirectory() && !child.isFile()))
				continue;
			addDocumentRow(cursor, new DocumentInfo(parent.root, child, false));
		}

		setNotificationUri(cursor, DocumentsContract.buildChildDocumentsUri(getAuthority(), parentDocumentId));
		return cursor;
	}

	@Override public ParcelFileDescriptor openDocument(String documentId, String mode, CancellationSignal signal) throws FileNotFoundException
	{
		if (signal != null)
			signal.throwIfCanceled();

		DocumentInfo document = resolveDocumentId(documentId);
		if (document.rootDocument || document.file.isDirectory() || !document.file.isFile())
			throw new FileNotFoundException("Document is not a regular file: " + documentId);

		boolean write = isWriteMode(mode);
		if (!"r".equals(mode) && !"w".equals(mode) && !"wt".equals(mode) && !"wa".equals(mode)
			&& !"rw".equals(mode) && !"rwt".equals(mode))
			throw new UnsupportedOperationException("Unsupported document mode: " + mode);
		if (write && !canWriteToRoot(document.root))
			throw new FileNotFoundException("This document is read-only: " + documentId);
		if (!document.file.exists())
			throw new FileNotFoundException("Document does not exist: " + documentId);

		File parent = document.file.getParentFile();
		if (parent == null || !isSafeFile(document.root, parent) || !parent.isDirectory())
			throw new FileNotFoundException("Document parent is unavailable: " + documentId);

		try
		{
			final int accessMode = ParcelFileDescriptor.parseMode(mode);
			// Recheck immediately before the path-based open. This closes the
			// ordinary stale-ID/symlink window, though java.io.File cannot make
			// check-and-open atomic against a concurrent filesystem writer.
			if (!isUsableRoot(document.root) || !isSafeFile(document.root, document.file)
				|| !document.file.isFile() || !isSafeFile(document.root, parent) || !parent.isDirectory())
				throw new FileNotFoundException("Document path changed before opening: " + documentId);
			if (!write)
				return ParcelFileDescriptor.open(document.file, accessMode);

			final String parentDocumentId = buildDocumentId(document.root, parent);
			final String changedDocumentId = documentId;
			return ParcelFileDescriptor.open(document.file, accessMode, new Handler(Looper.getMainLooper()),
				new ParcelFileDescriptor.OnCloseListener()
				{
					@Override public void onClose(IOException error)
					{
						notifyDocumentChanged(parentDocumentId, changedDocumentId);
					}
				});
		}
		catch (FileNotFoundException e)
		{
			throw e;
		}
		catch (IOException e)
		{
			throw fileNotFound("Could not open document: " + documentId, e);
		}
		catch (IllegalArgumentException e)
		{
			throw new UnsupportedOperationException("Unsupported document mode: " + mode, e);
		}
		catch (SecurityException e)
		{
			throw fileNotFound("Could not open document: " + documentId, e);
		}
	}

	@Override public String createDocument(String parentDocumentId, String mimeType, String displayName) throws FileNotFoundException
	{
		DocumentInfo parent = resolveDocumentId(parentDocumentId);
		if (!canWriteToRoot(parent.root))
			throw new FileNotFoundException("This root is read-only: " + parent.root.id);
		if (!PhoenixDocumentPathPolicy.isValidDisplayName(displayName))
			throw new FileNotFoundException("Invalid document name");

		boolean directory = DocumentsContract.Document.MIME_TYPE_DIR.equals(mimeType);
		boolean created;
		File child;
		try
		{
			if (!isUsableRoot(parent.root) || !isSafeFile(parent.root, parent.file))
				throw new FileNotFoundException("The document root or parent is unavailable: " + parentDocumentId);
			if ((!parent.rootDocument && (!parent.file.exists() || !parent.file.isDirectory()))
				|| (parent.rootDocument && parent.file.exists() && !parent.file.isDirectory()))
				throw new FileNotFoundException("Not a directory: " + parentDocumentId);

			if (!parent.file.exists() && !parent.file.mkdirs() && !parent.file.isDirectory())
				throw new FileNotFoundException("Could not create directory: " + parent.file);
			if (!isUsableRoot(parent.root) || !parent.file.isDirectory() || !isSafeFile(parent.root, parent.file))
				throw new FileNotFoundException("The document parent changed before creation: " + parentDocumentId);

			child = new File(parent.file, displayName);
			if (!isSafeFile(parent.root, child))
				throw new FileNotFoundException("Invalid document path");
			if (child.exists())
				throw new FileNotFoundException("A document with this name already exists: " + displayName);

			// createNewFile() is exclusive; mkdir() also fails rather than
			// replacing an existing entry created by another request.
			created = directory ? child.mkdir() : child.createNewFile();
		}
		catch (FileNotFoundException e)
		{
			throw e;
		}
		catch (IOException | SecurityException e)
		{
			throw fileNotFound("Could not create document: " + displayName, e);
		}

		if (!created)
			throw new FileNotFoundException("Could not create document: " + displayName);

		String childDocumentId = buildDocumentId(parent.root, child);
		notifyDocumentChanged(parentDocumentId, childDocumentId);
		return childDocumentId;
	}

	@Override public void deleteDocument(String documentId) throws FileNotFoundException
	{
		DocumentInfo document = resolveDocumentId(documentId);
		if (document.rootDocument || !canWriteToRoot(document.root))
			throw new FileNotFoundException("This document cannot be deleted: " + documentId);
		if (!isUsableRoot(document.root) || !document.file.exists()
			|| (!document.file.isDirectory() && !document.file.isFile()) || !isSafeFile(document.root, document.file))
			throw new FileNotFoundException("Document does not exist or is no longer safe: " + documentId);

		File parent = document.file.getParentFile();
		if (parent == null || !parent.isDirectory() || !isSafeFile(document.root, parent))
			throw new FileNotFoundException("Document parent is unavailable: " + documentId);
		final String parentDocumentId = buildDocumentId(document.root, parent);

		// Keep descendant grants until their entries are actually removed. If a
		// recursive delete is partial, revoke only IDs whose files disappeared.
		List<PermissionTarget> descendants = new ArrayList<PermissionTarget>();
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
		{
			descendants.add(new PermissionTarget(documentId, document.file));
			if (document.file.isDirectory())
				collectDescendantPermissions(document.root, document.file, descendants);
		}

		boolean deleted = false;
		try
		{
			// Revalidate immediately before recursively mutating the path.
			if (isUsableRoot(document.root) && isSafeFile(document.root, document.file)
				&& isSafeFile(document.root, parent))
				deleted = deleteRecursively(document.root, document.file);
		}
		catch (SecurityException e)
		{
			throw fileNotFound("Could not delete document: " + documentId, e);
		}
		finally
		{
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
				revokeDeletedDescendantPermissions(descendants);
			// Recursive deletion can fail after removing some children. Always
			// refresh the parent view, including on partial failure.
			notifyDocumentChanged(parentDocumentId, null);
			if (document.file.exists())
				notifyDocumentChanged(documentId, null);
		}

		if (!deleted)
			throw new FileNotFoundException("Could not delete document: " + documentId);
	}

	@Override public String renameDocument(String documentId, String displayName) throws FileNotFoundException
	{
		DocumentInfo document = resolveDocumentId(documentId);
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP)
			throw new UnsupportedOperationException("Renaming documents requires Android 5.0 or newer");
		if (document.rootDocument || !canWriteToRoot(document.root) || document.file.isDirectory()
			|| !PhoenixDocumentPathPolicy.isValidDisplayName(displayName))
			throw new FileNotFoundException("This document cannot be renamed: " + documentId);
		if (!isUsableRoot(document.root) || !document.file.isFile() || !isSafeFile(document.root, document.file))
			throw new FileNotFoundException("Document does not exist or is no longer safe: " + documentId);
		if (document.file.getName().equals(displayName))
			return null;

		File parent = document.file.getParentFile();
		if (parent == null || !parent.isDirectory() || !isSafeFile(document.root, parent))
			throw new FileNotFoundException("Document parent is unavailable: " + documentId);
		final String parentDocumentId = buildDocumentId(document.root, parent);
		File renamed = new File(parent, displayName);
		if (!PhoenixDocumentPathPolicy.isValidDisplayName(displayName)
			|| !isSafeFile(document.root, renamed) || renamed.exists())
			throw new FileNotFoundException("A document with this name already exists or the path is invalid");

		try
		{
			// Revalidate directly before rename; the java.io.File API cannot make
			// the no-overwrite check and rename atomic against concurrent writers.
			if (!isUsableRoot(document.root) || !isSafeFile(document.root, parent)
				|| !isSafeFile(document.root, document.file) || renamed.exists()
				|| !document.file.renameTo(renamed))
				throw new FileNotFoundException("Could not rename document: " + documentId);
		}
		catch (SecurityException e)
		{
			throw fileNotFound("Could not rename document: " + documentId, e);
		}

		String renamedDocumentId = buildDocumentId(document.root, renamed);
		notifyDocumentChanged(parentDocumentId, renamedDocumentId);
		return renamedDocumentId;
	}

	@Override public boolean isChildDocument(String parentDocumentId, String documentId)
	{
		try
		{
			DocumentInfo parent = resolveDocumentId(parentDocumentId);
			DocumentInfo child = resolveDocumentId(documentId);
			if (!parent.root.id.equals(child.root.id) || parent.file.equals(child.file)
				|| !child.file.exists() || (!parent.rootDocument && !parent.file.isDirectory()))
				return false;
			return PhoenixDocumentPathPolicy.isWithin(parent.file.getAbsolutePath(), child.file.getAbsolutePath());
		}
		catch (FileNotFoundException e)
		{
			return false;
		}
	}

	private File getStorageDirectory()
	{
		if (getContext() == null)
			return null;
		try
		{
			File directory = getContext().getExternalFilesDir(null);
			if (directory == null || !isStorageAvailable(directory))
				return null;
			return directory.getCanonicalFile();
		}
		catch (IOException | RuntimeException e)
		{
			return null;
		}
	}

	private RootInfo[] getRoots(File storageDirectory)
	{
		return new RootInfo[] {
			new RootInfo(ROOT_MODS, new File(storageDirectory, ROOT_MODS), "Mods", "User mods", true),
			new RootInfo(ROOT_CRASH, new File(storageDirectory, ROOT_CRASH), "Crash Logs", "Phoenix Engine crash reports", false)
		};
	}

	private int getRootFlags(RootInfo root)
	{
		int flags = 0;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
		{
			if (canWriteToRoot(root) && isWritableDirectory(root.directory))
				flags |= DocumentsContract.Root.FLAG_SUPPORTS_CREATE;
			flags |= DocumentsContract.Root.FLAG_SUPPORTS_IS_CHILD;
		}
		return flags;
	}

	private boolean isStorageAvailable(File path)
	{
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP)
			return false;
		try
		{
			String state = Environment.getExternalStorageState(path);
			return Environment.MEDIA_MOUNTED.equals(state)
				|| Environment.MEDIA_MOUNTED_READ_ONLY.equals(state);
		}
		catch (RuntimeException e)
		{
			return false;
		}
	}

	private boolean isStorageWritable(File path)
	{
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP)
			return false;
		try
		{
			return Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState(path));
		}
		catch (RuntimeException e)
		{
			return false;
		}
	}

	private boolean canWriteToRoot(RootInfo root)
	{
		return root.writable && isStorageWritable(root.directory);
	}

	private boolean isUsableRoot(RootInfo root)
	{
		return isStorageAvailable(root.directory) && isSafeFile(root, root.directory)
			&& (!root.directory.exists() || root.directory.isDirectory());
	}

	private static boolean isWritableDirectory(File directory)
	{
		if (directory.exists())
			return directory.isDirectory() && directory.canWrite();
		File parent = directory.getParentFile();
		return parent != null && parent.isDirectory() && parent.canWrite();
	}

	private DocumentInfo resolveDocumentId(String documentId) throws FileNotFoundException
	{
		if (documentId == null)
			throw new FileNotFoundException("Missing document ID");
		File storageDirectory = getStorageDirectory();
		if (storageDirectory == null)
			throw new FileNotFoundException("Phoenix storage is unavailable");

		for (RootInfo root : getRoots(storageDirectory))
		{
			if (root.id.equals(documentId))
			{
				if (!isUsableRoot(root))
					throw new FileNotFoundException("Invalid root directory: " + root.id);
				return new DocumentInfo(root, root.directory, true);
			}

			String prefix = root.id + ":";
			if (!documentId.startsWith(prefix))
				continue;
			if (!isUsableRoot(root))
				throw new FileNotFoundException("Invalid root directory: " + root.id);

			String encodedPath = documentId.substring(prefix.length());
			if (encodedPath.length() == 0 || encodedPath.length() > MAX_ENCODED_RELATIVE_PATH_LENGTH)
				throw new FileNotFoundException("Invalid document ID length");

			final String relativePath;
			try
			{
				relativePath = new String(Base64.decode(encodedPath, DOCUMENT_ID_FLAGS), StandardCharsets.UTF_8);
			}
			catch (IllegalArgumentException e)
			{
				throw fileNotFound("Invalid document ID: " + documentId, e);
			}

			if (!PhoenixDocumentPathPolicy.isSafeRelativePath(relativePath))
				throw new FileNotFoundException("Invalid document path: " + documentId);
			File file = new File(root.directory, relativePath);
			if (!isSafeFile(root, file))
				throw new FileNotFoundException("Document is outside its root: " + documentId);
			return new DocumentInfo(root, file, false);
		}

		throw new FileNotFoundException("Unknown document ID: " + documentId);
	}

	private boolean isSafeFile(RootInfo root, File file)
	{
		return PhoenixDocumentPathPolicy.isSafeFile(root.directory, file);
	}

	private String buildDocumentId(RootInfo root, File file) throws FileNotFoundException
	{
		if (!isSafeFile(root, file))
			throw new FileNotFoundException("Document is outside its root: " + file);
		String rootPath = root.directory.getAbsolutePath();
		String filePath = file.getAbsolutePath();
		if (rootPath.equals(filePath))
			return root.id;
		if (!PhoenixDocumentPathPolicy.isWithin(rootPath, filePath))
			throw new FileNotFoundException("Document is outside its root: " + file);

		String relativePath = filePath.substring(rootPath.length() + 1);
		if (!PhoenixDocumentPathPolicy.isSafeRelativePath(relativePath))
			throw new FileNotFoundException("Document has an invalid relative path: " + file);
		String encodedPath = Base64.encodeToString(relativePath.getBytes(StandardCharsets.UTF_8), DOCUMENT_ID_FLAGS);
		return root.id + ":" + encodedPath;
	}

	private void addDocumentRow(MatrixCursor cursor, DocumentInfo document) throws FileNotFoundException
	{
		boolean directory = document.rootDocument || document.file.isDirectory();
		String documentId = buildDocumentId(document.root, document.file);
		int flags = 0;
		if (canWriteToRoot(document.root))
		{
			File parent = document.file.getParentFile();
			boolean parentWritable = parent != null && parent.isDirectory() && parent.canWrite();
			if (directory)
			{
				if (isWritableDirectory(document.file))
					flags |= DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE;
				if (!document.rootDocument && parentWritable)
					flags |= DocumentsContract.Document.FLAG_SUPPORTS_DELETE;
			}
			else
			{
				if (document.file.canWrite())
					flags |= DocumentsContract.Document.FLAG_SUPPORTS_WRITE;
				if (parentWritable)
					flags |= DocumentsContract.Document.FLAG_SUPPORTS_DELETE;
			}

			// SAF rename support was added in API 21. Directory IDs are
			// path-based, so only files advertise rename (a directory rename
			// would otherwise invalidate every descendant ID).
			if (!directory && parentWritable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
				flags |= DocumentsContract.Document.FLAG_SUPPORTS_RENAME;
		}

		Map<String, Object> values = new HashMap<String, Object>();
		values.put(DocumentsContract.Document.COLUMN_DOCUMENT_ID, documentId);
		values.put(DocumentsContract.Document.COLUMN_DISPLAY_NAME,
			document.rootDocument ? document.root.title : document.file.getName());
		values.put(DocumentsContract.Document.COLUMN_MIME_TYPE,
			directory ? DocumentsContract.Document.MIME_TYPE_DIR : getMimeType(document.file));
		values.put(DocumentsContract.Document.COLUMN_FLAGS, Integer.valueOf(flags));
		values.put(DocumentsContract.Document.COLUMN_SIZE, directory ? null : Long.valueOf(document.file.length()));
		values.put(DocumentsContract.Document.COLUMN_LAST_MODIFIED, Long.valueOf(document.file.lastModified()));
		values.put(DocumentsContract.Document.COLUMN_SUMMARY, null);
		values.put(DocumentsContract.Document.COLUMN_ICON, null);
		addProjectedRow(cursor, values);
	}

	private static String getMimeType(File file)
	{
		String name = file.getName();
		int dot = name.lastIndexOf('.');
		if (dot >= 0 && dot < name.length() - 1)
		{
			String extension = name.substring(dot + 1).toLowerCase(java.util.Locale.ROOT);
			String mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
			if (mimeType != null)
				return mimeType;
		}
		return FALLBACK_MIME_TYPE;
	}

	private static boolean isWriteMode(String mode)
	{
		return mode != null && !"r".equals(mode);
	}

	private MatrixCursor newCursor(String[] projection, String[] defaultProjection)
	{
		return new MatrixCursor(projection == null ? defaultProjection : projection);
	}

	private static void addProjectedRow(MatrixCursor cursor, Map<String, Object> values)
	{
		String[] columns = cursor.getColumnNames();
		Object[] row = new Object[columns.length];
		for (int i = 0; i < columns.length; i++)
			row[i] = values.get(columns[i]);
		cursor.addRow(row);
	}

	private void setNotificationUri(Cursor cursor, Uri uri)
	{
		if (getContext() != null)
			cursor.setNotificationUri(getContext().getContentResolver(), uri);
	}

	private String getAuthority()
	{
		return getContext().getPackageName() + ".documentsprovider";
	}

	private void notifyDocumentChanged(String parentDocumentId, String changedDocumentId)
	{
		if (getContext() == null)
			return;
		ContentResolver resolver = getContext().getContentResolver();
		String authority = getAuthority();
		resolver.notifyChange(DocumentsContract.buildChildDocumentsUri(authority, parentDocumentId), null);
		resolver.notifyChange(DocumentsContract.buildDocumentUri(authority, parentDocumentId), null);
		if (changedDocumentId != null)
			resolver.notifyChange(DocumentsContract.buildDocumentUri(authority, changedDocumentId), null);
	}

	private void collectDescendantPermissions(RootInfo root, File directory, List<PermissionTarget> targets)
	{
		if (isSymbolicLink(directory) || !isSafeFile(root, directory))
			return;
		File[] children = directory.listFiles();
		if (children == null)
			return;
		for (File child : children)
		{
			// Symlinks are never exposed as documents and are never traversed.
			if (isSymbolicLink(child) || !isSafeFile(root, child)
				|| (!child.isDirectory() && !child.isFile()))
				continue;
			try
			{
				targets.add(new PermissionTarget(buildDocumentId(root, child), child));
			}
			catch (FileNotFoundException ignored) {}
			if (child.isDirectory())
				collectDescendantPermissions(root, child, targets);
		}
	}

	private void revokeDeletedDescendantPermissions(List<PermissionTarget> targets)
	{
		for (PermissionTarget target : targets)
		{
			if (target.file.exists())
				continue;
			try
			{
				revokeDocumentPermission(target.documentId);
			}
			catch (RuntimeException ignored) {}
		}
	}

	private boolean deleteRecursively(RootInfo root, File file)
	{
		// Delete the symlink itself, never its target. For ordinary paths, keep
		// validating every level instead of trusting an earlier parent check.
		if (isSymbolicLink(file))
			return file.delete();
		if (!isSafeFile(root, file))
			return false;

		if (file.isDirectory())
		{
			File[] children = file.listFiles();
			if (children == null)
				return false;
			for (File child : children)
			{
				if (!deleteRecursively(root, child))
					return false;
			}
		}
		return file.delete();
	}

	private static boolean isSymbolicLink(File file)
	{
		try
		{
			return !file.getAbsolutePath().equals(file.getCanonicalPath());
		}
		catch (IOException e)
		{
			return true;
		}
	}

	private static FileNotFoundException fileNotFound(String message, Throwable cause)
	{
		FileNotFoundException error = new FileNotFoundException(message);
		error.initCause(cause);
		return error;
	}
}
