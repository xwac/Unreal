package com.unreal.client.feature.impl.render;

import com.unreal.client.feature.Feature;
import com.unreal.client.impl.Client;
import net.minecraft.client.Minecraft;

public class Fullbright extends Feature {
    private double gamma = 16.0;

    public Fullbright() {
        super("Fullbright", "See in the dark", Category.RENDER);
    }

    @Override
    public void onEnable() {
        Minecraft mc = Client.getMc();
        mc.options.gamma().set(gamma);
    }

    @Override
    public void onDisable() {
        Minecraft mc = Client.getMc();
        mc.options.gamma().set(1.0);
    }

    public double getGamma() { return gamma; }
    public void setGamma(double gamma) { this.gamma = gamma; }
}
