package dev.zernanvash.juanderquest;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.InputDevice;
import android.view.MotionEvent;
import java.io.File;
import java.io.FileOutputStream;

/** Disposable Phase 0 evidence runner; never included in the release application. */
public final class SpikeGestureInstrumentation extends Instrumentation {
    private float width;
    private float height;

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        start();
    }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            String target = getTargetContext().getPackageName();
            if (!target.equals("dev.zernanvash.juanderquest.maplibre_spike")) {
                throw new IllegalStateException("Refusing any target except isolated spike");
            }
            Intent intent = getTargetContext().getPackageManager().getLaunchIntentForPackage(target);
            if (intent == null) throw new IllegalStateException("No spike launcher");
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivitySync(intent);
            SystemClock.sleep(8000);
            Bitmap initial = getUiAutomation().takeScreenshot();
            if (initial == null) throw new IllegalStateException("No screenshot");
            width = initial.getWidth();
            height = initial.getHeight();
            initial.recycle();
            capture("01-street-labels");
            gesture("pinch");
            capture("02-pinch");
            gesture("rotate");
            capture("03-rotate");
            gesture("tilt-down");
            capture("04-tilt-down");
            gesture("tilt-up");
            capture("05-tilt-up");
            for (int index = 0; index < 6; index++) gesture(index % 2 == 0 ? "pan-left" : "pan-right");
            capture("06-pan");
            result.putString("evidence", getTargetContext().getExternalFilesDir("phase0").getAbsolutePath());
            result.putString("result", "Gestures injected; inspect images/camera readouts for acceptance");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("error", error.toString());
            finish(Activity.RESULT_CANCELED, result);
        }
    }

    private void capture(String name) throws Exception {
        SystemClock.sleep(1200);
        Bitmap bitmap = getUiAutomation().takeScreenshot();
        if (bitmap == null) throw new IllegalStateException("Screenshot unavailable");
        File directory = getTargetContext().getExternalFilesDir("phase0");
        if (directory == null) throw new IllegalStateException("No isolated evidence directory");
        File file = new File(directory, name + ".png");
        try (FileOutputStream output = new FileOutputStream(file)) {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output);
        } finally {
            bitmap.recycle();
        }
    }

    private void gesture(String kind) {
        boolean pan = kind.startsWith("pan-");
        int count = pan ? 1 : 2;
        MotionEvent.PointerProperties[] properties = new MotionEvent.PointerProperties[count];
        MotionEvent.PointerCoords[] coordinates = new MotionEvent.PointerCoords[count];
        for (int index = 0; index < count; index++) {
            properties[index] = new MotionEvent.PointerProperties();
            properties[index].id = index;
            properties[index].toolType = MotionEvent.TOOL_TYPE_FINGER;
            coordinates[index] = new MotionEvent.PointerCoords();
            coordinates[index].pressure = 1;
            coordinates[index].size = 1;
        }
        long down = SystemClock.uptimeMillis();
        for (int step = 0; step <= 60; step++) {
            float progress = step / 60f;
            for (int index = 0; index < count; index++) {
                float sign = index == 0 ? -1 : 1;
                float radius = width * (kind.equals("pinch") ? 0.10f + 0.12f * progress : 0.18f);
                double angle = kind.equals("rotate") ? progress * Math.PI / 3 : 0;
                coordinates[index].x = width * 0.50f + sign * radius * (float)Math.cos(angle);
                coordinates[index].y = height * 0.58f + sign * radius * (float)Math.sin(angle);
                if (pan) coordinates[index].x = width * (kind.equals("pan-left") ? 0.7f - progress * 0.4f : 0.3f + progress * 0.4f);
                if (kind.startsWith("tilt-")) coordinates[index].y += height * 0.16f * progress * (kind.equals("tilt-down") ? 1 : -1);
            }
            if (step == 0) {
                inject(down, MotionEvent.ACTION_DOWN, 1, properties, coordinates);
                if (!pan) inject(down, MotionEvent.ACTION_POINTER_DOWN | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, properties, coordinates);
            } else {
                inject(down, MotionEvent.ACTION_MOVE, count, properties, coordinates);
            }
            SystemClock.sleep(16);
        }
        if (!pan) inject(down, MotionEvent.ACTION_POINTER_UP | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, properties, coordinates);
        inject(down, MotionEvent.ACTION_UP, 1, properties, coordinates);
        SystemClock.sleep(500);
    }

    private void inject(long down, int action, int count, MotionEvent.PointerProperties[] properties, MotionEvent.PointerCoords[] coordinates) {
        MotionEvent event = MotionEvent.obtain(down, SystemClock.uptimeMillis(), action, count, properties, coordinates, 0, 0, 1, 1, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0);
        try {
            // sendPointerSync rejects windows outside the instrumentation target.
            sendPointerSync(event);
        } finally {
            event.recycle();
        }
    }
}
