package com.unreal.client.ui;

import com.unreal.client.feature.Feature;
import com.unreal.client.impl.Client;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.input.KeyEvent;
import net.minecraft.client.input.MouseButtonEvent;
import net.minecraft.network.chat.Component;

public class ClickGUIScreen extends Screen {
    private static final int PANEL_WIDTH = 120;
    private static final int PANEL_HEIGHT = 24;
    private static final int CATEGORY_PANEL_WIDTH = 130;
    private static final int CATEGORY_PANEL_HEIGHT = 320;
    private static final int FEATURE_PANEL_X_OFFSET = 140;
    private static final int FEATURE_PANEL_WIDTH = 220;
    private static final int FEATURE_PANEL_HEIGHT = 320;

    private Feature.Category[] categories;
    private int selectedCategory = 0;
    private double scrollOffset = 0;

    public ClickGUIScreen() {
        super(Component.literal("Unreal Client"));
    }

    @Override
    public void init() {
        categories = Feature.Category.values();
    }

    @Override
    public void extractRenderState(GuiGraphicsExtractor gui, int mouseX, int mouseY, float tickDelta) {
        extractBackground(gui, mouseX, mouseY, tickDelta);

        Font font = getFont();
        if (font == null) {
            font = Minecraft.getInstance().font;
        }

        int centerX = this.width / 2;
        int centerY = this.height / 2;

        int catX = centerX - 180;
        int catY = centerY - 140;
        int featX = catX + FEATURE_PANEL_X_OFFSET;
        int featY = catY;

        // Category panel background
        gui.fill(catX, catY, catX + CATEGORY_PANEL_WIDTH, catY + CATEGORY_PANEL_HEIGHT, 0x80111111);
        // Feature panel background
        gui.fill(featX, featY, featX + FEATURE_PANEL_WIDTH, featY + FEATURE_PANEL_HEIGHT, 0x80111111);

        // Title
        gui.text(font, Component.literal("Unreal Client"), catX + 8, catY - 20, 0xFFFFFF);

        // Render category list
        for (int i = 0; i < categories.length; i++) {
            int y = catY + 8 + i * PANEL_HEIGHT;
            if (y < catY + CATEGORY_PANEL_HEIGHT - 4 && y > catY + 4) {
                boolean hovered = mouseX >= catX + 2 && mouseX <= catX + CATEGORY_PANEL_WIDTH - 2
                        && mouseY >= y && mouseY <= y + PANEL_HEIGHT - 2;

                int bg;
                if (selectedCategory == i) {
                    bg = 0x803399FF;
                } else if (hovered) {
                    bg = 0x60444444;
                } else {
                    bg = 0x40222222;
                }
                gui.fill(catX + 2, y, catX + CATEGORY_PANEL_WIDTH - 2, y + PANEL_HEIGHT - 2, bg);

                int textColor = selectedCategory == i ? 0xFFFFFF : (hovered ? 0xEEEEEE : 0xCCCCCC);
                gui.text(font, Component.literal(categories[i].getName()), catX + 8, y + 6, textColor);
            }
        }

        // Render features list for selected category
        Feature.Category selectedCat = categories[selectedCategory];
        var featuresInCat = Client.getFeatures().stream()
                .filter(f -> f.getCategory() == selectedCat)
                .toList();

        if (featuresInCat.isEmpty()) {
            gui.text(font, Component.literal("No features in this category"), featX + 8, featY + 10, 0xAAAAAA);
        } else {
            int featuresStartY = featY + 8;
            int availableHeight = FEATURE_PANEL_HEIGHT - 16;
            int maxVisible = availableHeight / PANEL_HEIGHT;

            int startIndex = (int) Math.max(0, scrollOffset / PANEL_HEIGHT);
            int endIndex = Math.min(featuresInCat.size(), startIndex + maxVisible);

            for (int i = startIndex; i < endIndex; i++) {
                Feature feature = featuresInCat.get(i);
                int y = featuresStartY + (i - startIndex) * PANEL_HEIGHT - (int) (scrollOffset % PANEL_HEIGHT);

                if (y >= featuresStartY && y < featuresStartY + availableHeight) {
                    int x = featX + 4;

                    boolean hovered = mouseX >= x && mouseX <= x + FEATURE_PANEL_WIDTH - 8
                            && mouseY >= y && mouseY <= y + PANEL_HEIGHT - 2;

                    int bg;
                    if (feature.isEnabled()) {
                        bg = 0x8000AA00;
                    } else if (hovered) {
                        bg = 0x60444444;
                    } else {
                        bg = 0x40222222;
                    }
                    gui.fill(x, y, x + FEATURE_PANEL_WIDTH - 8, y + PANEL_HEIGHT - 2, bg);

                    // Checkbox outline
                    int checkX = x + FEATURE_PANEL_WIDTH - 8 - 20;
                    int checkY = y + 4;
                    gui.fill(checkX, checkY, checkX + 14, checkY + 12, 0xFF222222);
                    if (feature.isEnabled()) {
                        gui.text(font, Component.literal("+"), checkX + 3, checkY + 1, 0x55FF55);
                    }

                    int nameColor = feature.isEnabled() ? 0x55FF55 : (hovered ? 0xFFFFFF : 0xCCCCCC);
                    gui.text(font, Component.literal(feature.getName()), x + 8, y + 6, nameColor);
                }
            }
        }
    }

