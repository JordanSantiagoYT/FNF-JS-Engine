package quack.fnf.phoenix.android;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.provider.OpenableColumns;
import android.util.Log;
import android.webkit.MimeTypeMap;

import androidx.core.content.FileProvider;

import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Storage Access Framework integration, content:// URI support and
 * intent-based sharing for the Phoenix Android platform layer.
 *
 * Picker results are delivered to the registered Haxe dispatcher as:
 *   handleStorageResult(requestCode, resultCode, uri, displayName, size, bytes)
 * where bytes is null unless the request was an open-document request.
 *
 * Part of the Phoenix Android platform layer. See docs/ANDROID_PLATFORM.md.
 */
public class PhoenixStorage extends Extension
{
	public static final String LOG_TAG = "PhoenixStorage";

	public static final int REQUEST_OPEN_DOCUMENT = 9101;
	public static final int REQUEST_CREATE_DOCUMENT = 9102;
	public static final int REQUEST_OPEN_DOCUMENT_TREE = 9103;

	private static HaxeObject storageCallback = null;

	/** Registers the Haxe object receiving handleStorageResult callbacks. */
	public static void registerStorageCallback(HaxeObject object)
	{
		storageCallback = object;
	}

	private static void deliverResult(int requestCode, int resultCode, Uri uri, byte[] bytes)
	{
		HaxeObject target = storageCallback;
		if (target == null)
			return;

		String uriString = uri != null ? uri.toString() : "";
		String name = uri != null ? getDisplayName(uriString) : "";
		long size = uri != null ? getUriSize(uriString) : 0L;

		try
		{
			Object[] args = new Object[6];
			args[0] = requestCode;
			args[1] = resultCode;
			args[2] = uriString;
			args[3] = name;
			args[4] = size;
			args[5] = bytes;
			target.call("handleStorageResult", args);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "deliverResult failed: " + e);
		}
	}

	@Override public boolean onActivityResult(int requestCode, int resultCode, Intent data)
	{
		if (requestCode != REQUEST_OPEN_DOCUMENT && requestCode != REQUEST_CREATE_DOCUMENT
			&& requestCode != REQUEST_OPEN_DOCUMENT_TREE)
		{
			// Not ours (e.g. Lime's own FileDialog request codes): leave the
			// result for the other extensions.
			return false;
		}

		Uri uri = (data != null) ? data.getData() : null;
		byte[] bytes = null;

		if (resultCode == Activity.RESULT_OK && uri != null)
		{
			// Persist access across reboots for document trees and picked files.
			try
			{
				int flags = Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION;
				mainContext.getContentResolver().takePersistableUriPermission(uri, flags);
			}
			catch (Exception ignored) {}

			if (requestCode == REQUEST_OPEN_DOCUMENT)
				bytes = readUriBytes(uri.toString());
		}

		deliverResult(requestCode, resultCode, uri, bytes);
		return true;
	}

	// ------------------------------------------------------------------
	// Storage Access Framework pickers
	// ------------------------------------------------------------------

	/** Opens ACTION_OPEN_DOCUMENT. mimeTypes is a comma separated list (or empty for any). */
	public static void openDocument(String mimeTypes, String title)
	{
		Activity activity = mainActivity;
		if (activity == null)
			return;

		try
		{
			Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
			intent.addCategory(Intent.CATEGORY_OPENABLE);
			applyMimeTypes(intent, mimeTypes);
			if (title != null && title.length() > 0)
				intent.putExtra(Intent.EXTRA_TITLE, title);
			activity.startActivityForResult(intent, REQUEST_OPEN_DOCUMENT);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "openDocument failed: " + e);
			deliverResult(REQUEST_OPEN_DOCUMENT, Activity.RESULT_CANCELED, null, null);
		}
	}

	/** Opens ACTION_CREATE_DOCUMENT with the suggested file name. */
	public static void createDocument(String mime, String suggestedName)
	{
		Activity activity = mainActivity;
		if (activity == null)
			return;

		try
		{
			Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
			intent.addCategory(Intent.CATEGORY_OPENABLE);
			intent.setType(mime != null && mime.length() > 0 ? mime : "application/octet-stream");
			if (suggestedName != null && suggestedName.length() > 0)
				intent.putExtra(Intent.EXTRA_TITLE, suggestedName);
			activity.startActivityForResult(intent, REQUEST_CREATE_DOCUMENT);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "createDocument failed: " + e);
			deliverResult(REQUEST_CREATE_DOCUMENT, Activity.RESULT_CANCELED, null, null);
		}
	}

	/** Opens ACTION_OPEN_DOCUMENT_TREE (directory picker). */
	public static void openDocumentTree()
	{
		Activity activity = mainActivity;
		if (activity == null)
			return;

		try
		{
			Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
			intent.addCategory(Intent.CATEGORY_DEFAULT);
			activity.startActivityForResult(intent, REQUEST_OPEN_DOCUMENT_TREE);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "openDocumentTree failed: " + e);
			deliverResult(REQUEST_OPEN_DOCUMENT_TREE, Activity.RESULT_CANCELED, null, null);
		}
	}

	private static void applyMimeTypes(Intent intent, String mimeTypes)
	{
		if (mimeTypes == null || mimeTypes.length() == 0)
		{
			intent.setType("*/*");
			return;
		}

		String[] types = mimeTypes.split(",");
		if (types.length == 1)
		{
			intent.setType(types[0].trim());
			return;
		}

		intent.setType("*/*");
		String[] cleaned = new String[types.length];
		for (int i = 0; i < types.length; i++)
			cleaned[i] = types[i].trim();
		intent.putExtra(Intent.EXTRA_MIME_TYPES, cleaned);
	}

	// ------------------------------------------------------------------
	// content:// URI helpers
	// ------------------------------------------------------------------

	public static byte[] readUriBytes(String uriString)
	{
		if (mainContext == null || uriString == null)
			return null;

		InputStream input = null;
		try
		{
			Uri uri = Uri.parse(uriString);
			input = mainContext.getContentResolver().openInputStream(uri);
			if (input == null)
				return null;

			java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream();
			byte[] buffer = new byte[64 * 1024];
			int read;
			while ((read = input.read(buffer)) != -1)
				output.write(buffer, 0, read);
			return output.toByteArray();
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "readUriBytes failed: " + e);
			return null;
		}
		finally
		{
			try
			{
				if (input != null)
					input.close();
			}
			catch (Exception ignored) {}
		}
	}

	public static boolean writeUriBytes(String uriString, byte[] data)
	{
		if (mainContext == null || uriString == null || data == null)
			return false;

		OutputStream output = null;
		try
		{
			Uri uri = Uri.parse(uriString);
			output = mainContext.getContentResolver().openOutputStream(uri, "wt");
			if (output == null)
				return false;
			output.write(data);
			return true;
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "writeUriBytes failed: " + e);
			return false;
		}
		finally
		{
			try
			{
				if (output != null)
					output.close();
			}
			catch (Exception ignored) {}
		}
	}

	public static String getDisplayName(String uriString)
	{
		if (mainContext == null || uriString == null)
			return "";

		// Plain file paths / file:// URIs: use the path directly.
		Uri uri;
		try
		{
			uri = Uri.parse(uriString);
		}
		catch (Exception e)
		{
			return "";
		}

		if (!"content".equals(uri.getScheme()))
		{
			String path = uri.getPath();
			if (path == null)
				path = uriString;
			int slash = path.lastIndexOf('/');
			return slash >= 0 ? path.substring(slash + 1) : path;
		}

		Cursor cursor = null;
		try
		{
			cursor = mainContext.getContentResolver().query(uri, null, null, null, null);
			if (cursor != null && cursor.moveToFirst())
			{
				int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
				if (index >= 0)
					return cursor.getString(index);
			}
		}
		catch (Exception ignored) {}
		finally
		{
			if (cursor != null)
				cursor.close();
		}

		String lastSegment = uri.getLastPathSegment();
		return lastSegment == null ? "" : lastSegment;
	}

	public static long getUriSize(String uriString)
	{
		if (mainContext == null || uriString == null)
			return -1;

		try
		{
			Uri uri = Uri.parse(uriString);
			if (!"content".equals(uri.getScheme()))
			{
				File file = new File(uri.getPath() == null ? uriString : uri.getPath());
				return file.exists() ? file.length() : -1;
			}

			Cursor cursor = null;
			try
			{
				cursor = mainContext.getContentResolver().query(uri, null, null, null, null);
				if (cursor != null && cursor.moveToFirst())
				{
					int index = cursor.getColumnIndex(OpenableColumns.SIZE);
					if (index >= 0 && !cursor.isNull(index))
						return cursor.getLong(index);
				}
			}
			finally
			{
				if (cursor != null)
					cursor.close();
			}
		}
		catch (Exception ignored) {}
		return -1;
	}

	/** Copies a content:// URI to a filesystem path. Returns true on success. */
	public static boolean copyUriToFile(String uriString, String destinationPath)
	{
		byte[] data = readUriBytes(uriString);
		if (data == null)
			return false;

		try
		{
			File destination = new File(destinationPath);
			File parent = destination.getParentFile();
			if (parent != null && !parent.exists())
				parent.mkdirs();

			try (FileOutputStream output = new FileOutputStream(destination))
			{
				output.write(data);
			}
			return true;
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "copyUriToFile failed: " + e);
			return false;
		}
	}

	public static void persistUriPermission(String uriString, boolean writable)
	{
		if (mainContext == null || uriString == null)
			return;

		try
		{
			int flags = Intent.FLAG_GRANT_READ_URI_PERMISSION;
			if (writable)
				flags |= Intent.FLAG_GRANT_WRITE_URI_PERMISSION;
			mainContext.getContentResolver().takePersistableUriPermission(Uri.parse(uriString), flags);
		}
		catch (Exception ignored) {}
	}

	// ------------------------------------------------------------------
	// Intents: sharing, opening URLs / files / settings
	// ------------------------------------------------------------------

	private static Uri getShareableUri(File file)
	{
		if (mainContext == null)
			return null;

		try
		{
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)
			{
				return FileProvider.getUriForFile(mainContext, mainContext.getPackageName() + ".fileprovider", file);
			}
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "FileProvider failed, falling back to file:// URI: " + e);
		}
		return Uri.fromFile(file);
	}

	/** Shares a file through Android's share sheet (ACTION_SEND). */
	public static void shareFile(String path, String mime, String title)
	{
		if (mainContext == null || path == null)
			return;

		try
		{
			File file = new File(path);
			if (!file.exists())
			{
				Log.e(LOG_TAG, "shareFile: file does not exist: " + path);
				return;
			}

			Uri uri = getShareableUri(file);
			if (uri == null)
				return;

			String resolvedMime = mime;
			if (resolvedMime == null || resolvedMime.length() == 0)
			{
				String extension = MimeTypeMap.getFileExtensionFromUrl(uri.toString());
				resolvedMime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
				if (resolvedMime == null)
					resolvedMime = "application/octet-stream";
			}

			Intent intent = new Intent(Intent.ACTION_SEND);
			intent.setType(resolvedMime);
			intent.putExtra(Intent.EXTRA_STREAM, uri);
			intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

			Intent chooser = Intent.createChooser(intent, title != null && title.length() > 0 ? title : "Share via");
			chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			mainContext.startActivity(chooser);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "shareFile failed: " + e);
		}
	}

	/** Shares plain text through Android's share sheet. */
	public static void shareText(String text, String title)
	{
		if (mainContext == null || text == null)
			return;

		try
		{
			Intent intent = new Intent(Intent.ACTION_SEND);
			intent.setType("text/plain");
			intent.putExtra(Intent.EXTRA_TEXT, text);

			Intent chooser = Intent.createChooser(intent, title != null && title.length() > 0 ? title : "Share via");
			chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			mainContext.startActivity(chooser);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "shareText failed: " + e);
		}
	}

	/** Opens a URL in the system browser. */
	public static void openUrl(String url)
	{
		if (mainContext == null || url == null)
			return;

		try
		{
			Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			mainContext.startActivity(intent);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "openUrl failed: " + e);
		}
	}

	/**
	 * Opens a Settings screen by action name (e.g. "APPLICATION_DETAILS_SETTINGS",
	 * "WIFI_SETTINGS"), falling back to the main Settings page.
	 */
	public static void openSettings(String action)
	{
		if (mainContext == null)
			return;

		try
		{
			String resolved = action;
			if (resolved == null || resolved.length() == 0)
				resolved = "android.settings.SETTINGS";
			else if (!resolved.startsWith("android."))
				resolved = "android.settings." + resolved;

			Intent intent = new Intent(resolved);
			if (resolved.contains("APPLICATION_DETAILS"))
				intent.setData(Uri.parse("package:" + mainContext.getPackageName()));
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			mainContext.startActivity(intent);
		}
		catch (Exception e)
		{
			try
			{
				Intent fallback = new Intent(android.provider.Settings.ACTION_SETTINGS);
				fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				mainContext.startActivity(fallback);
			}
			catch (Exception ignored) {}
		}
	}

	/** Opens a local file with the app registered for its type (ACTION_VIEW). */
	public static void openFile(String path)
	{
		if (mainContext == null || path == null)
			return;

		try
		{
			File file = new File(path);
			if (!file.exists())
				return;

			String extension = path.substring(path.lastIndexOf('.') + 1).toLowerCase();
			String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
			if (mime == null)
				mime = "application/octet-stream";

			Uri uri = getShareableUri(file);
			if (uri == null)
				return;

			Intent intent = new Intent(Intent.ACTION_VIEW);
			intent.setDataAndType(uri, mime);
			intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
			mainContext.startActivity(intent);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "openFile failed: " + e);
		}
	}

	/** Returns true when the system can resolve an ACTION_VIEW intent for this content URI. */
	public static boolean canOpenContentUri(String uriString, String mime)
	{
		if (mainContext == null || uriString == null)
			return false;

		try
		{
			Intent intent = new Intent(Intent.ACTION_VIEW);
			intent.setDataAndType(Uri.parse(uriString), mime == null ? "*/*" : mime);
			return mainContext.getPackageManager().queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY).size() > 0;
		}
		catch (Exception e)
		{
			return false;
		}
	}

	/** Opens a content:// URI with an external app (ACTION_VIEW). */
	public static void viewContentUri(String uriString, String mime)
	{
		if (mainContext == null || uriString == null)
			return;

		try
		{
			Intent intent = new Intent(Intent.ACTION_VIEW);
			intent.setDataAndType(Uri.parse(uriString), mime == null ? "*/*" : mime);
			intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
			mainContext.startActivity(intent);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "viewContentUri failed: " + e);
		}
	}
}
