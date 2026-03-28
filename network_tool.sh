cat > /tmp/network_tool.sh << 'EOF'
#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 配置
DEFAULT_PORT=5202
SERVER_PID_FILE="/tmp/iperf_server.pid"

# 清屏
clear

# 停止所有 iperf3 进程
kill_all_iperf() {
    echo -e "${YELLOW}正在清理所有 iperf3 进程...${NC}"
    
    # 获取所有 iperf3 进程 PID
    PIDS=$(pgrep -f "iperf3" 2>/dev/null)
    
    if [ -n "$PIDS" ]; then
        for pid in $PIDS; do
            echo -e "  停止 PID: $pid"
            kill $pid 2>/dev/null
        done
        sleep 1
        # 强制清理残留
        pkill -9 -f "iperf3" 2>/dev/null
        echo -e "${GREEN}✅ 所有 iperf3 进程已清理${NC}"
    else
        echo -e "${GREEN}✅ 没有发现 iperf3 进程${NC}"
    fi
    
    # 清理 PID 文件
    rm -f "$SERVER_PID_FILE"
    rm -f "/tmp/iperf_port.txt"
}

# 退出时清理
cleanup() {
    echo ""
    echo -e "${YELLOW}退出脚本，清理所有 iperf3 进程...${NC}"
    kill_all_iperf
    echo -e "${GREEN}再见！${NC}"
    exit 0
}

# 捕获退出信号
trap cleanup EXIT INT TERM

# 显示菜单
show_menu() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}      网络测速工具 v3.3${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查是否有 iperf3 进程在运行
    if pgrep -f "iperf3" > /dev/null 2>&1; then
        echo -e "${RED}⚠️  警告: 发现后台有 iperf3 进程在运行${NC}"
        echo -e "${YELLOW}   选择 2 启动监听时会自动清理${NC}"
        echo ""
    fi
    
    echo -e "${GREEN}1.${NC} 安装 iperf3（测速工具）"
    echo -e "${GREEN}2.${NC} 启动监听模式（服务端）"
    echo -e "${GREEN}3.${NC} 停止所有 iperf3 进程"
    echo -e "${GREEN}4.${NC} 启动测速模式（客户端）"
    echo -e "${GREEN}5.${NC} 查看本机 IP"
    echo -e "${GREEN}6.${NC} 快速测试（预设目标）"
    echo -e "${RED}0.${NC} 退出（自动清理所有 iperf3）"
    echo ""
    echo -e "${YELLOW}请选择 [0-6]:${NC} "
}

# 安装 iperf3
install_iperf() {
    echo -e "${BLUE}正在安装 iperf3...${NC}"
    apt update && apt install iperf3 -y
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ iperf3 安装成功！${NC}"
    else
        echo -e "${RED}❌ 安装失败，请检查网络${NC}"
    fi
    echo ""
    read -p "按回车键继续..."
}

# 停止所有 iperf3
stop_all() {
    kill_all_iperf
    echo ""
    read -p "按回车键继续..."
}

