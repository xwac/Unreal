package com.unreal.client.feature;

public abstract class Feature {
    private boolean enabled = false;
    private final String name;
    private final String description;
    private final Category category;

    public Feature(String name, String description, Category category) {
        this.name = name;
        this.description = description;
        this.category = category;
    }

    public abstract void onEnable();
    public abstract void onDisable();
    public void onTick() {}
    public void onRender(float tickDelta) {}

    public void toggle() {
        if (enabled) {
            enabled = false;
            onDisable();
        } else {
            enabled = true;
            onEnable();
        }
    }

    public boolean isEnabled() {
        return enabled;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public Category getCategory() {
        return category;
    }

    public enum Category {
        COMBAT("Combat"),
        MOVEMENT("Movement"),
        RENDER("Render"),
        MISC("Misc");

        private final String name;

        Category(String name) {
            this.name = name;
        }

        public String getName() {
            return name;
        }
    }
}
