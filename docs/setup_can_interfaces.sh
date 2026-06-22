#!/bin/bash

# 批量配置CAN接口的脚本
# 配置CAN0-CAN3接口，设置为CAN-FD模式

echo "配置CAN接口..."

for i in {0..3}; do
    echo "正在配置 can$i..."
    
    # 先关闭接口（如果已经启动）
    sudo ip link set can$i down 2>/dev/null
    
    # 配置CAN接口参数
    sudo ip link set can$i type can bitrate 1000000 dbitrate 5000000 fd on
    
    # 启动接口
    sudo ip link set can$i up
    
    # if [ $? -eq 0 ]; then
    #     echo "can$i 配置成功"
        
    #     # 执行零位设置（如果脚本存在）
    #     if [ -f "./set_zero.sh" ]; then
    #         echo "执行 can$i 零位设置..."
    #         ./set_zero.sh can$i --all
    #     else
    #         echo "警告: set_zero.sh 脚本不存在"
    #     fi
    # else
    #     echo "错误: can$i 配置失败"
    # fi
    
    echo "------------------------"
done

echo "CAN接口配置完成"

# 显示所有CAN接口状态
echo "当前CAN接口状态:"
ip link show | grep can