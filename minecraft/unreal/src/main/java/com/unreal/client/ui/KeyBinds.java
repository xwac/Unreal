package com.unreal.client.ui;

import com.mojang.blaze3d.platform.InputConstants;
import com.unreal.client.impl.Client;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraft.resources.Identifier;

public class KeyBinds {
    private static KeyBinds INSTANCE;
    private KeyMapping openClickGui;

    public static KeyBinds getInstance() {
        if (INSTANCE == null) {
            INSTANCE = new KeyBinds();
        }
        return INSTANCE;
    }

    public void init() {
        openClickGui = new KeyMapping(
                "key.unreal.click_gui",
                InputConstants.Type.KEYSYM,
                InputConstants.KEY_RSHIFT,
                KeyMapping.Category.register(Identifier.tryParse("unreal:main"))
        );

        ClientTickEvents.END_CLIENT_TICK.register(this::onClientTick);
    }

    private void onClientTick(Minecraft mc) {
        if (openClickGui != null && openClickGui.consumeClick()) {
            if (mc.gui.screen() == null) {
                mc.setScreenAndShow(new ClickGUIScreen());
            } else {
                mc.setScreenAndShow(null);
            }
        }
    }
}
