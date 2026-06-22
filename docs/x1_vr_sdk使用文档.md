# X1 VR SDK 使用指南

## 1. 文档目标

本指南用于帮助用户快速完成以下事项：

1. 安装 SDK 并配置运行环境
2. 理解 SDK 提供的命令行工具与配置项
3. 使用 CLI 完成 VR 遥操作数据采集
4. 快速定位常见问题

> 安装步骤见第 6 节「快速上手流程」。

---

## 2. SDK 包内结构

安装后位于 `<conda env>/lib/python3.10/site-packages/xarm/`，实际文件如下：

```text
xarm/
  - __init__.py                                          # 包入口（加载 _vendor 运行时库）
  - cli.py                                               # CLI 命令行入口
  - install.sh                                           # 依赖安装脚本（xarm install 调用）
  - configs/
    - default.yaml                                       # 默认配置模板（xarm init 复制它）
  - ros2_nodes/
    - __init__.py
    - hardware_node.py                                   # 硬件控制节点
    - teleop_node.py                                     # VR 遥操作节点
    - recorder_node.py                                   # 数据采集节点
  - assets/xarm/
    - scene.xml                                          # MuJoCo 场景模型
    - xarm_bimanual.xml                                  # 双臂模型（MuJoCo）
    - xarm_bimanual.urdf                                 # 双臂模型（URDF）
    - xarm_single.urdf                                   # 单臂模型（URDF）
    - meshes/
      - visual/                                          # 可视化网格（.obj × 32）
      - collision/                                       # 碰撞网格（.stl × 11）
  - _hardware/
    - __init__.py
    - interface.cpython-310-x86_64-linux-gnu.so          # 双臂硬件控制模块（CAN 总线 MIT 模式）
  - _teleop/
    - __init__.py
    - mujoco_ik.cpython-310-x86_64-linux-gnu.so          # MuJoCo 逆运动学遥操作模块
    - vr_controller.cpython-310-x86_64-linux-gnu.so      # VR 控制器姿态处理模块（坐标变换、滤波）
    - xr_client.cpython-310-x86_64-linux-gnu.so          # XR 设备通信模块（头显、手柄、追踪器）
  - _collection/
    - __init__.py
    - recorder.cpython-310-x86_64-linux-gnu.so           # 数据采集与存储模块（LeRobot v3.0 格式）
  - _utils/
    - __init__.py
    - geometry.cpython-310-x86_64-linux-gnu.so           # 几何变换工具库
    - filters.cpython-310-x86_64-linux-gnu.so            # 信号滤波工具库
  - _vendor/
    - __init__.py
    - xarm_can.cpython-310-x86_64-linux-gnu.so           # CAN 总线底层通信库
    - libPXREARobotSDK.so                                # XR 设备 SDK 运行时库
```

> `.so` 文件名带 `cpython-310-x86_64-linux-gnu` 后缀，表明该 wheel 仅适用于 **Linux x86_64 + Python 3.10**。

### 各模块说明

| 	     模块 	                  | 					说明 						           |
|-------------------------------|--------------------------------------------------------------------------------------------|
| `_hardware/interface.so` 	| 通过 CAN 总线以 MIT 模式控制双臂（各 7 关节 + 1 夹爪），负责电机初始化、使能、位置控制、状态反馈 |
| `_teleop/mujoco_ik.so` 	| 基于 MuJoCo 仿真器的逆运动学解算，将 VR 手柄末端位姿转换为关节角度目标 			            |
| `_teleop/vr_controller.so`    | VR 控制器姿态预处理：头显坐标系到世界坐标系变换、EMA 平滑滤波、参考系偏移管理 		            |
| `_teleop/xr_client.so`  	| 与 XR 设备（VR 头显、手柄、追踪器）通信，获取位姿、按键、手部追踪等数据		                              |
| `_collection/recorder.so`  	| 订阅 ROS2 话题并按帧率采集关节数据与相机图像，存储为 LeRobot v3.0 格式数据集 		            |
| `_utils/geometry.so`  	| 几何变换工具：四元数运算、坐标系转换、角轴表示等 					            |
| `_utils/filters.so` 	 	| 信号滤波器：One-Euro 位置滤波、四元数姿态滤波                                                |
| `_vendor/xarm_can.so` 	| CAN 总线底层通信库，为 `_hardware/interface.so` 提供驱动支持                                 |
| `_vendor/libPXREARobotSDK.so` | XR 设备 SDK 运行时库，为 `_teleop/xr_client.so` 提供设备驱动支持                              |

---

## 3. CLI 命令行工具

