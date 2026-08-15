package com.unreal.client;

import com.unreal.client.impl.Client;
import net.fabricmc.api.ModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UnrealClient implements ModInitializer {
    public static final String MOD_ID = "unreal";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    @Override
    public void onInitialize() {
        LOGGER.info("Unreal Client initializing...");
        Client.init();
        LOGGER.info("Unreal Client initialized successfully!");
    }
}
