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

    /**
     * 上传通用图片（如倒数日背景图）。
     * 与 /upload/avatar 的关键区别：只保存文件并返回 URL，绝不修改用户头像。
     * 若传入 oldUrl（被替换掉的旧图），会删除该旧文件，避免服务器上堆积无用图片。
     *
     * @param file   图片文件
     * @param oldUrl 可选，被替换的旧图 URL；若属于本服务上传的图片则删除它
     * @return 上传结果，包含文件 URL
     */
    @PostMapping("/image")
    public Map<String, String> uploadImage(@RequestParam("file") MultipartFile file,
                                           @RequestParam(value = "oldUrl", required = false) String oldUrl) {
        if (file.isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "文件不能为空");
        }

        try {
            Long userId = securityUtils.getCurrentUserId();
            if (userId == null) {
                throw new BusinessException(ErrorCode.UNAUTHORIZED, "未登录");
            }

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

            // 删除被替换的旧图（节省服务器空间），但绝不删除用户头像或默认图
            String currentAvatarUrl = null;
            var user = userMapper.selectById(userId);
            if (user != null) {
                currentAvatarUrl = user.getAvatarUrl();
            }
            deleteReplacedImage(oldUrl, fileUrl, currentAvatarUrl);

            Map<String, String> response = new HashMap<>();
            response.put("url", fileUrl);
            return response;

        } catch (IOException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "文件上传失败");
        }
    }

    /**
     * 删除被替换掉的旧图片文件（用于倒数日背景图等通用图片，节省磁盘空间）。
     * 安全约束：只删本服务 uploads 目录内的文件；跳过默认头像；
     * 且绝不删除当前用户的头像文件（即便它恰好与旧图同名）。
     */
    private void deleteReplacedImage(String oldUrl, String newUrl, String currentAvatarUrl) {
        String oldFileName = extractAvatarFileName(oldUrl);
        if (oldFileName == null || oldFileName.isBlank()) return;
        if (oldFileName.equals(extractAvatarFileName(newUrl))) return;
        if (isDefaultAvatarFile(oldFileName)) return;

        // 不要误删用户当前头像
        String avatarFileName = extractAvatarFileName(currentAvatarUrl);
        if (avatarFileName != null && oldFileName.equals(avatarFileName)) return;

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

    private void deleteOldAvatarIfReplaced(String oldAvatarUrl, String newAvatarUrl) {
        String oldFileName = extractAvatarFileName(oldAvatarUrl);
        if (oldFileName == null || oldFileName.isBlank()) return;

        String newFileName = extractAvatarFileName(newAvatarUrl);
        if (oldFileName.equals(newFileName)) return;
        if (isDefaultAvatarFile(oldFileName)) return;

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

    private boolean isDefaultAvatarFile(String fileName) {
        if (fileName == null) return false;
        return "default-avatar.png".equalsIgnoreCase(fileName)
                || "default-avatar.svg".equalsIgnoreCase(fileName);
    }
}
