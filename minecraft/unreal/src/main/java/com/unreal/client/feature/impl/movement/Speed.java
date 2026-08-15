package com.unreal.client.feature.impl.movement;

import com.unreal.client.feature.Feature;
import com.unreal.client.impl.Client;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;

public class Speed extends Feature {
    private double speed = 0.4;
    private String mode = "BHop";

    public Speed() {
        super("Speed", "Move faster", Category.MOVEMENT);
    }

    @Override
    public void onEnable() {
    }

    @Override
    public void onDisable() {
        Minecraft mc = Client.getMc();
        if (mc.player != null) {
            mc.player.setSpeed(0);
        }
    }

    @Override
    public void onTick() {
        Minecraft mc = Client.getMc();
        LocalPlayer player = mc.player;
        if (player == null || !player.isAlive()) return;

        switch (mode) {
            case "BHop":
                if (player.onGround() && player.input.keyPresses.forward() || player.input.keyPresses.backward()
                    || player.input.keyPresses.left() || player.input.keyPresses.right()) {
                    if (!player.isShiftKeyDown() && !player.isSprinting()) {
                        player.jumpFromGround();
                    }
                }
                break;
        }
    }

    public double getSpeed() { return speed; }
    public void setSpeed(double speed) { this.speed = speed; }
    public String getMode() { return mode; }
    public void setMode(String mode) { this.mode = mode; }
}
