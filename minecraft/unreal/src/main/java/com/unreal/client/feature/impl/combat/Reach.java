package com.unreal.client.feature.impl.combat;

import com.unreal.client.feature.Feature;

public class Reach extends Feature {
    private float range = 3.0f;
    private float extraReach = 0.5f;

    public Reach() {
        super("Reach", "Extends your attack reach", Category.COMBAT);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
    }

    @Override
    public void onTick() {
    }

    public float getRange() { return range + extraReach; }
    public void setRange(float range) { this.range = range; }
    public float getExtraReach() { return extraReach; }
    public void setExtraReach(float extraReach) { this.extraReach = extraReach; }
}
