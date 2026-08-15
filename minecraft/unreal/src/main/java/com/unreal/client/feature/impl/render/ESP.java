package com.unreal.client.feature.impl.render;

import com.unreal.client.feature.Feature;
import com.unreal.client.impl.Client;

public class ESP extends Feature {
    private boolean boxes = true;
    private boolean outlines = true;
    private boolean filled = false;
    private int colorR = 255, colorG = 0, colorB = 0;
    private int alpha = 100;

    public ESP() {
        super("ESP", "See players through walls", Category.RENDER);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
    }

    public boolean isBoxes() { return boxes; }
    public void setBoxes(boolean boxes) { this.boxes = boxes; }
    public boolean isOutlines() { return outlines; }
    public void setOutlines(boolean outlines) { this.outlines = outlines; }
    public boolean isFilled() { return filled; }
    public void setFilled(boolean filled) { this.filled = filled; }
    public int getRed() { return colorR; }
    public void setRed(int r) { this.colorR = r; }
    public int getGreen() { return colorG; }
    public void setGreen(int g) { this.colorG = g; }
    public int getBlue() { return colorB; }
    public void setBlue(int b) { this.colorB = b; }
    public int getAlpha() { return alpha; }
    public void setAlpha(int alpha) { this.alpha = alpha; }
}
