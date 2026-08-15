package com.unreal.client.feature.impl.render;

import com.unreal.client.feature.Feature;

public class Tracers extends Feature {
    private int colorR = 255, colorG = 0, colorB = 0;
    private int alpha = 200;

    public Tracers() {
        super("Tracers", "Draw lines to players", Category.RENDER);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
    }

    public int getRed() { return colorR; }
    public void setRed(int r) { this.colorR = r; }
    public int getGreen() { return colorG; }
    public void setGreen(int g) { this.colorG = g; }
    public int getBlue() { return colorB; }
    public void setBlue(int b) { this.colorB = b; }
    public int getAlpha() { return alpha; }
    public void setAlpha(int alpha) { this.alpha = alpha; }
}
