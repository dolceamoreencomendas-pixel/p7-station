package org.yuzu.yuzu_emu.activities;

import android.app.Activity;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;
import java.io.InputStream;

public class EmulationActivity extends Activity {
    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        Uri uri = getIntent().getData();
        String msg = "Nyushu Teste abriu: " + uri;
        try (InputStream in = getContentResolver().openInputStream(uri)) {
            msg += " (arquivo lido)";
        } catch (Exception e) {
            msg += " (sem acesso ao arquivo: " + e + ")";
        }
        Log.w("P7FALSO", msg);
        TextView t = new TextView(this);
        t.setText(msg);
        t.setTextSize(28);
        setContentView(t);
    }
}
