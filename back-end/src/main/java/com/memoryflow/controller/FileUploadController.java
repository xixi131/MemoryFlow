package com.memoryflow.controller;

import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.mapper.UserMapper;
import com.memoryflow.security.SecurityUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 文件上传控制器
 */
@RestController
@RequestMapping("/upload")
public class FileUploadController {

    @Value("${file.upload-dir}")
    private String uploadDir;

    private final UserMapper userMapper;
    private final SecurityUtils securityUtils;

    public FileUploadController(UserMapper userMapper, SecurityUtils securityUtils) {
        this.userMapper = userMapper;
        this.securityUtils = securityUtils;
    }

    /**
     * 上传头像
     *
     * @param file 头像文件
     * @return 上传结果，包含文件URL
     */
    @PostMapping("/avatar")
    public Map<String, String> uploadAvatar(@RequestParam("file") MultipartFile file) {
        if (file.isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "文件不能为空");
        }

        try {
            Long userId = securityUtils.getCurrentUserId();
            if (userId == null) {
                throw new BusinessException(ErrorCode.UNAUTHORIZED, "未登录");
            }

            var user = userMapper.selectById(userId);
            if (user == null) {
                throw new BusinessException(ErrorCode.NOT_FOUND, "用户不存在");
            }

            String oldAvatarUrl = user.getAvatarUrl();

            // 确保目录存在
            Path uploadPath = Paths.get(uploadDir);
            if (!Files.exists(uploadPath)) {
                Files.createDirectories(uploadPath);
            }

            // 生成唯一文件名
            String originalFilename = file.getOriginalFilename();
            String extension = "";
            if (originalFilename != null && originalFilename.contains(".")) {
                extension = originalFilename.substring(originalFilename.lastIndexOf("."));
            }
            String fileName = UUID.randomUUID().toString() + extension;

            // 保存文件
            Path filePath = uploadPath.resolve(fileName);
            Files.copy(file.getInputStream(), filePath);

            // 生成访问URL
            String fileUrl = "/api/uploads/avatars/" + fileName;

            user.setAvatarUrl(fileUrl);
            userMapper.updateById(user);

            deleteOldAvatarIfReplaced(oldAvatarUrl, fileUrl);
            
            Map<String, String> response = new HashMap<>();
            response.put("url", fileUrl);
            return response;

        } catch (IOException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "文件上传失败");
        }
    }

    private void deleteOldAvatarIfReplaced(String oldAvatarUrl, String newAvatarUrl) {
        String oldFileName = extractAvatarFileName(oldAvatarUrl);
        if (oldFileName == null || oldFileName.isBlank()) return;

        String newFileName = extractAvatarFileName(newAvatarUrl);
        if (oldFileName.equals(newFileName)) return;
        if ("default-avatar.png".equalsIgnoreCase(oldFileName)) return;

        try {
            String dir = uploadDir;
            if (dir == null || dir.isBlank()) return;
            if (!dir.endsWith("/") && !dir.endsWith("\\")) dir = dir + "/";

            Path base = Paths.get(dir).normalize().toAbsolutePath();
            Path target = base.resolve(oldFileName).normalize().toAbsolutePath();
            if (!target.startsWith(base)) return;

            Files.deleteIfExists(target);
        } catch (Exception ignored) {
        }
    }

    private String extractAvatarFileName(String avatarUrl) {
        if (avatarUrl == null) return null;
        String value = avatarUrl.trim();
        if (value.isEmpty()) return null;

        String path = value;
        try {
            if (value.startsWith("http://") || value.startsWith("https://")) {
                path = new URL(value).getPath();
            }
        } catch (Exception ignored) {
        }

        String base = null;
        if (path.contains("/api/uploads/avatars/")) base = "/api/uploads/avatars/";
        if (base == null && path.contains("/uploads/avatars/")) base = "/uploads/avatars/";
        if (base == null) return null;

        int start = path.indexOf(base);
        String tail = path.substring(start + base.length());
        if (tail.isEmpty() || tail.contains("/") || tail.contains("\\")) return null;
        return tail;
    }
}
