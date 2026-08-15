package com.unreal.client.feature.impl.movement;

import com.unreal.client.feature.Feature;
import com.unreal.client.impl.Client;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;

public class BHop extends Feature {
    public BHop() {
        super("BHop", "Bunny hop automatically", Category.MOVEMENT);
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

        if (player.input != null && player.input.keyPresses.jump() && player.onGround()) {
            player.jumpFromGround();
        }
    }
}
