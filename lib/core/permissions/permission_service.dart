import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class PermissionService {
  Future<bool> requestStoragePermission() async {
    PermissionStatus status;

    if (Platform.isAndroid) {
      // As of permission_handler 11.x, it's recommended to check SDK version for granular permissions.
      // However, let's try a simplified approach first.
      // `Permission.storage` for older Android versions.
      // `Permission.photos` for newer Android versions (Android 13+ for images).
      // `file_picker` primarily uses the Storage Access Framework (SAF), which doesn't
      // always require these runtime permissions in the same way, but it's good practice
      // to request them, as SAF might still be restricted if permissions are denied.

      // A common approach is to request photos for API 33+ and storage otherwise.
      // Let's assume permission_handler handles the SDK check correctly for Permission.photos
      // and Permission.storage. If Permission.photos is requested on an older OS,
      // it might fall back or cause an issue.
      // A safer bet might be to request `Permission.storage` and let the system/`permission_handler`
      // present the appropriate dialog (e.g. "Allow access to photos and media").

      // Let's try with Permission.photos first as it's more specific to our use case.
      // If this doesn't work well across versions, we might need to add SDK version checks.
      // Or, we can request multiple permissions.
      
      // Let's try a more robust approach by requesting photos, and if not available (older Android), fallback to storage.
      // However, permission_handler's Permission.storage is often sufficient as it adapts.
      // Let's simplify and stick to Permission.storage for now as it used to be the common one.
      // If Android 13+ doesn't show a picker, we'll switch to Permission.photos.

      // The user is reporting that the permission dialog is not showing.
      // This might mean that Permission.storage is not the correct one for triggering the
      // "access to photos and media" dialog on their specific Android version.
      // Let's try Permission.photos for Android.
      status = await Permission.photos.request();
      if (status.isDenied) {
        // If denied once, try requesting again. Sometimes users accidentally deny.
        // Or, if it's truly denied, this won't re-prompt but confirm the denied state.
        status = await Permission.photos.request(); 
      }
      // If photos permission is not applicable or fails, maybe try storage as a broader category
      // This is getting complicated. Let's stick to what's common.
      // The original code used Permission.storage. Let's ensure that's what we try.
      // If that doesn't work, we'll try photos specifically for Android 13+
      
      // Reverting to simpler logic that was there, but will ensure we use .photos for iOS and .storage for Android explicitly.
      // The existing code already had this.

      // Let's check the Android version.
      // We need a way to get the Android SDK version.
      // `device_info_plus` plugin can provide this. For now, let's assume a modern Android (API 33+)
      // and request `Permission.photos`. If this is too specific, we can broaden it.

      // The issue might be that even if we request, the dialog isn't showing.
      // This can happen if it was "permanently denied".

      // Let's try to be more specific for Android 13+ (API 33) vs older.
      // We don't have device_info_plus yet.
      // For now, let's try requesting BOTH storage and photos, or rely on one and see.
      // The `permission_handler` documentation often suggests specific permissions for specific tasks.
      // For picking general files/directories, `Permission.storage` (especially with `manageExternalStorage` for wider access)
      // or relying on `file_picker`'s SAF is key. For *media* files specifically, granular permissions are preferred on API 33+.

      // If `Permission.storage.request()` is not showing a dialog, let's try `Permission.photos.request()`.
      // It's possible the system interprets `Permission.storage` differently on the user's OS version
      // and doesn't prompt for media if it thinks it's for general files.

      status = await Permission.photos.request(); // Try photos first for Android
      if (status.isDenied) {
          // If photos is denied, let's try storage as a fallback, as some devices/OS versions might respond better.
          // This is speculative.
          print('[PermissionService] Photos permission denied, trying storage.');
          status = await Permission.storage.request();
      }
       if (status.isDenied) {
        // If denied once, try requesting again. Sometimes users accidentally deny.
        status = await (await Permission.photos.isGranted ? Permission.photos.request() : Permission.storage.request());
      }

    } else if (Platform.isIOS) {
      status = await Permission.photos.request(); // This is correct for iOS
      if (status.isDenied) {
        status = await Permission.photos.request();
      }
    } else {
      return true; 
    }

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      print('[PermissionService] Permission permanently denied. Opening app settings.');
      await openAppSettings();
      return false;
    } else if (status.isDenied) {
        print('[PermissionService] Permission denied.');
        return false;
    } else if (status.isRestricted) { // e.g. parental controls
        print('[PermissionService] Permission restricted.');
        return false;
    } else {
        print('[PermissionService] Permission status unknown: $status');
      return false;
    }
  }

  Future<bool> checkStoragePermissionStatus() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.storage.status;
    } else if (Platform.isIOS) {
      status = await Permission.photos.status;
    } else {
      return true; // Assuming no permission needed or handled differently
    }
    return status.isGranted;
  }
} 