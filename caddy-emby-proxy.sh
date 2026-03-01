cat <<'EOF' > proxy.sh
#!/bin/bash
# Caddy Manager - V15.3 (True Generic Public Edition)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}错误：${PLAIN} 必须使用 root 用户运行！\n" && exit 1

log() { echo -e "${GREEN}[Info]${PLAIN} $1" > /dev/tty; }
warn() { echo -e "${YELLOW}[Warning]${PLAIN} $1" > /dev/tty; }
error() { echo -e "${RED}[Error]${PLAIN} $1" > /dev/tty; }

# === 写入配置文件 ===
write_config() {
    local DOMAIN=$1; local BACKEND=$2; local MODE=$3; local STREAMS=$4; local KEYWORD=$5
    local FILE="/etc/caddy/conf.d/${DOMAIN}.conf"
    local EMAIL="admin@$DOMAIN"
    local PURE_HOST=$(echo "$BACKEND" | sed -e 's|https://||g' -e 's|http://||g' | cut -d: -f1 | sed 's|/||g')

    if [[ "$MODE" == "1" ]]; then
        cat <<EOM > "$FILE"
$DOMAIN {
    tls $EMAIL
    reverse_proxy $BACKEND {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
    }
}
EOM
    else
        local STREAM_CONFIG=""
        for s in $STREAMS; do [[ -n "$s" ]] && STREAM_CONFIG+="https://$s "; done
        cat <<EOM > "$FILE"
$DOMAIN {
    tls $EMAIL
    header >Location "https://[a-zA-Z0-9.-]+(?:${KEYWORD})[a-zA-Z0-9.-]*" "https://$DOMAIN"
    @video_streams {
        path /videos/* /emby/videos/* /Items/*/Download* /storage/serve*
    }
    handle @video_streams {
        reverse_proxy $STREAM_CONFIG {
            lb_policy round_robin
            header_up Host {http.reverse_proxy.upstream.hostport}
            header_up Referer $BACKEND
            header_up X-Real-IP {remote}
            flush_interval -1
            transport http {
                read_timeout 0
            }
        }
    }
    handle {
        replace {
            re "https://[a-zA-Z0-9.-]+(?:${KEYWORD})[a-zA-Z0-9.-]*" "https://$DOMAIN"
        }
        reverse_proxy $BACKEND {
            header_up Host $PURE_HOST
            header_up Accept-Encoding identity
            header_down -Content-Encoding
        }
    }
}
EOM
    fi
    /usr/bin/caddy validate --config /etc/caddy/Caddyfile && systemctl restart caddy && log "配置已生效！"
}

# === 智能推流节点管理面板 ===
manage_streams() {
    local current_streams=($1)
    while true; do
        echo -e "\n${SKYBLUE}=========== 推流节点管理 ===========${PLAIN}" > /dev/tty
        if [ ${#current_streams[@]} -eq 0 ]; then
            echo -e " ${YELLOW}(当前无节点)${PLAIN}" > /dev/tty
        else
            for i in "${!current_streams[@]}"; do
                echo -e " $((i+1)). ${current_streams[$i]}" > /dev/tty
            done
        fi
        echo -e "------------------------------------" > /dev/tty
        echo -e " 1. 添加新节点" > /dev/tty
        echo -e " 2. 删除指定节点" > /dev/tty
        echo -e " 3. 清空所有节点" > /dev/tty
        echo -e " 0. 保存并返回" > /dev/tty
        read -p "请选择操作 [0-3]: " opt < /dev/tty
        
        case "$opt" in
            1)
                read -p "输入推流域名 (例: stream.example.com): " ns < /dev/tty
                [[ -n "$ns" ]] && current_streams+=("$ns")
                ;;
            2)
                read -p "输入要删除的序号: " di < /dev/tty
                if [[ "$di" =~ ^[0-9]+$ ]] && [ "$di" -ge 1 ] && [ "$di" -le "${#current_streams[@]}" ]; then
                    unset 'current_streams[$((di-1))]'
                    current_streams=("${current_streams[@]}")
                    echo -e "${GREEN}节点已删除${PLAIN}" > /dev/tty
                else
                    echo -e "${RED}输入无效${PLAIN}" > /dev/tty
                fi
                ;;
            3)
                current_streams=()
                echo -e "${YELLOW}节点已全部清空${PLAIN}" > /dev/tty
                ;;
            0)
                echo "${current_streams[@]}"
                return
                ;;
            *)
                echo -e "${RED}输入有误${PLAIN}" > /dev/tty
                ;;
        esac
    done
}

# === 1. 添加站点逻辑 ===
add_site() {
    echo -e "------------------------------------------------" > /dev/tty
    read -p "输入反代域名 (例: emby.example.com): " D < /dev/tty; [[ -z "$D" ]] && return
    read -p "输入主站地址 (例: https://origin.com:443): " B < /dev/tty; [[ -z "$B" ]] && return
    read -p "模式(1.单机反代 2.前后端分离): " M < /dev/tty
    
    if [[ "$M" == "2" ]]; then
        echo -e "${YELLOW}小提醒：填后端链接中包含的特有关键字用于正则替换。如 lilyemby|longemby${PLAIN}" > /dev/tty
        read -p "输入通杀关键字 (多个用|隔开): " K < /dev/tty
        [[ -z "$K" ]] && K="emby" # 默认给个安全的关键字
        S=$(manage_streams "")
        [[ -z "$S" ]] && warn "未添加推流节点，自动降级为单机模式" && M="1"
        write_config "$D" "$B" "$M" "$S" "$K"
    else
        write_config "$D" "$B" "$M" "" ""
    fi
}