    @Override
    public void extractBackground(GuiGraphicsExtractor gui, int mouseX, int mouseY, float tickDelta) {
        gui.fill(0, 0, this.width, this.height, 0x80000000);
    }

    @Override
    public boolean keyPressed(KeyEvent event) {
        if (event.key() == 256) { // Escape
            Minecraft.getInstance().setScreenAndShow(null);
            return true;
        }
        return super.keyPressed(event);
    }

    @Override
    public boolean mouseClicked(MouseButtonEvent event, boolean accepted) {
        int centerX = this.width / 2;
        int centerY = this.height / 2;
        int catX = centerX - 180;
        int catY = centerY - 140;
        int featX = catX + FEATURE_PANEL_X_OFFSET;
        int featY = catY;

        double mouseX = event.x();
        double mouseY = event.y();

        // Check category click
        for (int i = 0; i < categories.length; i++) {
            int y = catY + 8 + i * PANEL_HEIGHT;
            if (mouseX >= catX + 2 && mouseX <= catX + CATEGORY_PANEL_WIDTH - 2
                    && mouseY >= y && mouseY <= y + PANEL_HEIGHT - 2) {
                selectedCategory = i;
                scrollOffset = 0;
                return true;
            }
        }

        // Check feature click
        Feature.Category selectedCat = categories[selectedCategory];
        var featuresInCat = Client.getFeatures().stream()
                .filter(f -> f.getCategory() == selectedCat)
                .toList();

        int featuresStartY = featY + 8;
        int maxVisible = (FEATURE_PANEL_HEIGHT - 16) / PANEL_HEIGHT;
        int startIndex = (int) Math.max(0, scrollOffset / PANEL_HEIGHT);
        int endIndex = Math.min(featuresInCat.size(), startIndex + maxVisible);

        for (int i = startIndex; i < endIndex; i++) {
            int y = featuresStartY + (i - startIndex) * PANEL_HEIGHT - (int) (scrollOffset % PANEL_HEIGHT);
            int x = featX + 4;
            if (mouseX >= x && mouseX <= x + FEATURE_PANEL_WIDTH - 8
                    && mouseY >= y && mouseY <= y + PANEL_HEIGHT - 2) {
                featuresInCat.get(i).toggle();
                return true;
            }
        }

        return super.mouseClicked(event, accepted);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double horizontal, double vertical) {
        Feature.Category selectedCat = categories[selectedCategory];
        var featuresInCat = Client.getFeatures().stream()
                .filter(f -> f.getCategory() == selectedCat)
                .toList();

        int maxScroll = Math.max(0, featuresInCat.size() * PANEL_HEIGHT - (FEATURE_PANEL_HEIGHT - 16));
        scrollOffset = Math.max(0, Math.min(maxScroll, scrollOffset + vertical * PANEL_HEIGHT));
        return true;
    }
}
