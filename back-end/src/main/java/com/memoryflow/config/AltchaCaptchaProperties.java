package com.memoryflow.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/** Settings for the self-hosted ALTCHA proof-of-work challenge. */
@Data
@Configuration
@ConfigurationProperties(prefix = "altcha.captcha")
public class AltchaCaptchaProperties {

    private String secret;
    private int cost = 5000;
    private int expiresInSeconds = 180;
    private int maxChallengeRequestsPerMinute = 20;
}
