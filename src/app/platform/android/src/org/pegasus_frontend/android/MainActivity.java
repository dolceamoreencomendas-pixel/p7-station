// Pegasus Frontend
// Copyright (C) 2017-2021  Mátyás Mustoha
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.


package org.pegasus_frontend.android;

import android.app.ActivityManager;
import android.content.Context;
import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.os.Bundle;
import android.content.IntentFilter;
import android.content.UriPermission;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Environment;
import android.os.storage.StorageManager;
import android.os.storage.StorageVolume;
import android.provider.Settings;
import androidx.core.content.FileProvider;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedList;
import java.util.List;


public class MainActivity extends org.qtproject.qt5.android.bindings.QtActivity {
    private static Activity m_self;
    private static PackageManager m_pm;
    private static int m_icon_density;


    @Override
    protected void onStart() {
        super.onStart();
        m_self = this;
        m_pm = getPackageManager();

        ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        m_icon_density = am.getLauncherLargeIconDensity();
    }


    public static App[] appList() {
        Intent intent = new Intent(Intent.ACTION_MAIN, null);
        intent.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> activities = m_pm.queryIntentActivities(intent, 0);

        App[] entries = new App[activities.size()];
        for (int i = 0; i < activities.size(); i++)
            entries[i] = new App(m_pm, activities.get(i));

        return entries;
    }


    public static byte[] appIcon(String packageName) {
        Drawable drawable = null;
        try {
            // NOTE: while there is m_pm.getApplicationInfo(), unfortunately
            //       that returns low density images for most apps
            ApplicationInfo appinfo = m_pm.getApplicationInfo(packageName, 0);
            Resources resources = m_pm.getResourcesForApplication(appinfo);
            Intent launch_intent = m_pm.getLaunchIntentForPackage(packageName);
            ResolveInfo resolveinfo = m_pm.resolveActivity(launch_intent, 0);
            // NOTE: getDrawableForDensity() has changed in API 21-22
            drawable = resources.getDrawableForDensity(resolveinfo.activityInfo.getIconResource(), m_icon_density);
        }
        catch (Exception ex) { }
        if (drawable == null)
            drawable = m_pm.getDefaultActivityIcon();

        Bitmap bitmap = drawableToBitmap(drawable);
        ByteArrayOutputStream stream = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
        return stream.toByteArray();
    }


