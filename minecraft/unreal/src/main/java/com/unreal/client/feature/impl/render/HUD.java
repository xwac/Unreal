package com.unreal.client.feature.impl.render;

import com.unreal.client.feature.Feature;

public class HUD extends Feature {
    private boolean showFPS = true;
    private boolean showCPS = true;
    private boolean showCoords = true;
    private int x = 5;
    private int y = 5;

    public HUD() {
        super("HUD", "Display information overlay", Category.RENDER);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
    }

    public boolean isShowFPS() { return showFPS; }
    public void setShowFPS(boolean showFPS) { this.showFPS = showFPS; }
    public boolean isShowCPS() { return showCPS; }
    public void setShowCPS(boolean showCPS) { this.showCPS = showCPS; }
    public boolean isShowCoords() { return showCoords; }
    public void setShowCoords(boolean showCoords) { this.showCoords = showCoords; }
    public int getX() { return x; }
    public void setX(int x) { this.x = x; }
    public int getY() { return y; }
    public void setY(int y) { this.y = y; }
}
