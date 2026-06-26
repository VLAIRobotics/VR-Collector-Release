# X1 VR SDK v1.1.0 更新说明

## 新增功能

- 新增 aarch64 (Jetson) 平台支持
- 修复 Conda 与 ROS2 环境共存时的兼容性问题

## 优化调整

- 优化默认控制参数，提升遥操作稳定性
- 相机配置统一由配置文件管理

## 使用方式

使用方式与 v1.0 完全一致，详见 `docs/x1_vr_sdk使用文档.md`。

```bash
# 安装（会自动替换已安装的 v1.0，无需手动卸载）
pip install x1_vr_sdk-1.1.0-py3-none-any.whl

# 后续步骤与 v1.0 一致
xarm install
xarm init --output my_config.yaml
xarm check --config my_config.yaml
xarm setup-can --config my_config.yaml
xarm collect --config my_config.yaml
```

## 发布版本

| 架构 | v1.0 | v1.1 |
|------|------|------|
| x86_64 | ✅ | ✅ |
| aarch64 (Jetson) | ✅ | 即将发布 |

## 升级注意事项

- 如果沿用 v1.0 的配置文件，建议重新生成（`xarm init`）并对照修改，以获取最新默认参数
