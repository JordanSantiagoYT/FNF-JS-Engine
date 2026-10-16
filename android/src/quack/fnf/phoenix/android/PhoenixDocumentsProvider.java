package quack.fnf.phoenix.android;

import android.content.ContentResolver;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.Build;
import android.os.CancellationSignal;
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
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
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
		if ((!document.rootDocument && !document.file.exists())
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
		if ((!parent.rootDocument && (!parent.file.exists() || !parent.file.isDirectory()))
			|| (parent.rootDocument && parent.file.exists() && !parent.file.isDirectory()))
			throw new FileNotFoundException("Not a directory: " + parentDocumentId);

		MatrixCursor cursor = newCursor(projection, DEFAULT_DOCUMENT_PROJECTION);
		if (!parent.file.exists())
		{
			setNotificationUri(cursor, DocumentsContract.buildChildDocumentsUri(getAuthority(), parentDocumentId));
			return cursor;
		}

		File[] children = parent.file.listFiles();
		if (children != null)
		{
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
				if (!isSafeFile(parent.root, child))
					continue;
				addDocumentRow(cursor, new DocumentInfo(parent.root, child, false));
			}
		}

		setNotificationUri(cursor, DocumentsContract.buildChildDocumentsUri(getAuthority(), parentDocumentId));
		return cursor;
	}

	@Override public ParcelFileDescriptor openDocument(String documentId, String mode, CancellationSignal signal) throws FileNotFoundException
	{
		if (signal != null)
			signal.throwIfCanceled();

		DocumentInfo document = resolveDocumentId(documentId);
		if (document.rootDocument || document.file.isDirectory())
			throw new FileNotFoundException("Directories cannot be opened as files: " + documentId);

		boolean write = isWriteMode(mode);
		if (!"r".equals(mode) && !"w".equals(mode) && !"wt".equals(mode) && !"wa".equals(mode)
			&& !"rw".equals(mode) && !"rwt".equals(mode))
			throw new UnsupportedOperationException("Unsupported document mode: " + mode);
		if (write && !document.root.writable)
			throw new FileNotFoundException("This document is read-only: " + documentId);
		if (!document.file.exists())
			throw new FileNotFoundException("Document does not exist: " + documentId);

		File parent = document.file.getParentFile();
		if (parent == null || !isSafeFile(document.root, parent) || !parent.isDirectory())
			throw new FileNotFoundException("Document parent is unavailable: " + documentId);

		try
		{
			final int accessMode = ParcelFileDescriptor.parseMode(mode);
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
		catch (IllegalArgumentException e)
		{
			throw new UnsupportedOperationException("Unsupported document mode: " + mode, e);
		}
	}

	@Override public String createDocument(String parentDocumentId, String mimeType, String displayName) throws FileNotFoundException
	{
		DocumentInfo parent = resolveDocumentId(parentDocumentId);
		if (!parent.root.writable)
			throw new FileNotFoundException("This root is read-only: " + parent.root.id);
		if ((!parent.rootDocument && (!parent.file.exists() || !parent.file.isDirectory()))
			|| (parent.rootDocument && parent.file.exists() && !parent.file.isDirectory()))
			throw new FileNotFoundException("Not a directory: " + parentDocumentId);
		if (!isValidDisplayName(displayName))
			throw new FileNotFoundException("Invalid document name");

		if (!parent.file.exists() && !parent.file.mkdirs())
			throw new FileNotFoundException("Could not create directory: " + parent.file);

		File child = new File(parent.file, displayName);
		if (!isSafeFile(parent.root, child))
			throw new FileNotFoundException("Invalid document path");
		if (child.exists())
			throw new FileNotFoundException("A document with this name already exists: " + displayName);

		boolean directory = DocumentsContract.Document.MIME_TYPE_DIR.equals(mimeType);
		boolean created;
		if (directory)
			created = child.mkdir();
		else
		{
			try
			{
				created = child.createNewFile();
			}
			catch (IOException e)
			{
				throw fileNotFound("Could not create document: " + displayName, e);
			}
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
		if (document.rootDocument || !document.root.writable)
			throw new FileNotFoundException("This document cannot be deleted: " + documentId);
		if (!document.file.exists())
			throw new FileNotFoundException("Document does not exist: " + documentId);

		File parent = document.file.getParentFile();
		if (parent == null)
			throw new FileNotFoundException("Document has no parent: " + documentId);

		// The base class revokes the selected document's grant after this
		// method returns. Descendants deleted with a directory need explicit
		// revocation as well.
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && document.file.isDirectory())
			revokeDescendantPermissions(document.root, document.file);

		if (!deleteRecursively(document.file))
			throw new FileNotFoundException("Could not delete document: " + documentId);

		notifyDocumentChanged(buildDocumentId(document.root, parent), null);
	}

	@Override public String renameDocument(String documentId, String displayName) throws FileNotFoundException
	{
		DocumentInfo document = resolveDocumentId(documentId);
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP)
			throw new UnsupportedOperationException("Renaming documents requires Android 5.0 or newer");
		if (document.rootDocument || !document.root.writable || document.file.isDirectory() || !isValidDisplayName(displayName))
			throw new FileNotFoundException("This document cannot be renamed: " + documentId);
		if (!document.file.exists())
			throw new FileNotFoundException("Document does not exist: " + documentId);
		if (document.file.getName().equals(displayName))
			return null;

		File parent = document.file.getParentFile();
		if (parent == null || !isSafeFile(document.root, parent))
			throw new FileNotFoundException("Document parent is unavailable: " + documentId);
		File renamed = new File(parent, displayName);
		if (!isSafeFile(document.root, renamed) || renamed.exists())
			throw new FileNotFoundException("A document with this name already exists or the path is invalid");
		if (!document.file.renameTo(renamed))
			throw new FileNotFoundException("Could not rename document: " + documentId);

		String renamedDocumentId = buildDocumentId(document.root, renamed);
		notifyDocumentChanged(buildDocumentId(document.root, parent), renamedDocumentId);
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
			return child.file.getAbsolutePath().startsWith(parent.file.getAbsolutePath() + File.separator);
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
			return directory == null ? null : directory.getCanonicalFile();
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
		int flags = root.writable ? DocumentsContract.Root.FLAG_SUPPORTS_CREATE : 0;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
			flags |= DocumentsContract.Root.FLAG_SUPPORTS_IS_CHILD;
		return flags;
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
				if (!isSafeFile(root, root.directory))
					throw new FileNotFoundException("Invalid root directory: " + root.id);
				return new DocumentInfo(root, root.directory, true);
			}

			String prefix = root.id + ":";
			if (!documentId.startsWith(prefix))
				continue;

			String encodedPath = documentId.substring(prefix.length());
			if (encodedPath.length() == 0)
				throw new FileNotFoundException("Invalid document ID: " + documentId);

			final String relativePath;
			try
			{
				relativePath = new String(Base64.decode(encodedPath, DOCUMENT_ID_FLAGS), StandardCharsets.UTF_8);
			}
			catch (IllegalArgumentException e)
			{
				throw fileNotFound("Invalid document ID: " + documentId, e);
			}

			if (!isSafeRelativePath(relativePath))
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
		try
		{
			String rootPath = root.directory.getCanonicalPath();
			String rootAbsolutePath = root.directory.getAbsolutePath();
			String absolutePath = file.getAbsolutePath();
			String canonicalPath = file.getCanonicalPath();

			// IDs are relative paths, but reject traversal and symbolic links so
			// a crafted document ID cannot escape either exported directory.
			if (!isWithin(rootPath, absolutePath) || !isWithin(rootPath, canonicalPath)
				|| !absolutePath.equals(canonicalPath) || !isWithin(rootAbsolutePath, absolutePath))
				return false;
			if (!rootAbsolutePath.equals(absolutePath)
				&& !isSafeRelativePath(absolutePath.substring(rootAbsolutePath.length() + 1)))
				return false;
			return true;
		}
		catch (IOException e)
		{
			return false;
		}
	}

	private static boolean isWithin(String rootPath, String path)
	{
		return path.equals(rootPath) || path.startsWith(rootPath + File.separator);
	}

	private static boolean isSafeRelativePath(String path)
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

	private static boolean isValidDisplayName(String name)
	{
		return name != null && name.length() > 0 && !".".equals(name) && !"..".equals(name)
			&& name.indexOf('/') < 0 && name.indexOf('\\') < 0 && name.indexOf('\0') < 0;
	}

	private String buildDocumentId(RootInfo root, File file) throws FileNotFoundException
	{
		if (!isSafeFile(root, file))
			throw new FileNotFoundException("Document is outside its root: " + file);
		String rootPath = root.directory.getAbsolutePath();
		String filePath = file.getAbsolutePath();
		if (rootPath.equals(filePath))
			return root.id;
		if (!filePath.startsWith(rootPath + File.separator))
			throw new FileNotFoundException("Document is outside its root: " + file);

		String relativePath = filePath.substring(rootPath.length() + 1);
		String encodedPath = Base64.encodeToString(relativePath.getBytes(StandardCharsets.UTF_8), DOCUMENT_ID_FLAGS);
		return root.id + ":" + encodedPath;
	}

	private void addDocumentRow(MatrixCursor cursor, DocumentInfo document) throws FileNotFoundException
	{
		boolean directory = document.rootDocument || document.file.isDirectory();
		String documentId = buildDocumentId(document.root, document.file);
		int flags = 0;
		if (document.root.writable)
		{
			if (directory)
			{
				flags |= DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE;
				if (!document.rootDocument)
					flags |= DocumentsContract.Document.FLAG_SUPPORTS_DELETE;
			}
			else
			{
				flags |= DocumentsContract.Document.FLAG_SUPPORTS_WRITE | DocumentsContract.Document.FLAG_SUPPORTS_DELETE;
			}

			// SAF rename support was added in API 21. Directory IDs are
			// path-based, so only files advertise rename (a directory rename
			// would otherwise invalidate every descendant ID).
			if (!directory && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
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

	private void revokeDescendantPermissions(RootInfo root, File directory)
	{
		if (isSymbolicLink(directory))
			return;
		File[] children = directory.listFiles();
		if (children == null)
			return;
		for (File child : children)
		{
			if (!isSafeFile(root, child))
				continue;
			try
			{
				revokeDocumentPermission(buildDocumentId(root, child));
			}
			catch (FileNotFoundException ignored) {}
			if (child.isDirectory())
				revokeDescendantPermissions(root, child);
		}
	}

	private static boolean deleteRecursively(File file)
	{
		if (isSymbolicLink(file))
			return file.delete();

		if (file.isDirectory())
		{
			File[] children = file.listFiles();
			if (children == null)
				return false;
			for (File child : children)
			{
				if (!deleteRecursively(child))
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
