package com.unreal.client.feature.impl.render;

import com.unreal.client.feature.Feature;

public class Chams extends Feature {
    private boolean outline = true;
    private boolean color = true;
    private int colorR = 255, colorG = 0, colorB = 0;
    private int alpha = 150;

    public Chams() {
        super("Chams", "See players through walls with colored overlays", Category.RENDER);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
    }

    public boolean isOutline() { return outline; }
    public void setOutline(boolean outline) { this.outline = outline; }
    public boolean isColor() { return color; }
    public void setColor(boolean color) { this.color = color; }
    public int getRed() { return colorR; }
    public void setRed(int r) { this.colorR = r; }
    public int getGreen() { return colorG; }
    public void setGreen(int g) { this.colorG = g; }
    public int getBlue() { return colorB; }
    public void setBlue(int b) { this.colorB = b; }
    public int getAlpha() { return alpha; }
    public void setAlpha(int alpha) { this.alpha = alpha; }
}
