package com.memoryflow.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Component
@Slf4j
public class ProfileStartupLogger implements CommandLineRunner {

    private static final Pattern JDBC_MYSQL_HOST_PORT =
            Pattern.compile("^jdbc:mysql://([^/:?]+)(?::(\\d+))?.*$");

    private final Environment environment;

    @Value("${spring.datasource.url:}")
    private String datasourceUrl;

    @Value("${spring.data.redis.host:}")
    private String redisHost;

    @Value("${spring.data.redis.port:}")
    private String redisPort;

    public ProfileStartupLogger(Environment environment) {
        this.environment = environment;
    }

    @Override
    public void run(String... args) {
        String[] activeProfiles = environment.getActiveProfiles();
        String effectiveProfile = activeProfiles.length > 0 ? activeProfiles[0] : "default";

        String importedPath = String.format("./uploads/config/application-%s.yml", effectiveProfile);
        String datasourceHostPort = extractMysqlHostPort(datasourceUrl);
        String redisTarget = (redisHost == null || redisHost.isBlank()) ? "N/A" : redisHost + ":" + redisPort;

        log.info("========================================");
        log.info("MemoryFlow Runtime Environment");
        log.info("Active Profiles: {}", Arrays.toString(activeProfiles));
        log.info("Effective Profile: {}", effectiveProfile);
        log.info("External Profile Config: {}", importedPath);
        log.info("Datasource Target: {}", datasourceHostPort);
        log.info("Redis Target: {}", redisTarget);
        log.info("========================================");
    }

    private String extractMysqlHostPort(String jdbcUrl) {
        if (jdbcUrl == null || jdbcUrl.isBlank()) {
            return "N/A";
        }
        Matcher matcher = JDBC_MYSQL_HOST_PORT.matcher(jdbcUrl.trim());
        if (!matcher.matches()) {
            return "N/A";
        }
        String host = matcher.group(1);
        String port = matcher.group(2) == null ? "3306" : matcher.group(2);
        return host + ":" + port;
    }
}
