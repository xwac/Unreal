package com.unreal.client.feature.impl.misc;

import com.unreal.client.feature.Feature;

public class AutoReconnect extends Feature {
    private int delay = 5;

    public AutoReconnect() {
        super("AutoReconnect", "Automatically reconnect after being kicked", Category.MISC);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
    }

    public int getDelay() { return delay; }
    public void setDelay(int delay) { this.delay = delay; }
}