# === 2. 修改站点逻辑 ===
edit_site() {
    CONF_FILES=(/etc/caddy/conf.d/*.conf); [[ ! -e "${CONF_FILES[0]}" ]] && warn "无可用站点" && return
    echo -e "${SKYBLUE}>>> 选择要修改的站点：${PLAIN}" > /dev/tty
    for i in "${!CONF_FILES[@]}"; do echo " $((i+1)). $(basename "${CONF_FILES[$i]}" .conf)" > /dev/tty; done
    read -p "请输入序号: " DI < /dev/tty; [[ ! "$DI" =~ ^[0-9]+$ ]] && return
    
    FILE_PATH="${CONF_FILES[$((DI-1))]}"
    D=$(basename "$FILE_PATH" .conf)
    
    CUR_BACKEND=$(grep "reverse_proxy" "$FILE_PATH" | tail -n 1 | awk '{print $2}')
    CUR_STREAMS=$(grep -A 1 "handle @video_streams" "$FILE_PATH" | grep "reverse_proxy" | sed 's/reverse_proxy//g' | sed 's/{//g' | sed 's/https:\/\///g' | xargs)
    # 智能提取当前的关键字
    CUR_KEYWORD=$(grep "re \"https://" "$FILE_PATH" | cut -d'?' -f2 | cut -d')' -f1 | sed 's/^://' | head -n 1)
    
    echo -e "\n${YELLOW}>>> 正在修改: $D${PLAIN}" > /dev/tty
    echo -e "${YELLOW}(小提醒：直接回车即代表不修改当前值)${PLAIN}" > /dev/tty
    read -p "主站地址 [当前: $CUR_BACKEND]: " B < /dev/tty
    [[ -z "$B" ]] && B="$CUR_BACKEND"
    
    if [[ -z "$CUR_STREAMS" ]]; then
        read -p "当前为【单机模式】，是否改为【分离模式】? (y/n): " up < /dev/tty
        if [[ "$up" == "y" ]]; then
            read -p "输入通杀关键字 [例: emby|plex]: " K < /dev/tty; [[ -z "$K" ]] && K="emby"
            S=$(manage_streams "")
            [[ -z "$S" ]] && write_config "$D" "$B" "1" "" "" || write_config "$D" "$B" "2" "$S" "$K"
        else
            write_config "$D" "$B" "1" "" ""
        fi
    else
        read -p "通杀关键字 [当前: ${CUR_KEYWORD}]: " K < /dev/tty
        [[ -z "$K" ]] && K="$CUR_KEYWORD"
        S=$(manage_streams "$CUR_STREAMS")
        [[ -z "$S" ]] && write_config "$D" "$B" "1" "" "" || write_config "$D" "$B" "2" "$S" "$K"
    fi
}

# ================= 主菜单 =================
show_menu() {
    clear
    echo -e "#################################################"
    echo -e "#    Caddy + Emby 终极管理脚本 (发版纯净版)    #"
    echo -e "#################################################"
    echo -e " 1.  安装 / 覆盖 Caddy 环境"
    echo -e " 2.  添加新的反代站点"
    echo -e " 3.  修改现有站点配置 (智能交互面板)"
    echo -e " 4.  删除指定站点配置"
    echo -e " 5.  查看当前所有配置详情"
    echo -e " 6.  查询 Caddy 服务运行状态"
    echo -e " 7.  重启 Caddy 服务"
    echo -e " 8.  查询 80/443 端口占用情况"
    echo -e " 9.  暴力清理端口占用进程"
    echo -e " 10. 彻底卸载 Caddy 程序"
    echo -e " 11. 查看实时运行日志"
    echo -e " 0.  退出管理脚本"
    echo -e "#################################################"
    read -p "请输入指令 [0-11]: " num < /dev/tty
    case "$num" in
        1) systemctl stop caddy 2>/dev/null; curl -L "https://caddyserver.com/api/download?os=linux&arch=amd64&p=github.com%2Fcaddyserver%2Freplace-response" -o /usr/bin/caddy; chmod +x /usr/bin/caddy; log "已安装完毕" ;;
        2) add_site ;;
        3) edit_site ;;
        4) CONF_FILES=(/etc/caddy/conf.d/*.conf); [[ ! -e "${CONF_FILES[0]}" ]] && warn "无可用站点" || (for i in "${!CONF_FILES[@]}"; do echo " $((i+1)). $(basename "${CONF_FILES[$i]}" .conf)"; done; read -p "请输入删除序号: " DI; rm -f "${CONF_FILES[$((DI-1))]}"; systemctl restart caddy; log "站点已删除") ;;
        5) for f in /etc/caddy/conf.d/*.conf; do [[ -e "$f" ]] && { echo -e "\n--- $f ---"; cat "$f"; }; done ;;
        6) systemctl status caddy --no-pager ;;
        7) systemctl restart caddy; log "服务已重启" ;;
        8) netstat -tunlp | grep -E ":80|:443" ;;
        9) killall -9 caddy nginx apache2 2>/dev/null; log "占用端口进程已清理" ;;
        10) systemctl stop caddy; rm -rf /etc/caddy /usr/bin/caddy; log "Caddy 已彻底卸载" ;;
        11) trap 'echo "退出日志模式..." ' INT; journalctl -u caddy -f | grep -v canceled; trap - INT ;;
        0) exit 0 ;;
    esac
}

while true; do show_menu; echo -e "\n按回车键返回主菜单..."; read temp < /dev/tty; done
EOF
chmod +x proxy.sh
bash proxy.sh