安装后通过 `xarm` 命令使用，提供以下子命令：`install` / `init` / `setup-can` / `check` / `collect`。

### 3.1 `xarm install` — 安装运行依赖

```bash
xarm install
```

运行 wheel 内置的 `install.sh`，自动完成系统依赖（can-utils）、CAN 驱动（peak_usb）、conda/pip 依赖、以及从源码编译安装 `xrobotoolkit_sdk`。

> **前置条件：** 需先 `conda activate <env>` 激活一个 conda 环境；仅在 Ubuntu 22.04 / 24.04 测试过，其他版本会提示确认。

### 3.2 `xarm init` — 生成配置文件

```bash
xarm init --output my_config.yaml
```

|     参数   |       默认值	    | 	  说明      |
|------------|--------------------|-----------------|
| `--output` | `xarm_config.yaml` | 配置文件输出路径 |

生成配置模板后，根据实际硬件修改其中的参数。

### 3.3 `xarm setup-can` — 配置 CAN 接口

```bash
# 方式 1：根据配置文件自动配置
xarm setup-can --config my_config.yaml

# 方式 2：手动指定接口
xarm setup-can --interfaces can2 can3
```

|      参数 	  | 	      说明 		|
|----------------|------------------------------|
| `--config`     | 从配置文件读取 CAN 接口名      |
| `--interfaces` | 手动指定接口（如 `can2 can3`） |

需要 `sudo` 权限。执行后会将指定 CAN 接口配置为 **CAN FD**（仲裁 1 Mbps / 数据 5 Mbps）并置为 UP。未显式指定时默认接口为 `can2`、`can3`。

### 3.4 `xarm check` — 检查环境

```bash
xarm check --config my_config.yaml
```

|        参数 	           |     说明     |
|--------------------|--------------|
| `--config`（必填） | 配置文件路径  |

输出示例：

```text
=== CAN interfaces ===
  ✅ can2: UP
  ✅ can3: UP
=== Dependencies ===
  ✅ xarm_can
  ✅ xrobotoolkit_sdk
  ✅ mink
  ✅ mujoco
  ✅ rclpy
```

### 3.5 `xarm collect` — 启动数据采集

```bash
xarm collect --config my_config.yaml
```

|        参数 	         |      说明    |
|-------------------|--------------|
| `--config`（必填）| 配置文件路径  |

该命令会按顺序启动三个节点（前一个就绪后才启动下一个，任一节点异常退出会自动停止全部并失能电机）：

1. **hardware_node** — 硬件控制节点，初始化电机并移动到初始位姿，等待 `/dual_xarm/joints` 话题就绪
2. **teleop_node** — VR 遥操作节点，连接 VR 设备并加载仿真模型，等待 `/dual_xarm/action/joints_position` 话题就绪
3. **recorder_node** — 数据采集节点，开始按帧率录制

按 **q** 停止采集并保存数据集，不要通过 **Ctrl + C** 停止，可能会损坏数据集。

---

## 4. 配置文件说明

配置文件由 `xarm init` 生成，分为三个部分：

### 4.1 `robot` — 机器人硬件参数

| 	   字段 	  |   类型    |                默认值		           |              说明 		|
|------------------------|----------|----------------------------------------|----------------------------------|
| `left_can` 		 | str      | `"can2"` 				     | 左臂 CAN 接口名 			|
| `right_can` 		 | str 	    | `"can3"` 				     | 右臂 CAN 接口名		                  |
| `control_rate_hz`	 | int 	    | `200` 				     | 硬件控制频率（Hz） 		|
| `kp` 			 | float[8] | `[280, 280, 240, 240, 35, 35, 35, 10]` | MIT 位置环增益（7 关节 + 1 夹爪） |
| `kd` 			 | float[8] | `[20, 20, 10, 20, 1.2, 1.2, 1.2, 0.2]` | MIT 速度环增益 			|
| `init_joint_pos_left`  | float[7] | 见默认配置 			           | 左臂初始关节位姿（rad） 		|
| `init_joint_pos_right` | float[7] | 见默认配置			           | 右臂初始关节位姿（rad） 		|
| `gripper_open` 	 | float    | `-1.1`				     | 夹爪打开位置（rad） 		|
| `gripper_close` 	 | float    | `0.0` 				     | 夹爪关闭位置（rad） 		|

**调参建议：** `kp`/`kd` 从小值开始逐步增大，避免电机过冲或振荡。

### 4.2 `teleop` — VR 遥操作参数