# 监听模式（启动前先清理所有旧进程）
start_server() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}启动监听模式${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # 先清理所有旧的 iperf3 进程
    kill_all_iperf
    echo ""
    
    # 获取本机 IP
    local_ipv4=$(curl -4 -s ifconfig.me 2>/dev/null)
    local_ipv6=$(curl -6 -s ifconfig.me 2>/dev/null)
    
    echo -e "${GREEN}本机 IP 信息:${NC}"
    [ -n "$local_ipv4" ] && echo -e "  IPv4: ${CYAN}$local_ipv4${NC}"
    [ -n "$local_ipv6" ] && echo -e "  IPv6: ${CYAN}$local_ipv6${NC}"
    echo ""
    
    echo -e "${GREEN}选择监听协议:${NC}"
    echo "1. IPv4 仅"
    echo "2. IPv6 仅"
    echo "3. 双栈（IPv4+IPv6）"
    read -p "请选择 [1-3]: " proto_choice
    
    read -p "请输入端口 [默认: $DEFAULT_PORT]: " port
    port=${port:-$DEFAULT_PORT}
    
    # 保存端口信息
    echo "$port" > /tmp/iperf_port.txt
    
    # 启动监听
    echo ""
    echo -e "${YELLOW}正在启动监听...${NC}"
    
    case $proto_choice in
        1)
            echo -e "${GREEN}启动 IPv4 监听，端口 $port${NC}"
            nohup iperf3 -s -p $port > /tmp/iperf_server.log 2>&1 &
            echo $! > "$SERVER_PID_FILE"
            echo -e "${GREEN}✅ 服务已启动，PID: $(cat $SERVER_PID_FILE)${NC}"
            echo ""
            echo -e "${MAGENTA}========== 测速命令（复制到客户端执行）==========${NC}"
            echo ""
            echo -e "${CYAN}# 单线程测速（测试基础带宽）${NC}"
            echo "iperf3 -c $local_ipv4 -p $port -t 10"
            echo ""
            echo -e "${CYAN}# 多线程测速（8线程，跑满带宽）${NC}"
            echo "iperf3 -c $local_ipv4 -p $port -t 10 -P 8"
            echo ""
            echo -e "${CYAN}# 反向测速（下载，单线程）${NC}"
            echo "iperf3 -c $local_ipv4 -p $port -t 10 -R"
            echo ""
            echo -e "${CYAN}# UDP 测速（100Mbps）${NC}"
            echo "iperf3 -c $local_ipv4 -p $port -u -b 100M -t 10"
            echo ""
            echo -e "${MAGENTA}================================================${NC}"
            ;;
        2)
            echo -e "${GREEN}启动 IPv6 监听，端口 $port${NC}"
            nohup iperf3 -s -p $port -V > /tmp/iperf_server.log 2>&1 &
            echo $! > "$SERVER_PID_FILE"
            echo -e "${GREEN}✅ 服务已启动，PID: $(cat $SERVER_PID_FILE)${NC}"
            echo ""
            echo -e "${MAGENTA}========== 测速命令（复制到客户端执行）==========${NC}"
            echo ""
            echo -e "${CYAN}# 单线程测速（测试基础带宽）${NC}"
            echo "iperf3 -6 -c $local_ipv6 -p $port -t 10"
            echo ""
            echo -e "${CYAN}# 多线程测速（8线程，跑满带宽）${NC}"
            echo "iperf3 -6 -c $local_ipv6 -p $port -t 10 -P 8"
            echo ""
            echo -e "${CYAN}# 反向测速（下载，单线程）${NC}"
            echo "iperf3 -6 -c $local_ipv6 -p $port -t 10 -R"
            echo ""
            echo -e "${CYAN}# UDP 测速（100Mbps）${NC}"
            echo "iperf3 -6 -c $local_ipv6 -p $port -u -b 100M -t 10"
            echo ""
            echo -e "${MAGENTA}================================================${NC}"
            ;;
        3)
            echo -e "${GREEN}启动双栈监听，端口 $port${NC}"
            nohup iperf3 -s -p $port > /tmp/iperf_server.log 2>&1 &
            echo $! > "$SERVER_PID_FILE"
            echo -e "${GREEN}✅ 服务已启动，PID: $(cat $SERVER_PID_FILE)${NC}"
            echo ""
            echo -e "${MAGENTA}========== 测速命令（复制到客户端执行）==========${NC}"
            echo ""
            echo -e "${CYAN}# IPv4 单线程${NC}"
            echo "iperf3 -c $local_ipv4 -p $port -t 10"
            echo ""
            echo -e "${CYAN}# IPv4 多线程（8线程）${NC}"
            echo "iperf3 -c $local_ipv4 -p $port -t 10 -P 8"
            echo ""
            echo -e "${CYAN}# IPv6 单线程${NC}"
            echo "iperf3 -6 -c $local_ipv6 -p $port -t 10"
            echo ""
            echo -e "${CYAN}# IPv6 多线程（8线程）${NC}"
            echo "iperf3 -6 -c $local_ipv6 -p $port -t 10 -P 8"
            echo ""
            echo -e "${MAGENTA}================================================${NC}"
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}服务正在后台运行${NC}"
    echo -e "${YELLOW}日志文件: /tmp/iperf_server.log${NC}"
    echo -e "${YELLOW}停止服务: 菜单选择 3 或退出脚本自动清理${NC}"
    echo ""
    read -p "按回车键继续..."
}

# 测速模式（客户端，可选择单线程/多线程）
start_client() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}启动测速模式${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # 选择协议
    echo -e "${GREEN}选择协议:${NC}"
    echo "1. IPv4"
    echo "2. IPv6"
    read -p "请选择 [1-2]: " proto_choice
    
    # 输入目标 IP
    if [ $proto_choice -eq 1 ]; then
        read -p "请输入目标 IPv4 地址: " target_ip
        ip_cmd=""
    else
        read -p "请输入目标 IPv6 地址: " target_ip
        ip_cmd="-6"
    fi
    
    read -p "请输入端口 [默认: $DEFAULT_PORT]: " port
    port=${port:-$DEFAULT_PORT}
    
    # 选择测试类型
    echo -e "${GREEN}选择测试类型:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  TCP 测速"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1. TCP 单线程（测试基础带宽）"
    echo "  2. TCP 多线程（4线程）"
    echo "  3. TCP 多线程（8线程，跑满带宽）"
    echo "  4. TCP 多线程（16线程）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  反向测速（下载）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  5. 反向测速（下载，单线程）"
    echo "  6. 反向测速（下载，8线程）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  UDP 测速（测试丢包率）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  7. UDP 100Mbps"
    echo "  8. UDP 500Mbps"
    echo "  9. UDP 1Gbps"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  大窗口测速"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  10. TCP 单线程 + 32MB 窗口"
    echo "  11. TCP 单线程 + 64MB 窗口"
    echo ""
    read -p "请选择 [1-11]: " test_type
    
    read -p "测试时间（秒）[默认: 10]: " duration
    duration=${duration:-10}
    
    # 执行测试
    echo ""
    echo -e "${YELLOW}开始测试...${NC}"
    echo -e "${BLUE}目标: $target_ip:$port${NC}"
    echo -e "${BLUE}测试时间: ${duration}秒${NC}"
    echo ""
    
    case $test_type in
        1)
            echo -e "${CYAN}>>> TCP 单线程测试${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -t $duration
            ;;
        2)
            echo -e "${CYAN}>>> TCP 4线程测试${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -t $duration -P 4
            ;;
        3)
            echo -e "${CYAN}>>> TCP 8线程测试${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -t $duration -P 8
            ;;
        4)
            echo -e "${CYAN}>>> TCP 16线程测试${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -t $duration -P 16
            ;;
        5)
            echo -e "${CYAN}>>> 反向测速（下载，单线程）${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -t $duration -R
            ;;
        6)
            echo -e "${CYAN}>>> 反向测速（下载，8线程）${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -t $duration -R -P 8
            ;;
        7)
            echo -e "${CYAN}>>> UDP 100Mbps 测试${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -u -b 100M -t $duration
            ;;
        8)
            echo -e "${CYAN}>>> UDP 500Mbps 测试${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -u -b 500M -t $duration
            ;;
        9)
            echo -e "${CYAN}>>> UDP 1Gbps 测试${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -u -b 1G -t $duration
            ;;
        10)
            echo -e "${CYAN}>>> TCP 单线程 + 32MB 窗口${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -t $duration -w 32M
            ;;
        11)
            echo -e "${CYAN}>>> TCP 单线程 + 64MB 窗口${NC}"
            iperf3 $ip_cmd -c $target_ip -p $port -t $duration -w 64M
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
}

