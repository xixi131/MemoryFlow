# MemoryFlow Island Release Notes

Add one `## vX.Y.Z` section before creating and pushing its matching Git tag.
Only that section is published to GitHub Releases and shown by Sparkle to users.

## v1.1.6

- 改进了设置页面

## v1.1.5

- 优化更新时灵动岛的动效：点击「更新」后立即收起为下载活动态。
- 全新 Material 风格加载圆环，转动更顺滑、更有节奏。
- 下载进度百分比改为居中显示并调整字号。

## v1.1.4

- 改进了复习模式图标。
- 修复 Tag 问题。

## v1.1.3

- 彻底修复 macOS 26 (Tahoe) 下菜单栏图标始终无法显示的问题：系统会按应用身份永久屏蔽被隐藏过的菜单栏图标，且无法通过重置控制中心清除，因此本版本改用全新应用身份绕过该屏蔽。
- 自动迁移并保留原有语言、功能与更新偏好设置。
- 若菜单栏图标仍被系统隐藏，应用会自动检测并引导你前往「系统设置 › 控制中心 › 允许在菜单栏中显示」重新开启。
- 因更换了应用身份，**本版本需从 DMG 手动重新安装一次**；完成后即可照常自动更新。

## v1.1.2

- 修复更新后 macOS 26 将菜单栏图标状态项恢复为隐藏的问题。
- 为菜单栏图标设置稳定身份并在应用启动后恢复可见，同时保留菜单语言实时跟随。

## v1.1.1

- 修复在设置中切换语言后，菜单栏菜单未立即同步更新的问题。
- 恢复菜单栏图标与灵动岛设置的实时语言跟随行为。

## v1.1.0

- 修复 macOS 26 下菜单栏图标无法显示的问题。
- 迁移应用身份并保留语言、功能和登录状态。
- 调整菜单栏图标为系统标准尺寸。
- 本版本需要从 DMG 手动重新安装一次。

## v1.0.12
- 修复设置页问题
- 修复更新相关问题

## v1.0.11

- Added a DMG installer with an Applications shortcut for first-time installation.
- Kept the signed ZIP and optional delta packages for Sparkle automatic updates.
- Added release validation for the DMG, checksums, update feed, and published assets.

## v1.0.9

- Initial public MemoryFlow Island release.