|         字段	                |  类型 | 默认值 |               说明			  |
|----------------------|-------|-------|-----------------------------------------|
| `filter_alpha`       | float | `0.5` | EMA 平滑系数（0~1，越小越平滑，延迟越大） |
| `scale_factor`       | float | `1.0` | VR 手柄位移缩放比例			  |
| `reset_duration_sec` | float | `3.0` | 按 A/X 键复位的 S 曲线时长（秒）		  |

### 4.3 `collection` — 数据采集参数

| 	字段 	       | 类型 | 	   默认值	         | 			   说明 		            |
|------------------|------|-------------------------|------------------------------------------------|
| `dataset_path`   | str  | `"~/lerobot_datasets"`  | 数据集存储根目录			                              |
| `repo_id` 	   | str  | `"xarm/pick_and_place"` | LeRobot 数据集 ID（用户名/数据集名） 	            |
| `task_name` 	   | str  | `"pick_and_place"`	    | 任务名称 					            |
| `num_episodes`   | int  | `50`		    | 采集轮次数 				            |
| `record_rate_hz` | int  | `30` 		    | 采集帧率（Hz）				            |
| `arm_side` 	   | str  | `"dual_arm"` 	    | 采集模式：`right_arm` / `left_arm` / `dual_arm` |
| `cameras` 	   | dict | 见默认配置		         | 相机话题配置 				            |

`cameras` 示例：

```yaml
cameras:
  chest:
    topic:   /cam_chest/cam_chest/color/image_raw
    enabled: true
  wrist_right:
    topic:   /cam_wrist_right/cam_wrist_right/color/image_rect_raw
    enabled: false
  wrist_left:
    topic:   /cam_wrist_left/cam_wrist_left/color/image_rect_raw
    enabled: false
```

---

## 5. 数据采集流程

### 5.1 节点启动顺序

`xarm collect` 按以下顺序启动并等待就绪（前一个节点的话题就绪后才启动下一个）：

1. **hardware_node** — 初始化电机，使能并移动到初始位姿，开始控制循环（等待 `/dual_xarm/joints`）
2. **teleop_node** — 连接 VR 设备，加载仿真模型，开始发布关节目标（等待 `/dual_xarm/action/joints_position`）
3. **recorder_node** — 开始按帧率采集数据

### 5.2 ROS2 话题

| 		  话题 			       | 	    类型 	  | 	  方向 		|    说明      |
|------------------------------------------|---------------------|----------------------|--------------|
| `/dual_xarm/joints`                      | `Float64MultiArray` | teleop → hardware   | 关节控制目标 |
| `/dual_xarm/gripperpos`		   | `Float64MultiArray` | teleop → hardware   | 夹爪位置目标 |
| `/dual_xarm/action/joints_position` 	   | `Float64MultiArray` | teleop → recorder   | 动作记录     |
| `/dual_xarm/observation/joints_position` | `Float64MultiArray` | hardware → recorder | 观测记录     |

---

## 6. 常见问题排查
完整操作示例：

```bash
# 1. 创建并激活 conda 环境
conda create -n xarm python=3.10 -y
conda activate xarm

# 2. 安装 wheel
pip install <whl 文件名>
如：
pip install x1_vr_sdk-1.0.0-py3-none-any.whl

# 3. 安装运行依赖（运行 wheel 内置的 install.sh）
xarm install

# 4. 生成配置（只需执行一次）
xarm init --output my_config.yaml

# 5. 修改配置（按实际硬件调整 CAN 接口名、控制参数等）
vim my_config.yaml

# 6. 检查环境
xarm check --config my_config.yaml

# 7. 配置 CAN 接口
xarm setup-can --config my_config.yaml

# 8. 开始采集（每个新终端先 source /opt/ros/humble/setup.bash）
xarm collect --config my_config.yaml

# 9. 卸载 wheel
pip uninstall x1_vr_sdk-1.0.0-py3-none-any.whl
```





## 7. 常见问题排查

### 7.1 `pip install` 失败

检查：

1. Python 版本是否 >= 3.10
2. 平台是否为 x86_64 Linux
3. 是否存在同名已安装包冲突（`pip uninstall xarm_sdk` 后重试）

### 7.2 `xarm check` 报 CAN 接口未 UP

检查：

1. USB-CAN 适配器是否正确连接
2. CAN 接口是否存在：`ip link show can2`
3. 运行 `xarm setup-can --config my_config.yaml`

### 7.3 `xarm check` 报依赖缺失

绝大多数依赖由 `xarm install` 一次性安装，若仍报缺失可按下表逐项处理：

