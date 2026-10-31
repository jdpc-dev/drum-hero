package com.drum.hero.allfilesaccess;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;

public class AllFilesAccessPlugin extends GodotPlugin {

    public AllFilesAccessPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "AllFilesAccess";
    }

    private String lastError = "";

    @UsedByGodot
    public String getLastError() {
        return lastError;
    }

    @UsedByGodot
    public boolean hasAllFilesAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return Environment.isExternalStorageManager();
        }
        return true;
    }

    @UsedByGodot
    public boolean requestAllFilesAccess() {
        lastError = "";
        Activity activity = getActivity();
        if (activity == null) {
            lastError = "no_activity";
            return false;
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            // No special permission is needed: storage permissions were granted
            // at install time. Settings are still opened so the user can review
            // them.
            return openAllFilesSettings();
        }
        if (Environment.isExternalStorageManager()) {
            return true;
        }
        return openAllFilesSettings();
    }

    @UsedByGodot
    public boolean openAllFilesSettings() {
        lastError = "";
        Activity activity = getActivity();
        if (activity == null) {
            lastError = "no_activity";
            return false;
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            try {
                Intent appDetails = new Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:" + activity.getPackageName()));
                appDetails.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(appDetails);
                return true;
            } catch (Exception e) {
                lastError = "no_app_details_activity";
                return false;
            }
        }
        try {
            Intent intent = new Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:" + activity.getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
            return true;
        } catch (Exception e) {
            try {
                Intent all = new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
                all.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(all);
                return true;
            } catch (Exception e2) {
                lastError = "no_settings_activity";
                return false;
            }
        }
    }

    @UsedByGodot
    public boolean isPathReadable(String path) {
        if (path == null || path.isEmpty()) return false;
        try {
            File f = new File(path);
            return f.exists() && f.canRead();
        } catch (Exception e) {
            return false;
        }
    }

    @UsedByGodot
    public boolean isDirectory(String path) {
        if (path == null || path.isEmpty()) return false;
        try {
            return new File(path).isDirectory();
        } catch (Exception e) {
            return false;
        }
    }
}
