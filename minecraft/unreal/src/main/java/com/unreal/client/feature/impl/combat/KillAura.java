package com.unreal.client.feature.impl.combat;

import com.unreal.client.feature.Feature;
import com.unreal.client.impl.Client;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.Entity;

public class KillAura extends Feature {
    private float range = 3.0f;
    private float speed = 10.0f;
    private long lastAttack = 0;
    private boolean requireMouse = false;
    private boolean swordLungeOnly = false;

    public KillAura() {
        super("KillAura", "Attack players around you automatically", Category.COMBAT);
    }

    @Override
    public void onEnable() {
        lastAttack = 0;
    }

    @Override
    public void onDisable() {
    }

    @Override
    public void onTick() {
        Minecraft mc = Client.getMc();
        LocalPlayer player = mc.player;

        if (player == null || !player.isAlive()) return;

        if (requireMouse && !mc.options.keyAttack.isDown()) return;

        long now = System.currentTimeMillis();
        long delay = (long) (1000 / speed);
        if (now - lastAttack < delay) return;

        Entity target = findTarget(player);
        if (target != null) {
            mc.gameMode.attack(player, target);
            player.swing(InteractionHand.MAIN_HAND);
            lastAttack = now;
        }
    }

    private Entity findTarget(LocalPlayer player) {
        return null;
    }

    public float getRange() { return range; }
    public void setRange(float range) { this.range = range; }
    public float getSpeed() { return speed; }
    public void setSpeed(float speed) { this.speed = speed; }
    public boolean isRequireMouse() { return requireMouse; }
    public void setRequireMouse(boolean requireMouse) { this.requireMouse = requireMouse; }
    public boolean isSwordLungeOnly() { return swordLungeOnly; }
    public void setSwordLungeOnly(boolean swordLungeOnly) { this.swordLungeOnly = swordLungeOnly; }
}
