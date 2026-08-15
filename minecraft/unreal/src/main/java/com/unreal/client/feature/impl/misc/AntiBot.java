package com.unreal.client.feature.impl.misc;

import com.unreal.client.feature.Feature;

public class AntiBot extends Feature {
    private boolean swing = true;
    private boolean health = true;
    private boolean name = true;

    public AntiBot() {
        super("AntiBot", "Filter out bots from targeting", Category.MISC);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
    }

    public boolean isSwing() { return swing; }
    public void setSwing(boolean swing) { this.swing = swing; }
    public boolean isHealth() { return health; }
    public void setHealth(boolean health) { this.health = health; }
    public boolean isName() { return name; }
    public void setName(boolean name) { this.name = name; }
}
