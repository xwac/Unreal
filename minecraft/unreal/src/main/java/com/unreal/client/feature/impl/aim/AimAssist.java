package com.unreal.client.feature.impl.aim;

import com.unreal.client.feature.Feature;
import com.unreal.client.impl.Client;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;

public class AimAssist extends Feature {
    private float fov = 90.0f;
    private float speed = 10.0f;
    private float distance = 100.0f;
    private boolean requireMouse = false;

    public AimAssist() {
        super("AimAssist", "Helps you aim at nearby targets", Category.COMBAT);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
    }

    @Override
    public void onTick() {
        Minecraft mc = Client.getMc();
        LocalPlayer player = mc.player;
        if (player == null || !player.isAlive()) return;
    }

    public float getFov() { return fov; }
    public void setFov(float fov) { this.fov = fov; }
    public float getSpeed() { return speed; }
    public void setSpeed(float speed) { this.speed = speed; }
    public float getDistance() { return distance; }
    public void setDistance(float distance) { this.distance = distance; }
    public boolean isRequireMouse() { return requireMouse; }
    public void setRequireMouse(boolean requireMouse) { this.requireMouse = requireMouse; }
}
