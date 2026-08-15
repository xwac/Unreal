package com.unreal.client.feature.impl.movement;

import com.unreal.client.feature.Feature;

public class NoSlow extends Feature {
    private boolean useStrength = true;
    private boolean weaponOnly = false;

    public NoSlow() {
        super("NoSlow", "Don't slow down when using items", Category.MOVEMENT);
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

    public boolean isUseStrength() { return useStrength; }
    public void setUseStrength(boolean useStrength) { this.useStrength = useStrength; }
    public boolean isWeaponOnly() { return weaponOnly; }
    public void setWeaponOnly(boolean weaponOnly) { this.weaponOnly = weaponOnly; }
}
