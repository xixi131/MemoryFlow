package com.memoryflow.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@Slf4j
@Component
public class DefaultAvatarInitializer implements ApplicationRunner {

    @Value("${file.upload-dir}")
    private String uploadDir;

    private static final String DEFAULT_AVATAR_FILE = "default-avatar.svg";

    private static final String DEFAULT_AVATAR_SVG = """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
              <defs>
                <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stop-color="#ffd4ee"/>
                  <stop offset="100%" stop-color="#f9a8d4"/>
                </linearGradient>
              </defs>
              <rect width="256" height="256" rx="128" fill="url(#bg)"/>
              <circle cx="128" cy="96" r="44" fill="#fff7fc"/>
              <path d="M48 220c10-42 40-66 80-66s70 24 80 66" fill="#fff7fc"/>
            </svg>
            """;

    @Override
    public void run(ApplicationArguments args) {
        if (uploadDir == null || uploadDir.isBlank()) {
            return;
        }

        try {
            String dirValue = uploadDir;
            if (!dirValue.endsWith("/") && !dirValue.endsWith("\\")) {
                dirValue = dirValue + "/";
            }

            Path dir = Paths.get(dirValue).normalize().toAbsolutePath();
            Files.createDirectories(dir);

            Path avatar = dir.resolve(DEFAULT_AVATAR_FILE).normalize().toAbsolutePath();
            if (!avatar.startsWith(dir)) {
                return;
            }

            if (!Files.exists(avatar)) {
                Files.writeString(avatar, DEFAULT_AVATAR_SVG, StandardCharsets.UTF_8);
                log.info("Created default avatar file: {}", avatar);
            }
        } catch (Exception e) {
            log.warn("Failed to initialize default avatar: {}", e.getMessage());
        }
    }
}
