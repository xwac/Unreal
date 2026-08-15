package com.unreal.client.feature.impl.combat;

import com.unreal.client.feature.Feature;

public class Velocity extends Feature {
    private int horizontalPercent = 0;
    private int verticalPercent = 0;

    public Velocity() {
        super("Velocity", "Modifies knockback received", Category.COMBAT);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
        // Reset velocity modifiers
    }

    public int getHorizontalPercent() { return horizontalPercent; }
    public void setHorizontalPercent(int percent) { this.horizontalPercent = percent; }
    public int getVerticalPercent() { return verticalPercent; }
    public void setVerticalPercent(int percent) { this.verticalPercent = percent; }
}
