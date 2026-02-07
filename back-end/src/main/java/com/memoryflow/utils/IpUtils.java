package com.memoryflow.utils;

import cn.hutool.core.util.StrUtil;
import cn.hutool.http.HttpUtil;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.net.InetAddress;
import java.net.UnknownHostException;

@Slf4j
@Component
public class IpUtils {

    private static final String IP_API_URL = "http://ip-api.com/json/";
    private static final ObjectMapper objectMapper = new ObjectMapper();

    private static final int TIMEOUT = 3000; // 3秒超时

    /**
     * 获取客户端IP地址
     * 支持多级反向代理
     */
    public String getClientIp(HttpServletRequest request) {
        String ip = request.getHeader("x-forwarded-for");
        if (ip == null || ip.length() == 0 || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("Proxy-Client-IP");
        }
        if (ip == null || ip.length() == 0 || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("WL-Proxy-Client-IP");
        }
        if (ip == null || ip.length() == 0 || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("HTTP_CLIENT_IP");
        }
        if (ip == null || ip.length() == 0 || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("HTTP_X_FORWARDED_FOR");
        }
        if (ip == null || ip.length() == 0 || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("X-Real-IP");
        }
        if (ip == null || ip.length() == 0 || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
            if ("127.0.0.1".equals(ip) || "0:0:0:0:0:0:0:1".equals(ip)) {
                // 根据网卡取本机配置的IP
                try {
                    InetAddress inet = InetAddress.getLocalHost();
                    ip = inet.getHostAddress();
                } catch (UnknownHostException e) {
                    log.warn("Failed to get local host ip", e);
                }
            }
        }
        
        // 多个代理的情况，第一个IP为客户端真实IP,多个IP按照','分割
        if (ip != null && ip.length() > 15) {
            if (ip.indexOf(",") > 0) {
                ip = ip.substring(0, ip.indexOf(","));
            }
        }
        return ip;
    }

    /**
     * 获取IP归属地
     * 自动处理本地IP，尝试获取服务器公网位置
     */
    public String getIpLocation(String ip) {
        if (StrUtil.isBlank(ip)) {
            return "未知";
        }
        
        // 如果是本地IP，尝试获取本机的外网位置
        if (isLocalIp(ip)) {
            return getPublicIpLocation();
        }

        return resolveLocation(ip);
    }

    private boolean isLocalIp(String ip) {
        return "127.0.0.1".equals(ip) || "0:0:0:0:0:0:0:1".equals(ip) || "localhost".equals(ip) || ip.startsWith("192.168.") || ip.startsWith("10.");
    }

    /**
     * 获取本机公网位置
     */
    private String getPublicIpLocation() {
        try {
            // 不带IP参数，默认返回请求者的位置（即服务器所在位置）
            String response = HttpUtil.get(IP_API_URL + "?lang=zh-CN", TIMEOUT);
            return parseLocation(response, "本地网络");
        } catch (Exception e) {
            log.warn("Failed to resolve public IP location: {}", e.getMessage());
            return "本地网络";
        }
    }

    /**
     * 解析指定IP位置
     */
    private String resolveLocation(String ip) {
        try {
            String response = HttpUtil.get(IP_API_URL + ip + "?lang=zh-CN", TIMEOUT);
            return parseLocation(response, "未知位置");
        } catch (Exception e) {
            log.warn("Failed to resolve IP location for {}: {}", ip, e.getMessage());
            return "未知位置";
        }
    }

    private String parseLocation(String jsonResponse, String defaultValue) {
        try {
            JsonNode root = objectMapper.readTree(jsonResponse);
            if ("success".equals(root.path("status").asText())) {
                String country = root.path("country").asText();
                String region = root.path("regionName").asText();
                String city = root.path("city").asText();
                
                StringBuilder location = new StringBuilder();
                if (StrUtil.isNotBlank(country)) location.append(country).append(" ");
                if (StrUtil.isNotBlank(region)) location.append(region).append(" ");
                if (StrUtil.isNotBlank(city) && !city.equals(region)) location.append(city);
                
                String result = location.toString().trim();
                return result.isEmpty() ? defaultValue : result;
            }
        } catch (Exception e) {
            log.warn("Error parsing location JSON: {}", e.getMessage());
        }
        return defaultValue;
    }
}
