package com.unreal.client.impl;

import com.unreal.client.UnrealClient;
import com.unreal.client.feature.Feature;
import com.unreal.client.feature.impl.aim.AimAssist;
import com.unreal.client.feature.impl.combat.KillAura;
import com.unreal.client.feature.impl.combat.NoHitDelay;
import com.unreal.client.feature.impl.combat.Reach;
import com.unreal.client.feature.impl.combat.Velocity;
import com.unreal.client.feature.impl.misc.AntiBot;
import com.unreal.client.feature.impl.misc.AutoReconnect;
import com.unreal.client.feature.impl.movement.BHop;
import com.unreal.client.feature.impl.movement.NoSlow;
import com.unreal.client.feature.impl.movement.Speed;
import com.unreal.client.feature.impl.render.AntiFog;
import com.unreal.client.feature.impl.render.Chams;
import com.unreal.client.feature.impl.render.ESP;
import com.unreal.client.feature.impl.render.Fullbright;
import com.unreal.client.feature.impl.render.HUD;
import com.unreal.client.feature.impl.render.Tracers;
import com.unreal.client.feature.impl.render.XRay;
import com.unreal.client.ui.HUDOverlay;
import com.unreal.client.ui.KeyBinds;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.Minecraft;

import java.util.ArrayList;
import java.util.List;

public class Client {
    private static final Minecraft mc = Minecraft.getInstance();
    private static final List<Feature> features = new ArrayList<>();

    public static void init() {
        register(new KillAura());
        register(new AimAssist());
        register(new Reach());
        register(new Velocity());
        register(new NoHitDelay());
        register(new Speed());
        register(new BHop());
        register(new NoSlow());
        register(new ESP());
        register(new Tracers());
        register(new Chams());
        register(new Fullbright());
        register(new AntiFog());
        register(new XRay());
        register(new HUD());
        register(new AntiBot());
        register(new AutoReconnect());

        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            for (Feature feature : features) {
                if (feature.isEnabled()) {
                    feature.onTick();
                }
            }
        });

        KeyBinds.getInstance().init();
        HUDOverlay.getInstance().init();

        UnrealClient.LOGGER.info("Registered {} features", features.size());
        UnrealClient.LOGGER.info("Initialized keybinds and HUD overlay");
    }

    private static void register(Feature feature) {
        features.add(feature);
        UnrealClient.LOGGER.info("Registered feature: {}", feature.getName());
    }

    public static List<Feature> getFeatures() {
        return features;
    }

    public static Minecraft getMc() {
        return mc;
    }
}