# 查看本机 IP
show_ip() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}本机 IP 信息${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    echo -e "${GREEN}IPv4:${NC}"
    ipv4=$(curl -4 -s ifconfig.me 2>/dev/null)
    echo "  $ipv4"
    echo ""
    
    echo -e "${GREEN}IPv6:${NC}"
    ipv6=$(curl -6 -s ifconfig.me 2>/dev/null)
    echo "  $ipv6"
    echo ""
    
    echo -e "${GREEN}所有网卡 IP:${NC}"
    ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print "  IPv4: " $2}'
    ip addr show | grep "inet6" | grep -v "::1" | grep -v "fe80" | awk '{print "  IPv6: " $2}'
    
    echo ""
    read -p "按回车键继续..."
}

# 快速测试（预设目标，区分单线程/多线程）
quick_test() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}快速测试${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    echo -e "${GREEN}选择测试目标:${NC}"
    echo "1. 日本 IPv6（1G+ 线路）"
    echo "2. 电信 IPv6（900M 线路）"
    echo "3. IPv4 测试点（455M 线路）"
    echo "4. 自定义目标"
    read -p "请选择 [1-4]: " target_choice
    
    case $target_choice in
        1)
            target="2403:18c0:1000:1e2:3863:73ff:fe54:d076"
            proto="-6"
            name="日本 IPv6"
            ;;
        2)
            target="240e:96c:7100:1fe:185:68f3:195c:ff98"
            proto="-6"
            name="电信 IPv6"
            ;;
        3)
            target="154.31.112.165"
            proto=""
            name="IPv4 测试点"
            ;;
        4)
            read -p "请输入目标 IP: " target
            read -p "IPv4 还是 IPv6? [4/6]: " ipv
            if [ "$ipv" == "6" ]; then
                proto="-6"
            else
                proto=""
            fi
            name="自定义"
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}选择测试类型:${NC}"
    echo "1. 单线程测试（基础带宽）"
    echo "2. 多线程测试（8线程，跑满带宽）"
    read -p "请选择 [1-2]: " thread_choice
    
    read -p "测试时间（秒）[默认: 10]: " duration
    duration=${duration:-10}
    
    echo ""
    echo -e "${YELLOW}测试 $name: $target${NC}"
    echo ""
    
    # 先 ping 测试
    if [ "$proto" == "-6" ]; then
        echo -e "${BLUE}Ping 测试:${NC}"
        ping6 -c 2 $target 2>/dev/null | tail -2
        echo ""
    else
        echo -e "${BLUE}Ping 测试:${NC}"
        ping -c 2 $target 2>/dev/null | tail -2
        echo ""
    fi
    
    # 测速
    if [ $thread_choice -eq 1 ]; then
        echo -e "${BLUE}单线程测速:${NC}"
        iperf3 $proto -c $target -p $DEFAULT_PORT -t $duration 2>/dev/null | grep -E "sender|receiver" | tail -2
    else
        echo -e "${BLUE}多线程测速 (8线程):${NC}"
        iperf3 $proto -c $target -p $DEFAULT_PORT -t $duration -P 8 2>/dev/null | grep -E "SUM|sender" | tail -2
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 主循环
while true; do
    show_menu
    read choice
    case $choice in
        1) install_iperf ;;
        2) start_server ;;
        3) stop_all ;;
        4) start_client ;;
        5) show_ip ;;
        6) quick_test ;;
        0) 
            cleanup
            exit 0
            ;;
        *) 
            echo -e "${RED}无效选择，请重新输入${NC}"
            sleep 1
            ;;
    esac
    clear
done

EOF

chmod +x /tmp/network_tool.sh
/tmp/network_tool.sh
