package com.drum.hero.gestureexclusion;

import android.app.Activity;
import android.graphics.Rect;
import android.view.View;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import java.util.ArrayList;
import java.util.List;

public class GestureExclusionPlugin extends GodotPlugin {

    public GestureExclusionPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "GestureExclusion";
    }

    @UsedByGodot
    public void setExclusionRects(int left, int top, int right, int bottom) {
        Activity activity = getActivity();
        if (activity == null) return;

        View decorView = activity.getWindow().getDecorView();
        List<Rect> rects = new ArrayList<>();

        int viewWidth = decorView.getWidth();
        int viewHeight = decorView.getHeight();

        if (left > 0) {
            rects.add(new Rect(0, max(0, top), min(left, 200), min(bottom, viewHeight)));
        }
        if (right > 0 && right < viewWidth) {
            rects.add(new Rect(max(viewWidth - 200, right), max(0, top), viewWidth, min(bottom, viewHeight)));
        }

        decorView.setSystemGestureExclusionRects(rects);
    }

    @UsedByGodot
    public void clearExclusionRects() {
        Activity activity = getActivity();
        if (activity == null) return;

        View decorView = activity.getWindow().getDecorView();
        decorView.setSystemGestureExclusionRects(new ArrayList<>());
    }

    private static int max(int a, int b) {
        return Math.max(a, b);
    }

    private static int min(int a, int b) {
        return Math.min(a, b);
    }
}
