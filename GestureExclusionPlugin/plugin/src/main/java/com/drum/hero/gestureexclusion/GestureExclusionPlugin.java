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
    public void setExclusionRects(int left, int top, int right, int bottom, int viewportW, int viewportH) {
        Activity activity = getActivity();
        if (activity == null) return;

        View decorView = activity.getWindow().getDecorView();
        List<Rect> rects = new ArrayList<>();

        int viewWidth = decorView.getWidth();
        int viewHeight = decorView.getHeight();

        if (viewportW <= 0 || viewportH <= 0) return;

        float scaleX = (float) viewWidth / (float) viewportW;
        float scaleY = (float) viewHeight / (float) viewportH;

        if (left > 0) {
            int r = Math.min((int)(left * scaleX + 0.5f), viewWidth);
            int t = Math.max(0, (int)(top * scaleY + 0.5f));
            int b = Math.min((int)(bottom * scaleY + 0.5f), viewHeight);
            rects.add(new Rect(0, t, r, b));
        }
        if (right > 0 && right < viewportW) {
            int l = Math.max(0, viewWidth - (int)((viewportW - right) * scaleX + 0.5f));
            int t = Math.max(0, (int)(top * scaleY + 0.5f));
            int b = Math.min((int)(bottom * scaleY + 0.5f), viewHeight);
            rects.add(new Rect(l, t, viewWidth, b));
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
}
