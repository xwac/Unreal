package com.unreal.client.ui;

import com.unreal.client.feature.Feature;
import com.unreal.client.impl.Client;
import net.minecraft.client.DeltaTracker;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;

import java.util.List;

public class HUDOverlay {
    private static HUDOverlay INSTANCE;
    private double offsetX = 5;
    private double offsetY = 5;

    public static HUDOverlay getInstance() {
        if (INSTANCE == null) {
            INSTANCE = new HUDOverlay();
        }
        return INSTANCE;
    }

    public void init() {
        net.fabricmc.fabric.api.client.rendering.v1.hud.HudElementRegistry.addFirst(
                Identifier.tryParse("unreal:hud"),
                this::renderHud
        );
    }

    private void renderHud(GuiGraphicsExtractor gui, DeltaTracker deltaTracker) {
        Minecraft mc = Minecraft.getInstance();
        Font font = mc.font;

        if (font == null) {
            return;
        }

        List<Feature> enabledFeatures = Client.getFeatures().stream()
                .filter(Feature::isEnabled)
                .toList();

        if (enabledFeatures.isEmpty()) {
            return;
        }

        int x = (int) offsetX;
        int y = (int) offsetY;

        int height = Math.max(10, enabledFeatures.size() * 12 + 8);
        int width = 0;
        for (Feature feature : enabledFeatures) {
            int w = font.width(feature.getName());
            if (w > width) width = w;
        }
        width += 14;

        // Background
        gui.fill(x, y, x + width, y + 12, 0x80111111);
        gui.text(font, Component.literal("Unreal"), x + 4, y + 2, 0x55FF55);

        int currentY = y + 14;
        for (Feature feature : enabledFeatures) {
            gui.fill(x, currentY, x + width, currentY + 12, 0x40111111);
            gui.text(font, Component.literal("> " + feature.getName()), x + 4, currentY + 2, 0xFFFFFF);
            currentY += 12;
        }
    }

    public double getOffsetX() { return offsetX; }
    public void setOffsetX(double x) { this.offsetX = x; }
    public double getOffsetY() { return offsetY; }
    public void setOffsetY(double y) { this.offsetY = y; }
}