    private static Bitmap drawableToBitmap(Drawable drawable) {
        if (drawable instanceof BitmapDrawable) {
            // TODO: handle null
            return ((BitmapDrawable) drawable).getBitmap();
        }

        int w = Math.max(1, drawable.getIntrinsicWidth());
        int h = Math.max(1, drawable.getIntrinsicHeight());
        Bitmap bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);

        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
        drawable.draw(canvas);
        return bitmap;
    }


    public static String primaryStoragePath() {
        final File storage = Environment.getExternalStorageDirectory();
        return storage.getAbsolutePath();
    }


    public static String[] sdcardPaths() {
        // Functions with high API level dependencies:
        // - https://developer.android.com/reference/android/os/storage/StorageManager#getStorageVolumes()
        // - https://developer.android.com/reference/android/os/storage/StorageVolume#getDirectory()

        final StorageManager storage_man = (StorageManager) m_self.getSystemService(Context.STORAGE_SERVICE);

        List<StorageVolume> storage_vols = null;
        if (Build.VERSION.SDK_INT >= 24) {
            storage_vols = storage_man.getStorageVolumes();
        }
        else {
            try {
                final Method volumelist_getter = StorageManager.class.getMethod("getVolumeList");
                final StorageVolume[] storage_vols_arr = (StorageVolume[]) volumelist_getter.invoke(storage_man);
                storage_vols = Arrays.asList(storage_vols_arr);
            } catch (IllegalAccessException e) {
                e.printStackTrace();
            } catch (InvocationTargetException e) {
                e.printStackTrace();
            } catch (NoSuchMethodException e) {
                e.printStackTrace();
            }
        }

        List<File> mount_points = new ArrayList<File>();
        if (Build.VERSION.SDK_INT >= 30) {
            for (StorageVolume sv : storage_vols)
                mount_points.add(sv.getDirectory());
        }
        else {
            try {
                final Method dir_getter = StorageVolume.class.getMethod("getPathFile");
                for (StorageVolume sv : storage_vols) {
                    final File mount_point = (File) dir_getter.invoke(sv);
                    mount_points.add(mount_point);
                }
            } catch (IllegalAccessException e) {
                e.printStackTrace();
            } catch (InvocationTargetException e) {
                e.printStackTrace();
            } catch (NoSuchMethodException e) {
                e.printStackTrace();
            }
        }

        List<String> paths = new ArrayList<String>();
        for (File mp : mount_points) {
            if (mp != null)
                paths.add(mp.getAbsolutePath());
        }
        paths.add("/"); // Always add the root
        return paths.toArray(new String[paths.size()]);
    }


    public static String[] grantedPaths() {
        List<String> paths = new ArrayList();
        for (UriPermission uriperm : m_self.getContentResolver().getPersistedUriPermissions()) {
            final Uri uri = uriperm.getUri();
            paths.add(uri.getPath());
        }
        return paths.toArray(new String[paths.size()]);
    }


    public static void rememberGrantedPath(Uri uri) {
        m_self
            .getContentResolver()
            .takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
    }


    // P7 Station: emuladores de Switch da família yuzu (Eden, Citron, Nyushu e outros que
    // aparecerem). Todos têm a tela de jogo em <algo>_emu.activities.EmulationActivity; é por ela
    // que o app acha cada um, sem precisar conhecer o nome do pacote de antemão.
    // Uma linha por app: pacote \t classe da tela de jogo \t nome do app \t última atualização (ms)
    private static final java.util.HashMap<String, String> s_forkCache = new java.util.HashMap<>();
    private static final java.util.regex.Pattern FORK_ACTIVITY =
        java.util.regex.Pattern.compile("^[\\w.]+_emu\\.activities\\.EmulationActivity$");

    public static String switchEmulators() {
        StringBuilder out = new StringBuilder();
        try {
            PackageManager pm = m_self.getPackageManager();
            for (PackageInfo info : pm.getInstalledPackages(0)) {
                if (info.applicationInfo == null
                    || (info.applicationInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0)
                    continue;
                String key = info.packageName + "@" + info.lastUpdateTime;
                String found = s_forkCache.get(key);
                if (found == null) {
                    found = "";
                    try {
                        PackageInfo full = pm.getPackageInfo(info.packageName, PackageManager.GET_ACTIVITIES);
                        if (full.activities != null) {
                            for (android.content.pm.ActivityInfo a : full.activities) {
                                if (a.name != null && FORK_ACTIVITY.matcher(a.name).matches()) { found = a.name; break; }
                            }
                        }
                    }
                    catch (Exception e) {
                        android.util.Log.w("P7", "switchEmulators " + info.packageName + ": " + e);
                    }
                    s_forkCache.put(key, found);
                }
                if (found.isEmpty())
                    continue;
                String label = String.valueOf(pm.getApplicationLabel(info.applicationInfo)).replace('\t', ' ').replace('\n', ' ');
                out.append(info.packageName).append('\t').append(found).append('\t')
                   .append(label).append('\t').append(info.lastUpdateTime).append('\n');
            }
        }
        catch (Exception e) {
            android.util.Log.w("P7", "switchEmulators: " + e);
        }
        return out.toString();
    }

    // P7 Station: só consulta, sem abrir a tela de configurações de novo
    // P7 Station: pacotes instalados, um por linha (para achar os emuladores)
    public static String installedPackages() {
        StringBuilder out = new StringBuilder();
        try {
            List<PackageInfo> list = m_self.getPackageManager().getInstalledPackages(0);
            for (PackageInfo info : list)
                out.append(info.packageName).append('\n');
        }
        catch (Exception e) {
            android.util.Log.w("P7", "installedPackages: " + e);
        }
        return out.toString();
    }

    // P7 Station: controles conectados, um por linha: nome \t tem bateria (1/0) \t carga 0..1 (ou -1) \t estado
    // estado: 0 desconhecido, 2 carregando, 3 descarregando, 4 sem carregar, 5 cheio (BatteryState do Android 12+).
    // A bateria só vem quando o próprio Android a informa (driver do controle); nada é estimado aqui.
    public static String controllers() {
        StringBuilder out = new StringBuilder();
        try {
            for (int id : android.view.InputDevice.getDeviceIds()) {
                android.view.InputDevice dev = android.view.InputDevice.getDevice(id);
                if (dev == null || dev.isVirtual())
                    continue;
                // só controles ligados ao tablet (Bluetooth/USB): fica de fora o que é do próprio
                // aparelho, como o "uinput-xiaomi" e os botões laterais
                final String devName = String.valueOf(dev.getName());
                if (devName.toLowerCase().matches(".*(uinput|virtual|gpio|keypad|-keys|touch|fingerprint).*"))
                    continue;
                if (Build.VERSION.SDK_INT >= 29) {
                    try {
                        if (!(Boolean) dev.getClass().getMethod("isExternal").invoke(dev))
                            continue;
                    }
                    catch (Exception e) {
                        android.util.Log.w("P7", "controle externo? " + e);
                    }
                }
                final int src = dev.getSources();
                final boolean pad = (src & android.view.InputDevice.SOURCE_GAMEPAD) == android.view.InputDevice.SOURCE_GAMEPAD
                                 || (src & android.view.InputDevice.SOURCE_JOYSTICK) == android.view.InputDevice.SOURCE_JOYSTICK;
                if (!pad)
                    continue;
                boolean present = false;
                float capacity = -1f;
                int status = 0;
                if (Build.VERSION.SDK_INT >= 31) {
                    try {
                        Object state = dev.getClass().getMethod("getBatteryState").invoke(dev);
                        present = (Boolean) state.getClass().getMethod("isPresent").invoke(state);
                        if (present) {
                            float c = (Float) state.getClass().getMethod("getCapacity").invoke(state);
                            capacity = Float.isNaN(c) ? -1f : c;
                            status = (Integer) state.getClass().getMethod("getStatus").invoke(state);
                        }
                    }
                    catch (Exception e) {
                        android.util.Log.w("P7", "bateria do controle: " + e);
                    }
                }
                out.append(dev.getName().replace('\t', ' ').replace('\n', ' '))
                   .append('\t').append(present ? 1 : 0)
                   .append('\t').append(capacity)
                   .append('\t').append(status)
                   .append('\n');
            }
        }
        catch (Exception e) {
            android.util.Log.w("P7", "controllers: " + e);
        }
        return out.toString();
    }

    // P7 Station: endereços content:// do próprio app que vão para o emulador (no -d ou num extra)
    // entram no ClipData, para a permissão de leitura valer também para os extras.
    private static void grantOwnUris(Intent intent) {
        final String prefix = "content://" + m_self.getPackageName() + ".files/";
        ClipData clip = null;
        java.util.ArrayList<Uri> uris = new java.util.ArrayList<>();
        if (intent.getData() != null && intent.getData().toString().startsWith(prefix))
            uris.add(intent.getData());
        Bundle extras = intent.getExtras();
        if (extras != null) {
            for (String key : extras.keySet()) {
                Object value = extras.get(key);
                if (value instanceof String && ((String) value).startsWith(prefix))
                    uris.add(Uri.parse((String) value));
            }
        }
        for (Uri uri : uris) {
            if (clip == null)
                clip = ClipData.newRawUri("P7", uri);
            else
                clip.addItem(new ClipData.Item(uri));
        }
        if (clip != null) {
            intent.setClipData(clip);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        }
    }

    public static boolean hasAllStorageAccess() {
        if (Build.VERSION.SDK_INT < 30)
            return true;
        return Environment.isExternalStorageManager();
    }

    public static boolean getAllStorageAccess() {
        if (Build.VERSION.SDK_INT < 30)
            return true;

        if (Environment.isExternalStorageManager())
            return true;

        Intent intent = new Intent();
        intent.setAction(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
        intent.setData(Uri.parse("package:" + m_self.getPackageName()));
        m_self.startActivity(intent);
        return false;
    }

    public static BatteryInfo queryBattery() {
        final IntentFilter ifilter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
        final Intent batIntent = m_self.registerReceiver(null, ifilter);

        final int batStatus = batIntent.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
        if (batStatus == BatteryManager.BATTERY_STATUS_UNKNOWN)
            return null;

        final boolean hasBattery = batIntent.getBooleanExtra(BatteryManager.EXTRA_PRESENT, true);
        final boolean batPlugged = batIntent.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) > 0;
        final boolean batCharged = batStatus == BatteryManager.BATTERY_STATUS_FULL;

        final int batLevel = batIntent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        final int batScale = batIntent.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
        final float batPercent = (batLevel >= 0 && batScale > 0)
            ? batLevel / (float) batScale
            : Float.NaN;

        return new BatteryInfo(hasBattery, batPlugged, batCharged, batPercent);
    }

    public static String launchAmCommand(String[] args_arr) {
        final LinkedList<String> args = new LinkedList(Arrays.asList(args_arr));
        if (args.isEmpty())
            return "No arguments provided to 'am'";

        final String am_command = args.pop().toLowerCase();
        if (!am_command.equals("start"))
            return "For 'am', only the 'start' command is supported at the moment, '" + am_command + "' is not";

        try {
            Intent intent = IntentHelper.parseIntentCommand(args);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            grantOwnUris(intent);
            android.util.Log.w("P7", "abrindo: " + intent.toUri(0));
            m_self.startActivity(intent);
        }
        catch (Exception e) {
            return e.toString() + ": " + e.getMessage();
        }

        return null;
    }

    public static String toContentUri(String path) {
        final Uri uri = FileProvider.getUriForFile(
            m_self,
            m_self.getPackageName() + ".files",
            new File(path));
        return uri.toString();
    }
}