1. `xarm_can`	             ：已随 wheel 打包在 `xarm/_vendor/`，正常无需单独安装；若报缺失，确认是否激活了正确的  conda 环境
2. `xrobotoolkit_sdk` ：由 `xarm install` 从源码编译安装；若失败，检查 `git` / 编译工具链是否就绪
3. `mink` / `mujoco`   ：`pip install mink mujoco`
4. `rclpy`	            ：需在 ROS2 环境中运行（`source /opt/ros/humble/setup.bash`，每个新终端都要执行）

### 7.4 VR 头显连不上 PC（在头显里输入正确  IP 无法连接）

前提：VR 头显与运行 PC 连接**同一 WiFi**，PC 上已启动 XRoboToolkit PC Service。PC 服务对外监听端口为 **63901**（VR 连接用），本机内部端口为 60061。

按以下顺序排查（覆盖绝大多数情况）：

**1. PC 防火墙拦截了 63901 端口（最常见）**

Ubuntu 的 `ufw` 默认会拦截外部连入，导致本机能连、VR 连不上。

```bash
sudo ufw status                 # 查看是否 active、是否放行 63901
sudo ufw allow 63901/tcp        # 放行 VR 端口
# 或在可信内网中直接关闭防火墙：
sudo ufw disable
```

**2. 确认在 VR 里填的是 PC 的 WiFi 网卡 IP**

```bash
hostname -I                     # 取 192.168.x.x 这类局域网地址
ip addr show                    # 找 wlan*/wlp* 网卡下的 inet
```

**3. 确认 PC 服务确实对外监听**

```bash
sudo ss -tlnp | grep -i robotics
```

正常应看到 `*:63901`（绑所有网卡）。若 63901 显示为 `127.0.0.1:63901`（仅本机），需在 XRoboToolkit 服务设置中把监听地址改为 `0.0.0.0`。

**4. 路由器客户端隔离 / 代理软件劫持路由**

- 用另一台同 WiFi 设备 `ping 192.168.x.x` 验证连通性；不通则关闭路由器的「AP 隔离 / 客户端隔离」，并确认两端在同一网段。
- 若 `hostname -I` 中出现 `198.18.x.x` 之类地址，说明 PC 上运行了代理/VPN 的 TUN 模式（如 Clash/v2ray），会劫持局域网路由导致连不上——关闭其 TUN/系统代理后再试。

**5. 其他**

- XRoboToolkit APK 是否已在头显上安装并启动
- 运行环境中 `libPXREARobotSDK.so` 是否可加载（已随 wheel 打包在 `xarm/_vendor/`）

### 7.5 电机不动 / 不使能

检查：

1. 配置文件中 `left_can` / `right_can` 是否与实际接口一致。
若  can 接口不一致，可按下面的方法确定 can 接口（前提：使用到的 CAN 接口都已配置成功）：
```bash
# 执行 docs 文件夹中的 setup_can_interfaces.sh 对所有 can 接口进行配置：
cd docs
bash ./setup_can_interfaces.sh

# 对 can0 id 为 008 的电机（夹爪）发送使能帧
cansend can0 008#FFFFFFFFFFFFFFFC 

# 对 can1 id 为 008 的电机（夹爪）发送使能帧
cansend can1 008#FFFFFFFFFFFFFFFC  

# 对 can2 id 为 008 的电机（夹爪）发送使能帧
cansend can2 008#FFFFFFFFFFFFFFFC  

# 对 can3 id 为 008 的电机（夹爪）发送使能帧
cansend can3 008#FFFFFFFFFFFFFFFC   

# 若发送指令后对应的夹爪电机使能（由红灯常亮 -> 绿灯常亮），则确定左右臂 CAN 接口

```
 
2. 电机是否处于可控模式

### 7.6 数据采集无输出

检查：

1. ROS2 数据采集话题是否存在：`ros2 topic list`
期望看到：

/dual_xarm/action/joints_position
/dual_xarm/observation/joints_position
/cam_chest/cam_chest/color/image_raw

2. ROS2 话题是否有数据：`ros2 topic echo /dual_xarm/observation/joints_position`
3. `dataset_path` 目录是否存在且可写
4. 相机配置中 `enabled` 是否为 `true`，话题名是否正确

---

## 8. 交付清单

| 		文件 		         |					 说明					             |
|-----------------------------------|---------------------------------------------------------------------------------|
| `x1_vr_sdk-1.0.0-py3-none-any.whl` | SDK 安装包（依赖安装脚本 `install.sh` 及所有 `.so` 运行时库均已内置，无需额外文件） |
| `x1_vr_sdk使用文档.md` 	    | 本文档 									             |

> **适用范围** —— 该 wheel 为 **Linux x86_64 + Python 3.10** 编译产物，仅在此环境可用；其他平台/Python 版本需在对应环境重新编译打包。
