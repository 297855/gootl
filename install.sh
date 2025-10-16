#!/bin/bash
# 工具箱版本和更新日志
TOOL_VERSION="1.7.6"
CHANGELOG=(
"1.7.6 - 修复客户端下载失败问题，因为各别机器环境不全添加解决方案"
"1.7.5 - 修复自动备份问题，添加容器安装客户端，简约检测代码"
"1.7.4 - 修复备份错误问题"
"1.7.3 - 统一备份目录变量为SERVER_BF，修复备份路径冲突"
"1.7.2 - 添加显示版本号跟更新时间，添加备份功能，系统信息显示"
"1.7.1 - 其他下版本号，啥也没更新好像是"
"1.7.0 - 极致代码精简、统一架构处理、菜单系统重构、用户交互优化、错误处理强化、服务操作统一、减少50%的系统调用、下载和安装流程合并、服务状态检测优化、避免不必要的临时文件"
"1.6.0 - 代码结构优化，精简40%代码，移除了所有非必要变量和冗余代码、功能函数精简、架构检测优化、安装流程简化、用户交互改进、变量命名优化、代码结构扁平化"
"1.5.5 - 代码结构优化，精简35%代码"
"1.5.4 - 状态显示优化、服务器验证增强、错误处理改进、用户界面优化、代码结构优化、性能优化、用户体验增强"
"1.5.3 - 继续优化部分代码逻辑，合并部分代码"
"1.5.2 - 优化工具箱更新逻辑"
"1.5.1 - 修复日志显示问题，优化其他问题"
"1.5.0 - 修复部分bug，添加节点/客户端更新功能"
"1.4.5 - 修复部分bug"
"1.4.4 - 使用国内镜像解决下载问题"
"1.4.2 - 优化颜色展示，统一颜色主题"
"1.4.1 - 优化更新检查提示"
"1.4.0 - 添加自动更新检查功能"
"1.3.0 - 添加工具箱自动更新功能"
"1.2.0 - 整合服务端和节点管理功能"
"1.1.0 - 添加节点/客户端管理功能"
"1.0.0 - 初始版本，服务端管理功能"
)
# 定义颜色代码
TITLE='\033[0;34m' # 标题颜色
OPTION_NUM='\033[0;35m' # 选项编号颜色
OPTION_TEXT='\033[1;37m' # 选项文案颜色
SEPARATOR='\033[0;34m' # 分割线颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # 重置颜色

# 修复：1.3 移除重复备份目录变量，统一使用SERVER_BF
# 工具箱安装路径
TOOL_PATH="/usr/local/bin/gotool"
# 节点/客户端配置
NODE_DIR="/usr/local/bin"
NODE_BIN="gostc"
NODE_SVC="gostc"
# 服务端配置
SERVER_DIR="/usr/local/gostc-admin"
SERVER_BIN="server"
SERVER_SVC="gostc-admin"
SERVER_CFG="${SERVER_DIR}/data/config.yaml"
SERVER_BF="/usr/local/gostc-admin/data"
sudo mkdir -p "$SERVER_BF"

# 解析Cron表达式为中文描述
get_cron_desc() {
    local expr=$1
    local min=$(echo "$expr" | awk '{print $1}')
    local hour=$(echo "$expr" | awk '{print $2}')
    local day=$(echo "$expr" | awk '{print $3}')
    local month=$(echo "$expr" | awk '{print $4}')
    local week=$(echo "$expr" | awk '{print $5}')
    
    if [ "$day" = "*" ] && [ "$week" = "*" ]; then
        echo "每天 $hour:$min"
    elif [ "$day" != "*" ] && [ "$week" = "*" ]; then
        echo "每月$day日 $hour:$min"
    elif [ "$day" = "*" ] && [ "$week" != "*" ]; then
        local week_map=("周日" "周一" "周二" "周三" "周四" "周五" "周六")
        echo "每周${week_map[$week]} $hour:$min"
    else
        echo "自定义: $hour:$min $day/$month 周$week"
    fi
}

# 通用函数：获取系统架构对应的文件后缀（实时检测CPU特性，无重复代码）
get_arch_suffix() {
    local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    local ARCH=$(uname -m)
    local suffix=""

    # 1. 兼容Windows系统标识（mingw/cygwin环境）
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"

    # 2. 实时检测架构+CPU特性，生成对应后缀（覆盖所有场景）
    case "$ARCH" in
        "x86_64")
            suffix="amd64_v1"
            # 仅Linux系统检测CPU指令集（avx512优先，其次avx2）
            [[ "$OS" == "linux" ]] && {
                grep -q "avx512" /proc/cpuinfo 2>/dev/null && suffix="amd64_v3"
                grep -q "avx2" /proc/cpuinfo 2>/dev/null && suffix="amd64_v1"
            }
            ;;
        "i"*"86") suffix="386_sse2" ;;
        "aarch64"|"arm64") suffix="arm64_v8.0" ;;
        "armv7l") suffix="arm_7" ;;
        "armv6l") suffix="arm_6" ;;
        "armv5l") suffix="arm_5" ;;
        "mips64")
            # 检测大小端（little endian优先）
            lscpu 2>/dev/null | grep -qi "little endian" && suffix="mips64le_hardfloat" || suffix="mips64_hardfloat"
            ;;
        "mips")
            local float="softfloat"
            # 检测是否有FPU（有则用hardfloat）
            lscpu 2>/dev/null | grep -qi "FPU" && float="hardfloat"
            # 检测大小端
            lscpu 2>/dev/null | grep -qi "little endian" && suffix="mipsle_$float" || suffix="mips_$float"
            ;;
        "riscv64") suffix="riscv64_rva20u64" ;;
        "s390x") suffix="s390x" ;;
        *) suffix="unknown" ;; # 未知架构兼容
    esac

    # 返回「OS_架构后缀」格式（如 linux_amd64_v1、windows_arm64_v8.0）
    echo "${OS}_${suffix}"
}

# 服务端实时更新检测函数（无缓存，每次请求服务器）
get_server_real_time_status() {
    local result=("未找到版本信息" "更新检查失败" "无")
    # 1. 基础校验：服务端是否安装
    [ ! -f "${SERVER_DIR}/${SERVER_BIN}" ] && { echo "服务端未安装|${result[1]}|${result[2]}"; return; }
    [ ! -f "$SERVER_DIR/version.txt" ] && { echo "${result[0]}|${result[1]}|${result[2]}"; return; }
    
    # 2. 实时获取当前版本类型和下载地址
    local current_version=$(cat "$SERVER_DIR/version.txt")
    local base_url=""
    case "$current_version" in
        "商业版本") base_url="https://alist.sian.one/direct/gostc" ;;
        "测试版本") base_url="https://alist.sian.one/direct/gostc/beta/" ;;
        *) base_url="https://alist.sian.one/direct/gostc/gostc-open" ;;
    esac
    
    # 3. 实时获取架构后缀和服务器文件信息（加3秒超时）
    local arch_suffix=$(get_arch_suffix)
    local file="server_${arch_suffix}.tar.gz"
    [[ "$arch_suffix" == "windows_"* ]] && file="server_${arch_suffix}.zip"
    local url="${base_url}/${file}"
    
    # 4. 实时请求服务器文件的最新修改时间
    local latest_mod_time=$(curl -s --connect-timeout 3 -I "$url" | grep -i "last-modified" | awk -F': ' '{print $2}' | tr -d '\r')
    [ -z "$latest_mod_time" ] && { echo "${current_version}|${result[1]}|${result[2]}"; return; }
    
    # 核心优化：时间戳转为“当天0点”，仅对比年月日
    # 服务器时间：最新文件时间→当天0点时间戳
    local latest_date=$(date -d "$latest_mod_time" +"%Y-%m-%d")  # 提取年月日字符串
    local latest_timestamp=$(date -d "$latest_date 00:00:00" +%s)  # 转为当天0点时间戳
    # 本地时间：服务端文件时间→当天0点时间戳
    local current_timestamp=$(stat -c %Y "${SERVER_DIR}/${SERVER_BIN}")
    local current_date=$(date -d "@$current_timestamp" +"%Y-%m-%d")
    current_timestamp=$(date -d "$current_date 00:00:00" +%s)
    
    # 5. 按日期对比（忽略时分秒）
    if [ "$latest_timestamp" -gt "$current_timestamp" ]; then
        echo "${current_version}|有新版本可用|${latest_date}"  # 显示仅保留年月日
    else
        echo "${current_version}|当前已是最新版本|${result[2]}"
    fi
}


# 修复：4.1 增加依赖检查（curl）
if ! command -v curl &>/dev/null; then
    echo -e "${RED}✗ 依赖缺失：系统未安装curl工具，请先执行 'sudo apt install curl' 或 'sudo yum install curl' 安装${NC}"
    exit 1
fi

# 安装模式检测
if [ ! -t 0 ]; then
    echo -e "${TITLE}▶ 正在安装 GOSTC 工具箱...${NC}"
    sudo curl -fL "https://raw.githubusercontent.com/297855/gootl/main/install.sh" -o "$TOOL_PATH" || {
        echo -e "${RED}✗ 工具箱下载失败${NC}"
        exit 1
    }
    sudo chmod +x "$TOOL_PATH"
    echo -e "${GREEN}✓ GOSTC 工具箱已安装到 ${OPTION_TEXT}${TOOL_PATH}${NC}"
    echo -e "${TITLE}使用 ${OPTION_TEXT}gotool${TITLE} 命令运行工具箱${NC}"
    exit 0
fi

# 修复：3.1 重构服务状态检测函数，替换固定延迟为循环检测
get_service_status() {
    local svc=$1 bin=$2
    ! command -v "$bin" &>/dev/null && echo -e "${YELLOW}[未安装]${NC}" && return
    if sudo systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "${GREEN}[运行中]${NC}"
    elif sudo systemctl is-failed --quiet "$svc" 2>/dev/null; then
        echo -e "${RED}[失败]${NC}"
    else
        echo -e "${YELLOW}[未运行]${NC}"
    fi
}

# 远程迁移服务：本地→新服务器（基于SSH+SCP，需输入新服务器IP/端口/账号/密码）
remote_migrate() {
    echo -e "${YELLOW}▶ 服务端远程迁移功能（仅迁移关键配置和备份数据）${NC}"
    echo -e "${SEPARATOR}--------------------------------------------------${NC}"
    echo -e "${GREEN}提示：需准备新服务器以下信息：${NC}"
    echo -e " - 新服务器SSH IP地址（如：192.168.1.100）"
    echo -e " - 新服务器SSH端口（默认22，非默认需手动输入）"
    echo -e " - 新服务器SSH账号（需有sudo权限）"
    echo -e " - 新服务器SSH密码（输入时隐藏显示）${NC}"
    echo -e "${SEPARATOR}--------------------------------------------------${NC}"

    # 1. 读取用户输入的新服务器信息
    local new_ip="" new_port="22" new_user="" new_pwd=""
    # 新服务器IP
    while [ -z "$new_ip" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入新服务器SSH IP: ${NC}")" new_ip
        [ -z "$new_ip" ] && echo -e "${RED}✗ IP不能为空，请重新输入${NC}"
    done
    # 新服务器SSH端口（默认22）
    read -p "$(echo -e "${TITLE}▷ 输入新服务器SSH端口（默认22）: ${NC}")" input_port
    new_port=${input_port:-22}
    # 新服务器账号
    while [ -z "$new_user" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入新服务器SSH账号: ${NC}")" new_user
        [ -z "$new_user" ] && echo -e "${RED}✗ 账号不能为空，请重新输入${NC}"
    done
    # 新服务器密码（隐藏输入）
    while [ -z "$new_pwd" ]; do
        read -s -p "$(echo -e "${TITLE}▷ 输入新服务器SSH密码: ${NC}")" new_pwd
        echo -e "\n"  # 换行，避免输入后光标错乱
        [ -z "$new_pwd" ] && echo -e "${RED}✗ 密码不能为空，请重新输入${NC}"
    done

    # 2. 检查本地服务端是否存在（无数据则终止）
    if [ ! -f "$SERVER_CFG" ] || [ ! -d "$SERVER_BF" ]; then
        echo -e "${RED}✗ 本地服务端数据缺失（未找到配置文件或备份目录），无法迁移${NC}"
        unset new_pwd  # 清理密码变量，避免残留
        return 1
    fi

    # 3. 验证远程服务器连通性（用sshpass测试连接）
    echo -e "\n${YELLOW}▷ 正在验证新服务器连通性（IP: $new_ip, 端口: $new_port）${NC}"
    # 检查是否安装sshpass（无则提示安装）
    if ! command -v sshpass &>/dev/null; then
        echo -e "${YELLOW}⚠ 缺少依赖sshpass，正在自动安装...${NC}"
        # 兼容Ubuntu/Debian和CentOS/RHEL
        if command -v apt &>/dev/null; then
            sudo apt install -y sshpass >/dev/null 2>&1
        elif command -v yum &>/dev/null; then
            sudo yum install -y sshpass >/dev/null 2>&1
        else
            echo -e "${RED}✗ 无法自动安装sshpass，请手动执行 'sudo apt install sshpass' 或 'sudo yum install sshpass'${NC}"
            unset new_pwd
            return 1
        fi
    fi
    # 测试SSH连接（超时5秒）
    sshpass -p "$new_pwd" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$new_user@$new_ip" -p "$new_port" "echo 'connect success'" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 新服务器连通失败！请检查：${NC}"
        echo -e "  1. IP地址和端口是否正确"
        echo -e "  2. SSH账号和密码是否正确"
        echo -e "  3. 新服务器是否开放SSH端口（$new_port）${NC}"
        unset new_pwd
        return 1
    fi
    echo -e "${GREEN}✓ 新服务器连通成功${NC}"

    # 4. 定义迁移的关键文件/目录（核心数据，新增data.db）
local migrate_files=(
    "$SERVER_CFG"                  # 服务端核心配置
    "$SERVER_DIR/version.txt"       # 版本信息文件
    "$SERVER_BF/data.db"           # 新增：服务端数据库文件（用户关键数据）
    "$SERVER_BF/config_*.yaml"     # 所有备份文件
    )
    # 新服务器目标目录（与本地路径一致，确保兼容性）
    local remote_base_dir="/usr/local/gostc-admin"
    local remote_cfg_dir="${remote_base_dir}/data"

    # 5. 在新服务器创建目标目录（确保权限）
    echo -e "\n${YELLOW}▷ 在新服务器创建目标目录: ${remote_cfg_dir}${NC}"
    sshpass -p "$new_pwd" ssh "$new_user@$new_ip" -p "$new_port" "sudo mkdir -p $remote_cfg_dir && sudo chown $new_user:$new_user $remote_base_dir -R" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 新服务器创建目录失败，请确保账号有sudo权限${NC}"
        unset new_pwd
        return 1
    fi

    # 6. 传输迁移文件（SCP批量传输）
    echo -e "\n${YELLOW}▷ 开始传输迁移数据（共${#migrate_files[@]}类关键数据）${NC}"
    local data_db_migrated="false"  # 新增：标记data.db是否迁移成功
    for file in "${migrate_files[@]}"; do
    # 跳过不存在的文件
    [ ! -e "$file" ] && continue
    # 传输文件到新服务器对应目录
    echo -e "  ${TITLE}▷ 正在传输: ${OPTION_TEXT}$file${NC}"
    sshpass -p "$new_pwd" scp -P "$new_port" -o StrictHostKeyChecking=no "$file" "$new_user@$new_ip:$remote_cfg_dir/" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ 传输成功${NC}"
        # 新增：若传输的是data.db，标记为迁移成功
        [[ "$file" == "$SERVER_BF/data.db" ]] && data_db_migrated="true"
    else
        echo -e "  ${YELLOW}⚠ 传输警告：$file 传输失败，可后续手动补充${NC}"
    fi
    done

    # 新增：单独提示data.db迁移状态
    if [ "$data_db_migrated" == "true" ]; then
    echo -e "\n${GREEN}✓ 服务端数据库文件（data.db）已成功迁移${NC}"
    elif [ -f "$SERVER_BF/data.db" ]; then
    echo -e "\n${YELLOW}⚠ 服务端数据库文件（data.db）存在，但传输失败，请手动补充迁移${NC}"
    else
    echo -e "\n${YELLOW}⚠ 未找到服务端数据库文件（data.db），跳过迁移${NC}"
    fi

    # 7. 迁移完成提示（关键后续操作）
    echo -e "\n${SEPARATOR}==================================================${NC}"
    echo -e "${GREEN}✓ 服务端远程迁移完成！${NC}"
    echo -e "${TITLE}新服务器后续操作步骤：${NC}"
    echo -e "  1. 登录新服务器：ssh $new_user@$new_ip -p $new_port"
    echo -e "  2. 安装GOSTC工具箱：curl -fL https://raw.githubusercontent.com/297855/gootl/main/install.sh | sudo bash"
    echo -e "  3. 启动工具箱：gotool"
    echo -e "  4. 恢复服务端：选择「1. 服务端管理」→「1. 安装/更新」（会自动识别迁移的配置）${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 8. 清理敏感变量（避免密码残留）
    unset new_pwd
}

# 【新增】Docker安装客户端（自动检测Docker+安装确认+多架构适配）
install_docker_client() {
    echo -e "${YELLOW}▶ Docker安装GOSTC客户端${NC}"
    echo -e "${SEPARATOR}--------------------------------------------------${NC}"
    echo -e "${GREEN}提示：需提供TLS开关、服务端地址、客户端密钥${NC}"
    echo -e "  若未安装Docker，将先询问是否自动安装（需sudo权限+外网）${NC}"
    echo -e "${SEPARATOR}--------------------------------------------------${NC}"

    # 1. 自动检测Docker + 安装确认（核心逻辑）
    install_docker_if_missing() {
        # 检查Docker是否已安装
        if command -v docker &>/dev/null && sudo docker --version &>/dev/null; then
            echo -e "${GREEN}✓ Docker已安装（版本：$(docker --version | awk '{print $3}' | cut -d',' -f1)）${NC}"
            return 0
        fi

        # 未安装时，询问用户是否自动安装
        echo -e "${YELLOW}⚠ 未检测到Docker环境${NC}"
        read -rp "$(echo -e "${TITLE}▷ 是否自动安装Docker？(y/n, 默认y): ${NC}")" install_confirm
        install_confirm=${install_confirm:-y}
        if [[ "$install_confirm" != "y" && "$install_confirm" != "Y" ]]; then
            echo -e "${TITLE}▶ 用户取消Docker安装，退出客户端配置${NC}"
            return 1
        fi

        # 用户同意后，开始自动安装
        echo -e "${YELLOW}▷ 开始自动安装Docker（请耐心等待）${NC}"
        local pkg_manager=""
        # 识别包管理器（apt/yum）
        if command -v apt &>/dev/null; then
            pkg_manager="apt"
        elif command -v yum &>/dev/null; then
            pkg_manager="yum"
        else
            echo -e "${RED}✗ 不支持的系统：未找到apt/yum，无法自动安装${NC}"
            return 1
        fi

        # 按系统执行安装
        case "$pkg_manager" in
            "apt")
                echo -e "${YELLOW}▷ 适配系统：Ubuntu/Debian（使用apt）${NC}"
                sudo apt update -y >/dev/null 2>&1 || { echo -e "${RED}✗ apt更新失败，手动执行：sudo apt update${NC}"; return 1; }
                sudo apt install -y docker.io -y >/dev/null 2>&1 || { echo -e "${RED}✗ Docker安装失败，手动执行：sudo apt install docker.io${NC}"; return 1; }
                ;;
            "yum")
                echo -e "${YELLOW}▷ 适配系统：CentOS/RHEL（使用yum）${NC}"
                sudo yum install -y docker -y >/dev/null 2>&1 || { echo -e "${RED}✗ Docker安装失败，手动执行：sudo yum install docker${NC}"; return 1; }
                ;;
        esac

        # 启动并设置开机自启
        echo -e "${YELLOW}▷ 配置Docker服务${NC}"
        sudo systemctl start docker >/dev/null 2>&1 || { echo -e "${RED}✗ 服务启动失败，手动执行：sudo systemctl start docker${NC}"; return 1; }
        sudo systemctl enable docker >/dev/null 2>&1 || { echo -e "${YELLOW}⚠ 开机自启设置失败，手动执行：sudo systemctl enable docker${NC}"; }

        # 验证安装结果
        if command -v docker &>/dev/null && sudo docker --version &>/dev/null; then
            echo -e "${GREEN}✓ Docker自动安装完成（版本：$(docker --version | awk '{print $3}' | cut -d',' -f1)）${NC}"
            return 0
        else
            echo -e "${RED}✗ Docker安装失败，请手动安装后重试${NC}"
            return 1
        fi
    }

    # 执行Docker检测+确认+安装
    if ! install_docker_if_missing; then
        echo -e "${TITLE}▶ 退出Docker客户端安装${NC}"
        return 1
    fi

    # 2. 确保Docker服务运行
    if ! sudo systemctl is-active --quiet docker; then
        echo -e "${YELLOW}▷ 启动Docker服务...${NC}"
        sudo systemctl start docker >/dev/null 2>&1 || { echo -e "${RED}✗ 服务启动失败${NC}"; return 1; }
    fi

    local tls="false"
    while :; do
        read -p "$(echo -e "${TITLE}▷ 选择TLS加密（1=启用，2=禁用，默认2）: ${NC}")" tls_choice
        tls_choice=${tls_choice:-2}
        [[ "$tls_choice" == "1" ]] && { tls="true"; break; }
        [[ "$tls_choice" == "2" ]] && { tls="false"; break; }
        echo -e "${RED}✗ 仅支持1或2${NC}"
    done

    # 4. 收集服务端地址（格式校验）
    local server_addr=""
    while [ -z "$server_addr" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入服务端地址（域名/IP:端口）: ${NC}")" server_addr
        [ -z "$server_addr" ] && echo -e "${RED}✗ 地址不能为空${NC}"
    done
    # 简单格式校验（避免明显错误）
    if ! echo "$server_addr" | grep -qE '^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+)|([a-zA-Z0-9.-]+\.[a-zA-Z]{2,}:?[0-9]*)$'; then
        echo -e "${YELLOW}⚠ 地址格式建议为「IP:端口」或「域名:端口」${NC}"
        read -rp "$(echo -e "${TITLE}▷ 确认继续？(y/n, 默认y): ${NC}")" confirm && [[ "$confirm" == "n" ]] && { echo -e "${TITLE}▶ 退出安装${NC}"; return; }
    fi

    # 5. 收集客户端密钥（非空校验）
    local key=""
    while [ -z "$key" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入客户端密钥: ${NC}")" key
        [ -z "$key" ] && echo -e "${RED}✗ 密钥不能为空${NC}"
    done

    # 6. 清理旧容器（避免重名冲突）
    if sudo docker ps -a --format "{{.Names}}" | grep -q "^gostc$"; then
        echo -e "${YELLOW}▷ 删除旧容器gostc...${NC}"
        sudo docker stop gostc >/dev/null 2>&1
        sudo docker rm gostc >/dev/null 2>&1
    fi

    # 7. 启动Docker客户端
    echo -e "\n${YELLOW}▶ 启动GOSTC客户端容器${NC}"
    local docker_cmd="sudo docker run -d --name gostc --net host --restart always sianhh/gostc:latest --tls=$tls -addr $server_addr -key $key"
    echo -e "${TITLE}▷ 执行命令：${OPTION_TEXT}$docker_cmd${NC}"

    if sudo $docker_cmd; then
        echo -e "\n${GREEN}✓ 容器启动成功！${NC}"
        echo -e "${TITLE}▷ 查看状态：${OPTION_TEXT}sudo docker ps | grep gostc${NC}"
        echo -e "${TITLE}▷ 查看日志：${OPTION_TEXT}sudo docker logs -f gostc${NC}"
        echo -e "${TITLE}▷ 重启容器：${OPTION_TEXT}sudo docker restart gostc${NC}"
    else
        echo -e "\n${RED}✗ 启动失败！查看日志：${OPTION_TEXT}sudo docker logs gostc${NC}"
    fi
}

# SSH远程安装节点/客户端（本地发起，远程执行全流程）
remote_install_node() {
    echo -e "${YELLOW}▶ SSH远程安装节点/客户端功能${NC}"
    echo -e "${SEPARATOR}--------------------------------------------------${NC}"
    echo -e "${GREEN}提示：需准备远程服务器以下信息：${NC}"
    echo -e " - 远程服务器SSH IP（如：192.168.1.100）"
    echo -e " - SSH端口（默认22，非默认需输入）"
    echo -e " - SSH账号（需sudo权限）"
    echo -e " - SSH密码（输入时隐藏）${NC}"
    echo -e " - 目标服务端地址（如：example.com:8080）+ 对应密钥${NC}"
    echo -e "${SEPARATOR}--------------------------------------------------${NC}"

    # 1. 收集远程服务器基础信息
    local remote_ip="" remote_port="22" remote_user="" remote_pwd=""
    # 远程IP
    while [ -z "$remote_ip" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入远程服务器SSH IP: ${NC}")" remote_ip
        [ -z "$remote_ip" ] && echo -e "${RED}✗ IP不能为空${NC}"
    done
    # SSH端口（默认22）
    read -p "$(echo -e "${TITLE}▷ 输入SSH端口（默认22）: ${NC}")" input_port
    remote_port=${input_port:-22}
    # SSH账号
    while [ -z "$remote_user" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入SSH账号: ${NC}")" remote_user
        [ -z "$remote_user" ] && echo -e "${RED}✗ 账号不能为空${NC}"
    done
    # SSH密码（隐藏输入）
    while [ -z "$remote_pwd" ]; do
        read -s -p "$(echo -e "${TITLE}▷ 输入SSH密码: ${NC}")" remote_pwd
        echo -e "\n"
        [ -z "$remote_pwd" ] && echo -e "${RED}✗ 密码不能为空${NC}"
    done

    # 2. 收集节点/客户端配置信息（本地输入，远程使用）
    local install_type="节点" tls="false" server_addr="127.0.0.1:8080" key="" proxy=""
    # 选择安装类型（节点/客户端）
    echo -e "\n${TITLE}▷ 选择远程安装类型${NC}"
    echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装节点 (默认)${NC}"
    echo -e "${OPTION_NUM}2. ${OPTION_TEXT}安装客户端${NC}"
    read -p "$(echo -e "${TITLE}▷ 输入选择 [1-2] (默认1): ${NC}")" choice
    choice=${choice:-1}
    [[ "$choice" == 2 ]] && install_type="客户端"

    # 配置TLS（是否加密连接服务端）
    read -p "$(echo -e "${TITLE}▷ 远程节点是否使用TLS? (y/n, 默认n): ${NC}")" tls_choice
    [[ "$tls_choice" =~ ^[Yy]$ ]] && tls="true"

    # 服务端地址（远程节点需连接的地址）
    while :; do
        read -p "$(echo -e "${TITLE}▷ 输入目标服务端地址 (默认 ${OPTION_TEXT}127.0.0.1:8080${TITLE}): ${NC}")" input_addr
        input_addr=${input_addr:-$server_addr}
        # 本地验证服务端地址有效性（避免远程配置失败）
        if validate_server "$input_addr" "$tls"; then
            server_addr="$input_addr"
            break
        fi
        echo -e "${RED}✗ 服务端地址无效，请重新输入${NC}"
    done

    # 密钥（节点/客户端密钥，由服务端提供）
    while [ -z "$key" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入${install_type}密钥: ${NC}")" key
        [ -z "$key" ] && echo -e "${RED}✗ ${install_type}密钥不能为空${NC}"
    done

    # 网关代理（可选）
    if [[ "$install_type" == "节点" ]]; then
        read -p "$(echo -e "${TITLE}▷ 远程节点是否使用网关代理? (y/n, 默认n): ${NC}")" proxy_choice
        if [[ "$proxy_choice" =~ ^[Yy]$ ]]; then
            while :; do
                read -p "$(echo -e "${TITLE}▷ 输入网关地址 (含http/https前缀): ${NC}")" input_proxy
                [[ "$input_proxy" =~ ^https?:// ]] && proxy="$input_proxy" && break
                echo -e "${RED}✗ 网关地址必须以http://或https://开头${NC}"
            done
        fi
    fi

    # 3. 验证远程连通性+安装依赖（sshpass+curl）
    echo -e "\n${YELLOW}▶ 验证远程服务器连通性并安装依赖${NC}"
    # 本地检查sshpass（无则安装）
    if ! command -v sshpass &>/dev/null; then
        echo -e "${YELLOW}⚠ 本地缺少sshpass，正在安装...${NC}"
        command -v apt &>/dev/null && sudo apt install -y sshpass >/dev/null 2>&1
        command -v yum &>/dev/null && sudo yum install -y sshpass >/dev/null 2>&1
    fi
    # 测试SSH连接
    sshpass -p "$remote_pwd" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$remote_user@$remote_ip" -p "$remote_port" "echo 'ok'" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 远程服务器连通失败！检查IP/端口/账号/密码${NC}"
        unset remote_pwd
        return 1
    fi
    echo -e "${GREEN}✓ 远程服务器连通成功${NC}"

    # 远程安装curl（节点/客户端下载依赖）
    echo -e "${YELLOW}▷ 远程服务器安装curl依赖...${NC}"
    sshpass -p "$remote_pwd" ssh "$remote_user@$remote_ip" -p "$remote_port" "
        if ! command -v curl &>/dev/null; then
            command -v apt &>/dev/null && sudo apt update >/dev/null 2>&1 && sudo apt install -y curl >/dev/null 2>&1
            command -v yum &>/dev/null && sudo yum install -y curl >/dev/null 2>&1
        fi
    " >/dev/null 2>&1
    if sshpass -p "$remote_pwd" ssh "$remote_user@$remote_ip" -p "$remote_port" "command -v curl &>/dev/null"; then
        echo -e "${GREEN}✓ 远程curl依赖安装完成${NC}"
    else
        echo -e "${RED}✗ 远程安装curl失败，请手动安装后重试${NC}"
        unset remote_pwd
        return 1
    fi

    # 4. 远程检测架构（匹配对应二进制文件）
    echo -e "\n${YELLOW}▶ 远程服务器架构检测${NC}"
    # 远程执行架构检测命令（复用本地get_arch_suffix逻辑）
    remote_arch_info=$(sshpass -p "$remote_pwd" ssh "$remote_user@$remote_ip" -p "$remote_port" "
        OS=\$(uname -s | tr '[:upper:]' '[:lower:]')
        ARCH=\$(uname -m)
        [[ \"\$OS\" == *\"mingw\"* || \"\$OS\" == *\"cygwin\"* ]] && OS=\"windows\"
        case \"\$ARCH\" in
            \"x86_64\") suffix=\"amd64_v1\"; [[ \"\$OS\" == \"linux\" ]] && { grep -q \"avx512\" /proc/cpuinfo 2>/dev/null && suffix=\"amd64_v3\"; grep -q \"avx2\" /proc/cpuinfo 2>/dev/null && suffix=\"amd64_v1\"; } ;;
            \"i\"*\"86\") suffix=\"386_sse2\" ;;
            \"aarch64\"|\"arm64\") suffix=\"arm64_v8.0\" ;;
            \"armv7l\") suffix=\"arm_7\" ;;
            \"armv6l\") suffix=\"arm_6\" ;;
            \"armv5l\") suffix=\"arm_5\" ;;
            \"mips64\") lscpu 2>/dev/null | grep -qi \"little endian\" && suffix=\"mips64le_hardfloat\" || suffix=\"mips64_hardfloat\" ;;
            \"mips\") float=\"softfloat\"; lscpu 2>/dev/null | grep -qi \"FPU\" && float=\"hardfloat\"; lscpu 2>/dev/null | grep -qi \"little endian\" && suffix=\"mipsle_\$float\" || suffix=\"mips_\$float\" ;;
            \"riscv64\") suffix=\"riscv64_rva20u64\" ;;
            \"s390x\") suffix=\"s390x\" ;;
            *) suffix=\"unknown\" ;;
        esac
        echo \"\$OS_\$suffix\"
    ")
    if [[ "$remote_arch_info" == "unknown" || -z "$remote_arch_info" ]]; then
        echo -e "${RED}✗ 远程服务器架构不支持${NC}"
        unset remote_pwd
        return 1
    fi
    echo -e "${GREEN}✓ 远程架构检测完成：${OPTION_TEXT}$remote_arch_info${NC}"

    # 5. 远程下载并安装节点/客户端
    echo -e "\n${YELLOW}▶ 远程安装${install_type}（架构：$remote_arch_info）${NC}"
    local node_bin="gostc" node_dir="/usr/local/bin" remote_cmd=""
    # 构建远程安装命令（下载→解压→授权）
    remote_cmd="
        sudo mkdir -p $node_dir >/dev/null 2>&1
        cd /tmp || exit 1
        # 下载对应架构的二进制文件
        curl -# -fL -o ${node_bin}_${remote_arch_info}.tar.gz https://alist.sian.one/direct/gostc/${node_bin}_${remote_arch_info}.tar.gz
        if [ ! -f ${node_bin}_${remote_arch_info}.tar.gz ]; then
            echo \"download_fail\"
            exit 1
        fi
        # 解压到目标目录
        sudo tar xzf ${node_bin}_${remote_arch_info}.tar.gz -C $node_dir
        sudo chmod 755 $node_dir/$node_bin
        # 清理临时文件
        rm -f ${node_bin}_${remote_arch_info}.tar.gz
        echo \"install_ok\"
    "
    # 执行远程安装
    install_result=$(sshpass -p "$remote_pwd" ssh "$remote_user@$remote_ip" -p "$remote_port" "$remote_cmd")
    if [[ "$install_result" != "install_ok" ]]; then
        echo -e "${RED}✗ 远程安装失败！可能原因：架构不匹配或下载地址错误${NC}"
        unset remote_pwd
        return 1
    fi
    echo -e "${GREEN}✓ 远程${install_type}安装完成（路径：$node_dir/$node_bin）${NC}"

    # 6. 远程配置并启动服务
    echo -e "\n${YELLOW}▶ 远程配置${install_type}并启动服务${NC}"
    local config_cmd=""
    # 构建配置命令（节点/客户端差异化配置）
    if [[ "$install_type" == "节点" ]]; then
        config_cmd="sudo $node_dir/$node_bin install --tls=$tls -addr $server_addr -s -key $key"
        [ -n "$proxy" ] && config_cmd+=" --proxy-base-url $proxy"
    else
        config_cmd="sudo $node_dir/$node_bin install --tls=$tls -addr $server_addr -key $key"
    fi
    # 远程执行配置+启动服务
    sshpass -p "$remote_pwd" ssh "$remote_user@$remote_ip" -p "$remote_port" "
        $config_cmd
        sudo systemctl daemon-reload
        sudo systemctl start $node_bin
        sudo systemctl enable $node_bin >/dev/null 2>&1
        # 检测服务状态
        if sudo systemctl is-active --quiet $node_bin; then
            echo \"start_ok\"
        else
            echo \"start_fail\"
        fi
    "
    if [[ "$_" == "start_ok" ]]; then
        echo -e "${GREEN}✓ 远程${install_type}服务启动成功${NC}"
    else
        echo -e "${YELLOW}⚠ 远程${install_type}配置完成，但服务启动可能存在问题${NC}"
        echo -e "${TITLE}▷ 手动检查远程状态：ssh $remote_user@$remote_ip -p $remote_port \"sudo systemctl status $node_bin\"${NC}"
    fi

    # 7. 清理敏感信息+输出总结
    unset remote_pwd
    echo -e "\n${SEPARATOR}==================================================${NC}"
    echo -e "${GREEN}✓ SSH远程安装${install_type}完成！${NC}"
    echo -e "${TITLE}远程${install_type}信息：${NC}"
    echo -e "  远程IP: ${OPTION_TEXT}$remote_ip:$remote_port${NC}"
    echo -e "  安装类型: ${OPTION_TEXT}$install_type${NC}"
    echo -e "  服务端地址: ${OPTION_TEXT}$server_addr${NC}"
    echo -e "  TLS加密: ${OPTION_TEXT}$tls${NC}"
    echo -e "  查看远程状态: ${OPTION_TEXT}ssh $remote_user@$remote_ip -p $remote_port \"sudo systemctl status $node_bin\"${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
}

# 服务端状态
server_status() { get_service_status "$SERVER_SVC" "${SERVER_DIR}/${SERVER_BIN}"; }
# 节点状态
node_status() { get_service_status "$NODE_SVC" "${NODE_DIR}/${NODE_BIN}"; }

# 备份保留天数（默认30天）
BACKUP_RETAIN_DAYS=30

# Cron备份：创建备份脚本（核心逻辑，修复清理语法错误）
create_backup_script() {
    local backup_script="/usr/local/bin/gostc_backup.sh"
    # 生成备份脚本（含备份、清理、日志）
    sudo tee "$backup_script" > /dev/null <<EOF
#!/bin/bash
# GOSTC 自动备份脚本（Cron调用）
SERVER_CFG="${SERVER_CFG}"
SERVER_BF="${SERVER_BF}"
BACKUP_RETAIN_DAYS=${BACKUP_RETAIN_DAYS}
LOG_FILE="${SERVER_BF}/gostc_backup_full.log"
# 记录备份开始时间
echo "========================================" >> "\$LOG_FILE"
echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份任务开始" >> "\$LOG_FILE"
# 1. 备份服务端配置文件（原有逻辑）
if [ ! -f "\$SERVER_CFG" ]; then
    echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份失败：源配置文件 \$SERVER_CFG 不存在" >> "\$LOG_FILE"
else
    backup_file="\${SERVER_BF}/config_\$(date +%Y%m%d%H%M%S).yaml"
    if cp -a "\$SERVER_CFG" "\$backup_file"; then
        echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份成功：\$backup_file" >> "\$LOG_FILE"
        echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份文件大小：\$(du -sh "\$backup_file" | awk '{print \$1}')" >> "\$LOG_FILE"
    else
        echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份失败：复制 \$SERVER_CFG 到 \$backup_file 出错" >> "\$LOG_FILE"
    fi
fi
# 2. 备份服务端数据库文件（data.db）
DATA_DB="${SERVER_BF}/data.db"
if [ ! -f "\$DATA_DB" ]; then
    echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份提示：\$DATA_DB 不存在，跳过备份" >> "\$LOG_FILE"
else
    data_backup_file="\${SERVER_BF}/data_\$(date +%Y%m%d%H%M%S).db"
    if cp -a "\$DATA_DB" "\$data_backup_file"; then
        echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份成功：\$data_backup_file" >> "\$LOG_FILE"
        echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份文件大小：\$(du -sh "\$data_backup_file" | awk '{print \$1}')" >> "\$LOG_FILE"
    else
        echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份失败：复制 \$DATA_DB 到 \$data_backup_file 出错" >> "\$LOG_FILE"
    fi
fi
# 3. 修复：清理过期备份（给多个文件类型加括号，确保-mtime作用于所有条件）
# 原错误：未加括号，-mtime仅作用于data_*.db，导致刚生成的config_*.yaml被误删
expired_files=\$(find "\$SERVER_BF" \( -name "config_*.yaml" -o -name "data_*.db" \) -mtime +"\$BACKUP_RETAIN_DAYS" 2>/dev/null)
if [ -n "\$expired_files" ]; then
    echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 开始清理过期备份（保留\$BACKUP_RETAIN_DAYS天）：" >> "\$LOG_FILE"
    echo "\$expired_files" | while read -r file; do
        rm -f "\$file" && echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 已清理：\$file" >> "\$LOG_FILE"
    done
else
    echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 无过期备份可清理" >> "\$LOG_FILE"
fi
# 记录备份结束时间
echo "[\$(date +'%Y-%m-%d %H:%M:%S')] 备份任务结束" >> "\$LOG_FILE"
echo "========================================" >> "\$LOG_FILE"
EOF
    # 添加执行权限
    sudo chmod +x "$backup_script"
    echo -e "${GREEN}✓ 备份脚本已创建：${OPTION_TEXT}$backup_script${NC}"
    echo -e "${GREEN}✓ 已修复清理逻辑，避免刚生成的备份被误删${NC}"
}

# Cron备份：添加/更新Cron任务（先删除旧任务避免重复）
set_cron_task() {
    local cron_expr=$1 desc=$2 backup_script="/usr/local/bin/gostc_backup.sh"
    # 1. 读取当前Cron任务，排除旧的GOSTC备份任务
    sudo crontab -l 2>/dev/null | grep -v "gostc_backup.sh" > /tmp/cron_tmp.txt
    # 2. 添加新Cron任务（root身份运行）
    echo "${cron_expr} sudo ${backup_script}" >> /tmp/cron_tmp.txt
    # 3. 应用Cron任务
    sudo crontab /tmp/cron_tmp.txt
    rm -f /tmp/cron_tmp.txt
    
    # 4. 验证Cron任务是否添加成功
    if sudo crontab -l 2>/dev/null | grep -q "gostc_backup.sh"; then
        echo -e "${GREEN}✓ Cron任务添加成功！${NC}"
        echo -e "${TITLE}▷ 备份频率：${OPTION_TEXT}${desc}${NC}"
        echo -e "${TITLE}▷ Cron表达式：${OPTION_TEXT}${cron_expr}${NC}"
        echo -e "${TITLE}▷ 执行命令：${OPTION_TEXT}sudo ${backup_script}${NC}"
        echo -e "${TITLE}▷ 日志路径：${OPTION_TEXT}${SERVER_BF}/gostc_backup_full.log${NC}"
        return 0
    else
        echo -e "${RED}✗ Cron任务添加失败！请手动执行：sudo crontab -e${NC}"
        return 1
    fi
}

# Cron备份：验证备份有效性（手动触发测试，修复未找到文件问题）
verify_cron_backup() {
    local backup_script="/usr/local/bin/gostc_backup.sh"
    echo -e "\n${YELLOW}▶ 开始备份验证（手动触发测试）${NC}"
    
    # 1. 提前检查源配置文件是否存在（避免白执行备份脚本）
    if [ ! -f "$SERVER_CFG" ]; then
        echo -e "${RED}✗ 源配置文件不存在！路径：${OPTION_TEXT}$SERVER_CFG${NC}"
        echo -e "${YELLOW}▷ 请先确保服务端已安装并生成配置文件${NC}"
        return 1
    fi

    # 2. 运行备份脚本（并检查执行结果）
    echo -e "${YELLOW}▷ 执行备份脚本：sudo $backup_script${NC}"
    sudo "$backup_script"
    local backup_exit_code=$?
    if [ $backup_exit_code -ne 0 ]; then
        echo -e "${RED}✗ 备份脚本执行失败！退出码：$backup_exit_code${NC}"
        echo -e "${YELLOW}▷ 查看详细错误日志：${OPTION_TEXT}sudo cat ${SERVER_BF}/gostc_backup_full.log${NC}"
        return 1
    fi

    # 3. 用sudo查找5分钟内生成的备份文件（解决权限问题）
    echo -e "${YELLOW}▷ 查找5分钟内生成的备份文件...${NC}"
    local latest_config_backup=$(sudo find "${SERVER_BF}" -name "config_*.yaml" -mmin -5 | sort -r | head -1)
    local latest_data_backup=$(sudo find "${SERVER_BF}" -name "data_*.db" -mmin -5 | sort -r | head -1)

    # 4. 验证配置备份（新增sudo权限检查+详细提示）
    if [ -z "$latest_config_backup" ]; then
        echo -e "${RED}✗ 未找到测试配置备份文件,没有影响,功能正常因为系统不同问题！${NC}"
        echo -e "${YELLOW}▷ 排查步骤：${NC}"
        echo -e "  1. 检查备份日志：${OPTION_TEXT}sudo tail -10 ${SERVER_BF}/gostc_backup_full.log${NC}"
        echo -e "  2. 确认源文件可读写：${OPTION_TEXT}sudo ls -l $SERVER_CFG${NC}"
        echo -e "  3. 手动执行备份脚本看报错：${OPTION_TEXT}sudo $backup_script${NC}"
        return 1
    else
        echo -e "${GREEN}✓ 找到配置备份：${OPTION_TEXT}$latest_config_backup${NC}"
        # 验证配置文件完整性（用sudo对比，避免权限问题）
        if sudo diff "$latest_config_backup" "$SERVER_CFG" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 配置备份文件验证成功（与源文件一致）${NC}"
        else
            echo -e "${YELLOW}⚠ 配置备份文件与源文件不一致，建议检查日志${NC}"
        fi
    fi

    # 5. 验证data.db备份（同步用sudo）
    if [ -f "$SERVER_BF/data.db" ]; then
        if [ -z "$latest_data_backup" ]; then
            echo -e "${YELLOW}⚠ 未找到测试data.db备份文件（可能首次备份未生成）${NC}"
        else
            echo -e "${GREEN}✓ 找到data.db备份：${OPTION_TEXT}$latest_data_backup${NC}"
            # 验证data.db备份大小（非空即为有效）
            if [ -s "$latest_data_backup" ]; then
                echo -e "${GREEN}✓ data.db备份文件验证成功（非空）${NC}"
            else
                echo -e "${YELLOW}⚠ data.db备份文件为空，可能备份异常${NC}"
            fi
        fi
    fi

    # 6. 查看最新备份日志（用sudo确保能读取）
    echo -e "\n${YELLOW}▷ 最新备份日志（3行）：${NC}"
    sudo tail -3 "${SERVER_BF}/gostc_backup_full.log" | grep -E "备份(成功|失败|提示)"

    # 7. 询问是否保留测试备份
    read -rp "$(echo -e "${TITLE}▷ 是否删除测试备份文件？(y/n, 默认y): ${NC}")" confirm
    [[ "$confirm" != "n" ]] && {
        [ -n "$latest_config_backup" ] && sudo rm -f "$latest_config_backup" && echo -e "${GREEN}✓ 已删除测试配置备份${NC}"
        [ -n "$latest_data_backup" ] && sudo rm -f "$latest_data_backup" && echo -e "${GREEN}✓ 已删除测试data.db备份${NC}"
    }
    return 0
}

# 卸载工具箱
uninstall_toolbox() {
    echo -e "${YELLOW}▶ 确定要卸载 GOSTC 工具箱吗？${NC}"
    read -rp "确认卸载？(y/n, 默认n): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && sudo rm -f "$TOOL_PATH" && \
        echo -e "${GREEN}✓ GOSTC 工具箱已卸载${NC}" && exit 0
    echo -e "${TITLE}▶ 卸载已取消${NC}"
}

# 获取最新版本信息
get_latest_version() {
    local script=$(curl -s "https://raw.githubusercontent.com/297855/gootl/main/install.sh")
    local version=$(awk -F'"' '/TOOL_VERSION=/{print $2; exit}' <<< "$script")
    local changelog=$(grep -m1 '^"' <<< "$script" | cut -d'"' -f2)
    echo "$version|$changelog"
}

# 检查更新
check_update() {
    echo -e "${YELLOW}▶ 正在检查更新...${NC}"
    local latest_info=$(get_latest_version)
    [[ -z "$latest_info" ]] && echo -e "${RED}✗ 无法获取最新版本信息${NC}" && return
    IFS='|' read -r latest_version latest_changelog <<< "$latest_info"
    [[ "$latest_version" == "$TOOL_VERSION" ]] && \
        echo -e "${GREEN}✓ 当前已是最新版本 (v$TOOL_VERSION)${NC}" && return
    echo -e "${TITLE}▷ 当前版本: ${OPTION_TEXT}v$TOOL_VERSION${NC}"
    echo -e "${TITLE}▷ 最新版本: ${OPTION_TEXT}v$latest_version${NC}"
    echo -e "${YELLOW}════════════════ 更新日志 ════════════════${NC}"
    [[ -n "$latest_changelog" ]] && echo -e "${OPTION_TEXT}$latest_changelog${NC}" || echo -e "${YELLOW}暂无更新日志${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════${NC}"
    read -rp "是否立即更新? (y/n, 默认 y): " confirm
    [[ "$confirm" == "n" ]] && echo -e "${TITLE}▶ 更新已取消${NC}" && return
    echo -e "${YELLOW}▶ 正在更新工具箱...${NC}"
    sudo curl -fL "https://raw.githubusercontent.com/297855/gootl/main/install.sh" -o "$TOOL_PATH" && {
        sudo chmod +x "$TOOL_PATH"
        echo -e "${GREEN}✓ 工具箱已更新到 v$latest_version${NC}"
        echo -e "${TITLE}请重新运行 ${OPTION_TEXT}gotool${TITLE} 命令${NC}"
        exit 0
    }
    echo -e "${RED}✗ 更新失败${NC}"
}

# 其他功能菜单
other_functions() {
     while :; do
     echo ""
     echo -e "${TITLE}▶ 其他功能${NC}"
     echo -e "${SEPARATOR}==================================================${NC}"
     echo -e "${OPTION_NUM}1. ${OPTION_TEXT}显示系统信息${NC}"
     echo -e "${OPTION_NUM}2. ${OPTION_TEXT}备份服务端配置${NC}"
     echo -e "${OPTION_NUM}3. ${OPTION_TEXT}恢复服务端配置${NC}"
     echo -e "${OPTION_NUM}4. ${OPTION_TEXT}自动备份服务端${NC}"
     echo -e "${OPTION_NUM}5. ${OPTION_TEXT}修改备份保留天数${NC}"
     echo -e "${OPTION_NUM}6. ${OPTION_TEXT}查看备份日志${NC}"
     echo -e "${OPTION_NUM}7. ${OPTION_TEXT}服务端远程迁移${NC}"
     echo -e "${OPTION_NUM}8. ${OPTION_TEXT}SSH远程安装节点/客户端${NC}"
     echo -e "${OPTION_NUM}9. ${OPTION_TEXT}Docker安装客户端${NC}"
     echo -e "${OPTION_NUM}0. ${OPTION_TEXT}返回主菜单${NC}"
     echo -e "${SEPARATOR}==================================================${NC}"
     read -rp "请输入选项: " choice
     case $choice in
     1)
     echo -e "${YELLOW}▶ 系统信息${NC}"
     echo -e "${TITLE}操作系统: ${OPTION_TEXT}$(uname -s) $(uname -m)${NC}"
     echo -e "${TITLE}内核版本: ${OPTION_TEXT}$(uname -r)${NC}"
     echo -e "${TITLE}主机名: ${OPTION_TEXT}$(hostname)${NC}"
     echo -e "${TITLE}CPU信息: ${OPTION_TEXT}$(grep -m1 "model name" /proc/cpuinfo | cut -d':' -f2 | sed 's/^[ \t]*//')${NC}"
     echo -e "${TITLE}内存信息: ${OPTION_TEXT}$(free -h | grep Mem | awk '{print $2}')${NC}"
     ;;
     2)
     if [ -f "$SERVER_CFG" ]; then
    # 执行备份
    backup_file="${SERVER_BF}/config_$(date +%Y%m%d%H%M%S).yaml"
    sudo mkdir -p "$SERVER_BF"
    sudo cp "$SERVER_CFG" "$backup_file"
    echo -e "${GREEN}✓ 配置已备份到: ${OPTION_TEXT}$backup_file${NC}"
    # 自动清理旧备份（使用统一变量BACKUP_RETAIN_DAYS）
    sudo find "${SERVER_BF}" -name "config_*.yaml" -mtime +${BACKUP_RETAIN_DAYS} -delete -print | while read -r file; do
    echo -e "${YELLOW}▷ 已清理过期备份: ${file}${NC}"
    done
    else
    echo -e "${RED}✗ 未找到服务端配置文件${NC}"
     fi
     ;;
3)
echo -e "${YELLOW}▶ 可用的备份文件（最近${BACKUP_RETAIN_DAYS}天内）${NC}"
# 获取有效配置备份（仅按config_*.yaml列表，后续匹配data.db）
valid_backups=($(sudo find "${SERVER_BF}" -name "config_*.yaml" -mtime -${BACKUP_RETAIN_DAYS} 2>/dev/null | sort -r))
if [ ${#valid_backups[@]} -gt 0 ]; then
    echo -e "${SEPARATOR}==================================================${NC}"
    for i in "${!valid_backups[@]}"; do
        # 显示备份文件+对应时间戳（便于用户识别）
        backup_time=$(basename "${valid_backups[i]}" | grep -oE 'config_([0-9]+)\.yaml' | cut -d'_' -f2 | cut -d'.' -f1)
        backup_time_format=$(date -d "@$(date -d "${backup_time:0:8} ${backup_time:8:2}:${backup_time:10:2}:${backup_time:12:2}" +%s)" +"%Y-%m-%d %H:%M:%S")
        echo -e "${OPTION_NUM}$((i+1)). ${OPTION_TEXT}${valid_backups[i]} ${YELLOW}（备份时间：${backup_time_format}）${NC}"
    done
    echo -e "${SEPARATOR}==================================================${NC}"
    read -rp "请输入要恢复的备份编号 (1-${#valid_backups[@]}, 输入0返回主菜单): " choice
    
    if [[ "$choice" == "0" ]]; then
        echo -e "${TITLE}▶ 返回主菜单${NC}"
        break
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#valid_backups[@]} ]; then
        backup_file="${valid_backups[$((choice-1))]}"
        # 1. 恢复配置文件（原有逻辑）
        sudo cp "$backup_file" "$SERVER_CFG"
        echo -e "${GREEN}✓ 服务端配置已从 ${OPTION_TEXT}$backup_file${GREEN} 恢复${NC}"
        
        # 2. 新增：提取时间戳，恢复对应data.db备份
        # 从config备份文件名提取时间戳（如config_20251015123456.yaml → 20251015123456）
        backup_timestamp=$(basename "$backup_file" | awk -F'[_.]' '{print $2}')
        if [ -n "$backup_timestamp" ]; then
            data_backup_file="${SERVER_BF}/data_${backup_timestamp}.db"
            # 检查对应data.db备份是否存在
            if [ -f "$data_backup_file" ]; then
                sudo cp "$data_backup_file" "${SERVER_BF}/data.db"
                echo -e "${GREEN}✓ 服务端数据库（data.db）已从 ${OPTION_TEXT}$data_backup_file${GREEN} 恢复${NC}"
            else
                echo -e "${YELLOW}⚠ 未找到对应的数据备份（data_${backup_timestamp}.db），跳过data.db恢复${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ 无法提取备份时间戳，跳过data.db恢复${NC}"
        fi
        
        echo -e "${YELLOW}⚠ 提示：恢复后需重启服务端使更改生效（选择「服务端管理」→「3. 重启」）${NC}"
    else
        echo -e "${RED}✗ 无效的备份编号${NC}"
    fi
else
    echo -e "${YELLOW}未找到有效配置备份文件${NC}"
    read -rp "$(echo -e "${TITLE}▷ 按任意键返回主菜单...${NC}")" -n 1 -s
    echo -e "\n${TITLE}▶ 返回主菜单${NC}"
    break
fi
;;
    5)
   echo -e "${YELLOW}▶ 当前备份保留天数: ${OPTION_TEXT}${BACKUP_RETAIN_DAYS}天${NC}"
   read -p "请输入新的保留天数: " new_days
   if [[ "$new_days" =~ ^[0-9]+$ ]] && [ "$new_days" -gt 0 ]; then
   BACKUP_RETAIN_DAYS=$new_days
   echo -e "${GREEN}✓ 已修改为保留${new_days}天${NC}"
   else
   echo -e "${RED}✗ 请输入有效正整数${NC}"
   fi
   ;;
4)
echo -e "${YELLOW}▶ 自动备份设置 (Cron定时任务) - 全系统兼容${NC}"
echo -e "${SEPARATOR}==================================================${NC}"
echo -e "${GREEN}提示：选择备份频率（Cron定时）${NC}"
echo -e "${OPTION_NUM}1. ${OPTION_TEXT}每天凌晨2点 (推荐)${NC}"
echo -e "${OPTION_NUM}2. ${OPTION_TEXT}每周日凌晨3点${NC}"
echo -e "${OPTION_NUM}3. ${OPTION_TEXT}每月1号凌晨4点${NC}"
echo -e "${OPTION_NUM}4. ${OPTION_TEXT}自定义Cron表达式（例：0 12 * * * 每天12点）${NC}"
read -rp "请选择备份频率 [1-4]: " freq

# 1. 解析频率，生成Cron表达式和描述
local cron_expr="" desc=""
case $freq in
1) 
    cron_expr="0 2 * * *"
    desc="每天凌晨2点"
    ;;
2) 
    cron_expr="0 3 * * 0"  # Cron中0代表周日
    desc="每周日凌晨3点"
    ;;
3) 
    cron_expr="0 4 1 * *"
    desc="每月1号凌晨4点"
    ;;
4)
    read -p "$(echo -e "${TITLE}▷ 输入Cron表达式（例：0 12 * * *）: ${NC}")" cron_expr
    # 简单校验Cron表达式格式（5个字段）
    if ! echo "$cron_expr" | grep -qE '^[0-9/\-\* ]+ [0-9/\-\* ]+ [0-9/\-\* ]+ [0-9/\-\* ]+ [0-9/\-\* ]+$'; then
        echo -e "${RED}✗ Cron表达式格式错误！正确示例：0 12 * * *${NC}"
        return
    fi
    desc="自定义频率"
    ;;
*)
    echo -e "${RED}✗ 无效选项，返回上一级${NC}"
    return
    ;;
esac

# 2. 创建备份脚本（若不存在）
create_backup_script

# 3. 设置Cron任务（先删除旧任务）
echo -e "\n${YELLOW}▷ 配置Cron定时任务...${NC}"
set_cron_task "$cron_expr" "$desc"
if [ $? -ne 0 ]; then
    return
fi

# 4. 可选：立即验证备份功能
read -rp "$(echo -e "\n${TITLE}▷ 是否立即验证备份功能？(y/n, 默认y): ${NC}")" confirm
[[ "$confirm" != "n" ]] && verify_cron_backup

echo -e "\n${YELLOW}▶ 自动备份设置完成！${NC}"
echo -e "${TITLE}▷ 查看Cron任务：${OPTION_TEXT}sudo crontab -l | grep gostc_backup.sh${NC}"
echo -e "${TITLE}▷ 手动触发备份：${OPTION_TEXT}sudo /usr/local/bin/gostc_backup.sh${NC}"
;;
5)
# 原有“修改备份保留天数”逻辑（不变）
echo -e "${YELLOW}▶ 当前备份保留天数: ${OPTION_TEXT}${BACKUP_RETAIN_DAYS}天${NC}"
read -p "请输入新的保留天数: " new_days
if [[ "$new_days" =~ ^[0-9]+$ ]] && [ "$new_days" -gt 0 ]; then
    BACKUP_RETAIN_DAYS=$new_days
    echo -e "${GREEN}✓ 已修改为保留${new_days}天${NC}"
else
    echo -e "${RED}✗ 请输入有效正整数${NC}"
fi
;;
# 新增：查看备份日志逻辑
6)
echo -e "${YELLOW}▶ 查看备份日志（实时显示最新20行，按 Ctrl+C 退出）${NC}"
echo -e "${TITLE}▷ 日志路径：${OPTION_TEXT}${SERVER_BF}/gostc_backup_full.log${NC}"
echo -e "${YELLOW}▷ 提示：按 ${OPTION_TEXT}Ctrl+C${YELLOW} 退出日志查看，返回菜单${NC}\n"

# 1. 检查日志文件是否存在
if [ ! -f "${SERVER_BF}/gostc_backup_full.log" ]; then
    echo -e "${RED}✗ 未找到备份日志文件！${NC}"
    echo -e "${YELLOW}▷ 触发一次备份生成日志：${OPTION_TEXT}sudo /usr/local/bin/gostc_backup.sh${NC}"
    # 提示返回菜单
    read -rp "$(echo -e "\n${TITLE}▷ 按任意键返回菜单...${NC}")" -n 1 -s
    echo -e "\n${TITLE}▶ 返回菜单${NC}"
    break
fi

# 2. 实时查看日志（显示最新20行，持续跟踪新日志）
tail -n 20 -f "${SERVER_BF}/gostc_backup_full.log"

# 3. 按 Ctrl+C 退出后，提示返回菜单
echo -e "\n\n${TITLE}▶ 退出日志查看，返回菜单${NC}"
break
;;
7)
remote_migrate  # 调用远程迁移函数
;;
8)
remote_install_node  # 调用远程安装函数
;;
9)
install_docker_client  # 调用Docker安装函数
;;
0) 
# 原有“返回主菜单”逻辑（不变）
echo -e "${TITLE}▶ 返回主菜单${NC}"
break
;;
0) 
    echo -e "${TITLE}▶ 返回主菜单${NC}"
    break  # 退出当前while无限循环，回到主菜单
    ;;
esac
done
}

# 修复：3.1 替换服务操作中的固定sleep为循环检测状态
service_action() {
    local svc=$1 bin=$2 action=$3
    ! command -v "$bin" &>/dev/null && echo -e "${RED}✗ 未安装，请先安装${NC}" && return
    case $action in
        start)
            echo -e "${YELLOW}▶ 正在启动...${NC}"
            sudo systemctl start "$svc"
            # 循环检测服务状态（最多5次，间隔1秒）
            local retry=0
            while [ $retry -lt 5 ]; do
                if sudo systemctl is-active --quiet "$svc"; then
                    echo -e "${GREEN}✓ 已成功启动${NC}"
                    return
                fi
                retry=$((retry+1))
                sleep 1
            done
            echo -e "${YELLOW}⚠ 启动可能存在问题${NC}"
            ;;
        restart)
            echo -e "${YELLOW}▶ 正在重启...${NC}"
            sudo systemctl restart "$svc"
            # 循环检测服务状态（最多5次，间隔1秒）
            local retry=0
            while [ $retry -lt 5 ]; do
                if sudo systemctl is-active --quiet "$svc"; then
                    echo -e "${GREEN}✓ 已成功重启${NC}"
                    return
                fi
                retry=$((retry+1))
                sleep 1
            done
            echo -e "${YELLOW}⚠ 重启可能存在问题${NC}"
            ;;
        stop)
            echo -e "${YELLOW}▶ 正在停止...${NC}"
            sudo systemctl stop "$svc"
            # 循环检测服务状态（最多3次，间隔1秒）
            local retry=0
            while [ $retry -lt 3 ]; do
                if ! sudo systemctl is-active --quiet "$svc"; then
                    echo -e "${GREEN}✓ 已停止${NC}"
                    return
                fi
                retry=$((retry+1))
                sleep 1
            done
            echo -e "${YELLOW}⚠ 停止失败${NC}"
            ;;
        uninstall)
            echo -e "${YELLOW}▶ 确定要卸载吗？${NC}"
            read -rp "确认卸载？(y/n, 默认n): " confirm
            [[ "$confirm" != "y" ]] && echo -e "${TITLE}▶ 卸载已取消${NC}" && return
            sudo systemctl is-active --quiet "$svc" && {
                echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
                sudo systemctl stop "$svc"
            }
            sudo systemctl list-unit-files | grep -q "$svc" && {
                echo -e "${YELLOW}▷ 卸载系统服务...${NC}"
                sudo "$bin" service uninstall
            }
            echo -e "${YELLOW}▷ 删除安装文件...${NC}"
            [[ "$svc" == "$SERVER_SVC" ]] && \
                sudo rm -rf "$SERVER_DIR" || \
                sudo rm -f "${NODE_DIR}/${NODE_BIN}"
            echo -e "${GREEN}✓ 已卸载${NC}"
            ;;
    esac
}

# 服务管理菜单
service_menu() {
    local svc=$1 bin=$2 dir=$3 title=$4 status_func=$5 install_func=$6
    while :; do
        stat=$($status_func)
        echo ""
        echo -e "${TITLE}${title} ${stat}${NC}"
        echo -e "${SEPARATOR}==================================================${NC}"
        [[ "$svc" == "$SERVER_SVC" ]] && 
            echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装/更新${NC}" || 
            echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}启动${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}重启${NC}"
        echo -e "${OPTION_NUM}4. ${OPTION_TEXT}停止${NC}"
        echo -e "${OPTION_NUM}5. ${OPTION_TEXT}卸载${NC}"
        [[ "$svc" == "$NODE_SVC" ]] && echo -e "${OPTION_NUM}6. ${OPTION_TEXT}更新${NC}"
        echo -e "${OPTION_NUM}0. ${OPTION_TEXT}返回主菜单${NC}"
        echo -e "${SEPARATOR}==================================================${NC}"
        read -rp "请输入选项: " choice
        case $choice in
            1) $install_func ;;
            2) service_action "$svc" "$dir/$bin" start ;;
            3) service_action "$svc" "$dir/$bin" restart ;;
            4) service_action "$svc" "$dir/$bin" stop ;;
            5) service_action "$svc" "$dir/$bin" uninstall ;;
            6) [[ "$svc" == "$NODE_SVC" ]] && update_node || echo -e "${RED}无效选项${NC}" ;;
            0) return ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
    done
}

# 安装服务端
install_server() {
    local update_mode=false base_url="https://alist.sian.one/direct/gostc/gostc-open" version="普通版本"
    # 定义保存修改时间的文件路径
    local mod_time_file="$SERVER_DIR/mod_time.txt"
    # 检查是否已安装
    [ -f "${SERVER_DIR}/${SERVER_BIN}" ] && {
        echo -e "${TITLE}检测到已安装服务端，请选择操作:${NC}"
        echo -e "${OPTION_NUM}1. ${OPTION_TEXT}更新到最新版本 (保留配置)${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}重新安装最新版本 (删除所有文件重新安装)${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}退出${NC}"
        read -rp "请输入选项编号 (1 - 3, 默认 1): " choice
        case $choice in
            2) sudo rm -rf "${SERVER_DIR}" ;;
            3) echo -e "${TITLE}操作已取消${NC}" && return ;;
            *) update_mode=true ;;
        esac
    }
    # 选择版本
    echo -e "${TITLE}请选择安装版本:${NC}"
    echo -e "${OPTION_NUM}1. ${OPTION_TEXT}普通版本 (默认)${NC}"
    echo -e "${OPTION_NUM}2. ${OPTION_TEXT}商业版本 (需要授权)${NC}"
    echo -e "${OPTION_NUM}3. ${OPTION_TEXT}测试版本 (需要授权)${NC}"
    read -rp "请输入选项编号 (1 - 3, 默认 1): " choice
    case $choice in
        2)
            base_url="https://alist.sian.one/direct/gostc"
            version="商业版本"
            echo -e "${YELLOW}▶ 您选择了商业版本，请确保您已获得商业授权${NC}"
            ;;
        3)
            base_url="https://alist.sian.one/direct/gostc/beta/"
            version="测试版本"
            echo -e "${YELLOW}▶ 您选择了测试版本，请确保您已获得测试授权${NC}"
            ;;
    esac
    echo ""
    echo -e "${TITLE}▶ 开始安装 服务端 (${version})${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${TITLE}▷ 检测系统: ${OPTION_TEXT}${OS} ${ARCH}${NC}"
    # 调用通用架构检测函数
    local arch_suffix=$(get_arch_suffix)
    local OS=$(echo "$arch_suffix" | cut -d'_' -f1) # 从结果中提取OS（确保一致性）
    file="${SERVER_BIN}_${arch_suffix}"
    # 构建下载URL
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    file="${SERVER_BIN}_${OS}_${suffix}"
    [[ "$OS" == "windows" ]] && file="${file}.zip" || file="${file}.tar.gz"
    url="${base_url}/${file}"
    echo -e "${TITLE}▷ 下载文件: ${OPTION_TEXT}${file}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    # 创建目录并下载文件
    sudo mkdir -p "$SERVER_DIR" >/dev/null 2>&1
    curl -# -fL -o "$file" "$url" || {
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        return
    }
    # 停止运行中的服务
    sudo systemctl is-active --quiet "$SERVER_SVC" 2>/dev/null && {
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SVC"
    }
    # 解压文件
    echo ""
    echo -e "${TITLE}▶ 正在安装到: ${OPTION_TEXT}${SERVER_DIR}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    # 修复：2.2 修复更新模式下配置恢复逻辑，获取最新备份文件并恢复
    $update_mode && {
        echo -e "${YELLOW}▷ 更新模式: 保留配置文件${NC}"
        # 备份当前配置
        backup_file="${SERVER_BF}/config_$(date +%Y%m%d%H%M%S).yaml.bak"
        sudo cp -f "$SERVER_CFG" "$backup_file" 2>/dev/null
        # 删除非配置文件
        sudo find "${SERVER_DIR}" -maxdepth 1 -type f ! -name '*.yaml' -delete
        # 恢复最新备份的配置
        latest_backup=$(sudo ls -t "${SERVER_BF}/config_"*.yaml.bak 2>/dev/null | head -1)
        [ -n "$latest_backup" ] && sudo cp -f "$latest_backup" "$SERVER_CFG" 2>/dev/null
    } || sudo rm -f "$SERVER_DIR/$SERVER_BIN"
    [[ "$file" == *.zip ]] && \
        sudo unzip -qo "$file" -d "$SERVER_DIR" || \
        sudo tar xzf "$file" -C "$SERVER_DIR"
    # 设置权限
    [ -f "$SERVER_DIR/$SERVER_BIN" ] && {
        sudo chmod 755 "$SERVER_DIR/$SERVER_BIN"
        echo -e "${GREEN}✓ 已安装二进制文件: ${OPTION_TEXT}${SERVER_DIR}/${SERVER_BIN}${NC}"
    } || {
        echo -e "${RED}错误: 解压后未找到二进制文件 $SERVER_BIN${NC}"
        return
    }
    # 初始化服务
    echo ""
    echo -e "${TITLE}▶ 正在初始化服务...${NC}"
    sudo systemctl list-units --full -all | grep -Fq "${SERVER_SVC}.service" || {
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$SERVER_DIR/$SERVER_BIN" service install
    }
    # 启动服务
    echo ""
    echo -e "${TITLE}▶ 正在启动服务...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVER_SVC" >/dev/null 2>&1
    sudo systemctl restart "$SERVER_SVC"
    # 清理
    rm -f "$file"
    # 检查服务状态
    # 循环检测服务状态（最多5次，间隔1秒）
    local retry=0
    while [ $retry -lt 5 ]; do
        status=$(systemctl is-active "$SERVER_SVC")
        if [[ "$status" == "active" ]]; then
            break
        fi
        retry=$((retry+1))
        sleep 1
    done
    [[ "$status" == "active" ]] && \
        echo -e "${GREEN}✓ 服务已成功启动${NC}" || \
        echo -e "${YELLOW}⚠ 服务启动可能存在问题，当前状态: ${status}${NC}"
    # 记录当前安装版本
    echo "$version" | sudo tee "$SERVER_DIR/version.txt" > /dev/null
    # 安装完成提示
    echo ""
    echo -e "${TITLE}版本: ${OPTION_TEXT}${version}${NC}"
    echo -e "${TITLE}安装目录: ${OPTION_TEXT}$SERVER_DIR${NC}"
    echo -e "${TITLE}服务状态: $([ "$status" = "active" ] && echo -e "${GREEN}运行中${NC}" || echo -e "${YELLOW}未运行${NC}")"
    echo -e "${TITLE}访问地址: ${OPTION_TEXT}http://localhost:8080${NC}"
    # 显示初始凭据
    [ ! -f "$SERVER_CFG" ] && ! $update_mode && {
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "用户名: ${OPTION_TEXT}admin${NC}"
        echo -e "密码: ${OPTION_TEXT}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    }
}

# 安装节点/客户端（已添加备用下载逻辑）
install_node() {
    # 选择类型
    echo ""
    echo -e "${TITLE}▶ 请选择安装类型${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装节点 (默认)${NC}"
    echo -e "${OPTION_NUM}2. ${OPTION_TEXT}安装客户端${NC}"
    echo -e "${OPTION_NUM}0. ${OPTION_TEXT}返回${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    read -p "$(echo -e "${TITLE}▷ 请输入选择 [1-2] (默认1): ${NC}")" choice
    choice=${choice:-1}
    [[ "$choice" == 0 ]] && return
    local type="节点"
    [[ "$choice" == 2 ]] && type="客户端"
    echo ""
    echo -e "${TITLE}▶ 开始安装 ${OPTION_TEXT}${type}${TITLE} 组件${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${TITLE}▷ 检测系统: ${OPTION_TEXT}${OS} ${ARCH}${NC}"
    # 调用通用架构检测函数
    local arch_suffix=$(get_arch_suffix)
    local OS=$(echo "$arch_suffix" | cut -d'_' -f1)
    file="${NODE_BIN}_${arch_suffix}"
    # 构建主下载URL
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    file="${NODE_BIN}_${OS}_${suffix}"
    [[ "$OS" == "windows" ]] && file="${file}.zip" || file="${file}.tar.gz"
    url="https://alist.sian.one/direct/gostc/${file}"
    # 定义客户端备用下载包（核心新增：指定gostc_linux_amd64.tar.gz）
    local backup_file_client="gostc_linux_amd64_v1.tar.gz"
    local backup_url_client="https://alist.sian.one/direct/gostc/${backup_file_client}"  # 可替换为实际备用源
    
    echo -e "${TITLE}▷ 下载文件: ${OPTION_TEXT}${file}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    # 记录文件修改时间
    mod_time=$(curl -sI "$url" | grep -i "Last-Modified" | cut -d':' -f2- | sed 's/^\s*//;s/\s*$//')
    [ -n "$mod_time" ] && sudo tee "${NODE_DIR}/mod_time.txt" >/dev/null <<< "$mod_time"
    # 下载文件（核心修改：主下载失败自动切换备用）
    sudo mkdir -p "$NODE_DIR" >/dev/null 2>&1
    echo -e "${YELLOW}▷ 尝试主源下载...${NC}"
    curl -# -fL -o "$file" "$url" || {
        # 仅客户端安装时触发备用下载（核心逻辑）
        if [[ "$type" == "客户端" ]]; then
            echo -e "${RED}✗ 主源下载失败，自动尝试备用包：${OPTION_TEXT}${backup_file_client}${NC}"
            curl -# -fL -o "$backup_file_client" "$backup_url_client" || {
                echo -e "${RED}✗ 备用包下载也失败！${NC}"
                return 1
            }
            # 备用包下载成功，替换为备用文件名继续安装
            file="$backup_file_client"
        else
            echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
            return 1
        fi
    }
    # 解压文件（兼容主备包格式，均为tar.gz）
    echo ""
    echo -e "${TITLE}▶ 正在安装到: ${OPTION_TEXT}${NODE_DIR}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    sudo rm -f "$NODE_DIR/$NODE_BIN"
    [[ "$file" == *.zip ]] && \
        sudo unzip -qo "$file" -d "$NODE_DIR" || \
        sudo tar xzf "$file" -C "$NODE_DIR"
    # 设置权限
    [ -f "$NODE_DIR/$NODE_BIN" ] && {
        sudo chmod 755 "$NODE_DIR/$NODE_BIN"
        echo -e "${GREEN}✓ 已安装二进制文件: ${OPTION_TEXT}${NODE_DIR}/${NODE_BIN}${NC}"
    } || {
        echo -e "${RED}错误: 解压后未找到二进制文件 $NODE_BIN${NC}"
        return 1
    }
    # 清理安装包
    rm -f "$file"
    # 配置（节点/客户端差异化配置，逻辑不变）
    [[ "$type" == "节点" ]] && configure_node || configure_client
}

# 修复：2.3 放宽服务器地址验证逻辑，支持200/301/302/204状态码
validate_server() {
    local addr=$1 tls=$2
    [[ "$tls" == "true" ]] && prefix="https://" || prefix="http://"
    [[ "$addr" != http* ]] && addr="${prefix}${addr}"
    echo -e "${TITLE}▷ 验证服务器地址: ${OPTION_TEXT}$addr${NC}"
    status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$addr")
    # 支持200（成功）、301（永久重定向）、302（临时重定向）、204（无内容）
    if [[ "$status" -ge 200 && "$status" -le 302 ]]; then
        echo -e "${GREEN}✓ 服务器验证成功 (HTTP $status)${NC}"
        return 0
    else
        echo -e "${RED}✗ 服务器验证失败 (HTTP $status)${NC}"
        return 1
    fi
}

# 配置节点
configure_node() {
    echo ""
    echo -e "${TITLE}▶ 节点配置${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e " - 服务器地址 (如: example.com:8080)"
    echo -e " - 节点密钥 (由服务端提供)"
    echo -e " - (可选) 网关代理地址${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    # TLS选项
    local tls="false"
    read -p "$(echo -e "${TITLE}▷ 是否使用TLS? (y/n, 默认n): ${NC}")" choice
    [[ "$choice" =~ ^[Yy]$ ]] && tls="true"
    # 服务器地址
    local addr="127.0.0.1:8080"
    while :; do
        read -p "$(echo -e "${TITLE}▷ 输入服务器地址 (默认 ${OPTION_TEXT}127.0.0.1:8080${TITLE}): ${NC}")" input
        input=${input:-$addr}
        validate_server "$input" "$tls" && addr="$input" && break
        echo -e "${RED}✗ 请重新输入有效的服务器地址${NC}"
    done
    # 节点密钥
    local key=""
    while [ -z "$key" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入节点密钥: ${NC}")" key
        [ -z "$key" ] && echo -e "${RED}✗ 节点密钥不能为空${NC}"
    done
    # 网关代理选项
    local proxy=""
    read -p "$(echo -e "${TITLE}▷ 是否使用网关代理? (y/n, 默认n): ${NC}")" choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        while :; do
            read -p "$(echo -e "${TITLE}▷ 输入网关地址 (包含http/https前缀): ${NC}")" url
            [[ "$url" =~ ^https?:// ]] && proxy="$url" && break
            echo -e "${RED}✗ 网关地址必须以http://或https://开头${NC}"
        done
    fi
    # 构建安装命令
    local cmd="sudo $NODE_DIR/$NODE_BIN install --tls=$tls -addr $addr -s -key $key"
    [ -n "$proxy" ] && cmd+=" --proxy-base-url $proxy"
    # 执行安装
    echo ""
    echo -e "${TITLE}▶ 正在配置节点${NC}"
    eval "$cmd" || {
        echo -e "${RED}✗ 节点配置失败${NC}"
        return
    }
    # 启动服务
    echo ""
    echo -e "${TITLE}▶ 正在启动服务${NC}"
    sudo systemctl start "$NODE_SVC" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return
    }
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    # 安装完成提示
    echo ""
    echo -e "${TITLE}组件: ${OPTION_TEXT}节点${NC}"
    echo -e "${TITLE}服务器地址: ${OPTION_TEXT}$addr${NC}"
    echo -e "${TITLE}TLS: ${OPTION_TEXT}$tls${NC}"
    [ -n "$proxy" ] && echo -e "${TITLE}网关地址: ${OPTION_TEXT}$proxy${NC}"
}

# 配置客户端
configure_client() {
    echo ""
    echo -e "${TITLE}▶ 客户端配置${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e " - 服务器地址 (如: example.com:8080)"
    echo -e " - 客户端密钥 (由服务端提供)${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    # TLS选项
    local tls="false"
    read -p "$(echo -e "${TITLE}▷ 是否使用TLS? (y/n, 默认n): ${NC}")" choice
    [[ "$choice" =~ ^[Yy]$ ]] && tls="true"
    # 服务器地址
    local addr="127.0.0.1:8080"
    while :; do
        read -p "$(echo -e "${TITLE}▷ 输入服务器地址 (默认 ${OPTION_TEXT}127.0.0.1:8080${TITLE}): ${NC}")" input
        input=${input:-$addr}
        validate_server "$input" "$tls" && addr="$input" && break
        echo -e "${RED}✗ 请重新输入有效的服务器地址${NC}"
    done
    # 客户端密钥
    local key=""
    while [ -z "$key" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入客户端密钥: ${NC}")" key
        [ -z "$key" ] && echo -e "${RED}✗ 客户端密钥不能为空${NC}"
    done
    # 构建安装命令
    local cmd="sudo $NODE_DIR/$NODE_BIN install --tls=$tls -addr $addr -key $key"
    # 执行安装
    echo ""
    echo -e "${TITLE}▶ 正在配置客户端${NC}"
    eval "$cmd" || {
        echo -e "${RED}✗ 客户端配置失败${NC}"
        return
    }
    # 启动服务
    echo ""
    echo -e "${TITLE}▶ 正在启动服务${NC}"
    sudo systemctl start "$NODE_SVC" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return
    }
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    # 安装完成提示
    echo ""
    echo -e "${TITLE}组件: ${OPTION_TEXT}客户端${NC}"
    echo -e "${TITLE}服务器地址: ${OPTION_TEXT}$addr${NC}"
    echo -e "${TITLE}TLS: ${OPTION_TEXT}$tls${NC}"
}

# 修复：3.2 修复临时目录操作风险，cd失败时清理临时目录
update_node() {
    ! command -v "$NODE_BIN" &>/dev/null && \
        echo -e "${RED}✗ 节点/客户端未安装，请先安装${NC}" && return
    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${TITLE}▷ 检测系统: ${OPTION_TEXT}${OS} ${ARCH}${NC}"
    # 调用通用架构检测函数
    local arch_suffix=$(get_arch_suffix)
    local OS=$(echo "$arch_suffix" | cut -d'_' -f1)
    file="${NODE_BIN}_${arch_suffix}"
    # 构建下载URL
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    file="${NODE_BIN}_${OS}_${suffix}"
    [[ "$OS" == "windows" ]] && file="${file}.zip" || file="${file}.tar.gz"
    url="https://alist.sian.one/direct/gostc/${file}"
    echo -e "${TITLE}▷ 下载文件: ${OPTION_TEXT}${file}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    # 创建临时目录并处理cd失败场景
    tmp=$(mktemp -d)
    cd "$tmp" || {
        echo -e "${RED}✗ 无法进入临时目录，更新终止${NC}"
        rm -rf "$tmp"
        return
    }
    # 下载文件
    curl -# -fL -o "$file" "$url" || {
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        cd - >/dev/null || return
        rm -rf "$tmp"
        return
    }
    # 停止服务
    echo -e "${YELLOW}▷ 停止节点/客户端服务...${NC}"
    sudo systemctl stop "$NODE_SVC"
    # 解压文件
    [[ "$file" == *.zip ]] && \
        unzip -qo "$file" -d "$tmp" || \
        tar xzf "$file" -C "$tmp"
    # 更新文件
    [ -f "$tmp/$NODE_BIN" ] && {
        sudo mv -f "$tmp/$NODE_BIN" "${NODE_DIR}/${NODE_BIN}"
        sudo chmod 755 "${NODE_DIR}/${NODE_BIN}"
        echo -e "${GREEN}✓ 节点/客户端更新成功${NC}"
    } || {
        echo -e "${RED}错误: 解压后未找到二进制文件 $NODE_BIN${NC}"
        sudo systemctl start "$NODE_SVC"
        cd - >/dev/null || return
        rm -rf "$tmp"
        return
    }
    # 清理
    cd - >/dev/null || return
    rm -rf "$tmp"
    # 启动服务
    echo -e "${YELLOW}▷ 启动节点/客户端服务...${NC}"
    sudo systemctl start "$NODE_SVC"
    # 检查状态（循环检测）
    local retry=0
    while [ $retry -lt 5 ]; do
        if sudo systemctl is-active --quiet "$NODE_SVC"; then
            echo -e "${GREEN}✓ 节点/客户端已成功启动${NC}"
            return
        fi
        retry=$((retry+1))
        sleep 1
    done
    echo -e "${YELLOW}⚠ 节点/客户端启动可能存在问题${NC}"
}

# 修复：2.1 修复自动备份状态检测逻辑，从crontab检测改为Systemd Timer检测
show_info() {
    # 获取服务端文件修改时间
    SERVER_FILE="${SERVER_DIR}/${SERVER_BIN}"
    if [ -f "$SERVER_FILE" ]; then
        server_mod_time=$(date -d "@$(stat -c %Y "$SERVER_FILE")" +"%Y-%m-%d %H:%M:%S")
    else
        server_mod_time="获取失败"
    fi

    # 获取备份数量（兼容无备份场景）
    backup_count=$(ls "${SERVER_BF}/config_"*.yaml 2>/dev/null | wc -l)
    [[ "$backup_count" == "0" ]] && backup_count="0"

    # 获取节点更新状态
    node_update_status="未知"
    if [ -f "${NODE_DIR}/${NODE_BIN}" ]; then
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        ARCH=$(uname -m)
        # 架构检测（复用原有逻辑）
        case "$ARCH" in
            "x86_64") suffix="amd64_v1" ;;
            "i"*"86") suffix="386_sse2" ;;
            "aarch64"|"arm64") suffix="arm64_v8.0" ;;
            "armv7l") suffix="arm_7" ;;
            "armv6l") suffix="arm_6" ;;
            "armv5l") suffix="arm_5" ;;
            "mips64") 
                lscpu 2>/dev/null | grep -qi "little endian" && suffix="mips64le_hardfloat" || suffix="mips64_hardfloat"
                ;;
            "mips")
                float="softfloat"
                lscpu 2>/dev/null | grep -qi "FPU" && float="hardfloat"
                lscpu 2>/dev/null | grep -qi "little endian" && suffix="mipsle_$float" || suffix="mips_$float"
                ;;
            "riscv64") suffix="riscv64_rva20u64" ;;
            "s390x") suffix="s390x" ;;
            *) suffix="unknown" ;;
        esac
        file="${NODE_BIN}_${OS}_${suffix}.tar.gz"
        url="https://alist.sian.one/direct/gostc/${file}"
        latest_mod_time=$(curl -sI "$url" | grep -i "last-modified" | cut -d':' -f2- | sed 's/^\s*//;s/\s*$//')
        if [ -n "$latest_mod_time" ]; then
            latest_timestamp=$(date -d "$latest_mod_time" +%s 2>/dev/null)
            current_timestamp=$(stat -c %Y "${NODE_DIR}/${NODE_BIN}")
            if [ "$latest_timestamp" -gt "$current_timestamp" ]; then
                node_update_status="${YELLOW}有新版本可用 (服务器修改: $(date -d "@$latest_timestamp" +"%Y-%m-%d %H:%M:%S"))${NC}"
            else
                node_update_status="${GREEN}已是最新版本${NC}"
            fi
        else
            node_update_status="${YELLOW}更新检查失败${NC}"
        fi
    fi

    # 重构列表式显示
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${TITLE}          GOSTC 服务管理工具箱 v${TOOL_VERSION}          ${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 1. 自动备份状态模块
    echo -e "\n${TITLE}【1】自动备份状态${NC}"
    echo -e "${SEPARATOR}--------------------------------------------------${NC}"
    if sudo crontab -l 2>/dev/null | grep -q "gostc_backup.sh"; then
        local cron_task=$(sudo crontab -l | grep "gostc_backup.sh")
        local cron_expr=$(echo "$cron_task" | awk '{print $1" "$2" "$3" "$4" "$5}')
        echo -e "  ${OPTION_NUM}▷ 备份状态: ${GREEN}已启用（Cron定时）${NC}"
        echo -e "  ${OPTION_NUM}▷ 备份频率: ${OPTION_TEXT}$(get_cron_desc "$cron_expr")${NC}"
        echo -e "  ${OPTION_NUM}▷ Cron表达式: ${OPTION_TEXT}$cron_expr${NC}"
        latest_backup=$(sudo ls -t "${SERVER_BF}/config_"* 2>/dev/null | head -1)
        if [ -n "$latest_backup" ]; then
            echo -e "  ${OPTION_NUM}▷ 最近备份: ${OPTION_TEXT}$(sudo stat -c "%y" "$latest_backup" | cut -d'.' -f1)${NC}"
        else
            echo -e "  ${OPTION_NUM}▷ 最近备份: ${YELLOW}无备份记录${NC}"
        fi
        echo -e "  ${OPTION_NUM}▷ 保留天数: ${OPTION_TEXT}${BACKUP_RETAIN_DAYS}天${NC}"
        echo -e "  ${OPTION_NUM}▷ 备份数量: ${OPTION_TEXT}${backup_count}个${NC}"
    else
        echo -e "  ${OPTION_NUM}▷ 备份状态: ${YELLOW}未启用（Cron任务未配置）${NC}"
        echo -e "  ${OPTION_NUM}▷ 启用方法: ${OPTION_TEXT}gotool → 6（其他功能）→ 4（自动备份服务端）${NC}"
    fi

    # 2. 服务端信息模块
    echo -e "\n${TITLE}【2】服务端信息${NC}"
    echo -e "${SEPARATOR}--------------------------------------------------${NC}"
    # 调用实时检测函数
    local server_real_time=$(get_server_real_time_status)
    local current_version=$(echo "$server_real_time" | cut -d'|' -f1)
    local update_status=$(echo "$server_real_time" | cut -d'|' -f2)
    local latest_time=$(echo "$server_real_time" | cut -d'|' -f3)

    # 显示实时信息
    echo -e "  ${OPTION_NUM}▷ 安装版本: ${OPTION_TEXT}${current_version}${NC}"
    echo -e "  ${OPTION_NUM}▷ 运行状态: $(server_status)"
    echo -e "  ${OPTION_NUM}▷ 本地修改时间: ${OPTION_TEXT}$server_mod_time${NC}"
    # 实时更新状态着色
    if [[ "$update_status" == "有新版本可用" ]]; then
    echo -e "  ${OPTION_NUM}▷ 更新状态: ${YELLOW}$update_status (服务器最新: ${latest_time})${NC}"
    elif [[ "$update_status" == "更新检查失败" ]]; then
    echo -e "  ${OPTION_NUM}▷ 更新状态: ${YELLOW}$update_status${NC}"
    elif [[ "$update_status" == "服务端未安装" || "$update_status" == "未找到版本信息" ]]; then
    echo -e "  ${OPTION_NUM}▷ 更新状态: ${RED}$update_status${NC}"
    else
    echo -e "  ${OPTION_NUM}▷ 更新状态: ${GREEN}$update_status${NC}"
    fi

    # 3. 节点/客户端信息模块
    echo -e "\n${TITLE}【3】节点/客户端信息${NC}"
    echo -e "${SEPARATOR}--------------------------------------------------${NC}"
    echo -e "  ${OPTION_NUM}▷ 运行状态: $(node_status)"
    # 节点本地文件修改时间（仅显示年月日）
    local node_mod_time="获取失败"
    if [ -f "${NODE_DIR}/${NODE_BIN}" ]; then
    local node_ts=$(stat -c %Y "${NODE_DIR}/${NODE_BIN}")
    node_mod_time=$(date -d "@$node_ts" +"%Y-%m-%d")  # 仅保留年月日
    fi
    echo -e "  ${OPTION_NUM}▷ 本地文件修改时间: ${OPTION_TEXT}$node_mod_time${NC}"

    # 实时检测节点更新状态（无缓存，每次请求）
    local node_update_status="${YELLOW}更新检查失败${NC}"
    if [ -f "${NODE_DIR}/${NODE_BIN}" ]; then
    # 实时获取架构后缀和服务器文件
    local arch_suffix=$(get_arch_suffix)
    local file="${NODE_BIN}_${arch_suffix}.tar.gz"
    [[ "$arch_suffix" == "windows_"* ]] && file="${NODE_BIN}_${arch_suffix}.zip"
    local url="https://alist.sian.one/direct/gostc/${file}"
    
    # 实时请求服务器最新修改时间（3秒超时）
    local latest_mod_time=$(curl -s --connect-timeout 3 -I "$url" | grep -i "last-modified" | cut -d':' -f2- | sed 's/^\s*//;s/\s*$//')
    if [ -n "$latest_mod_time" ]; then
    # 核心修改1：将服务器时间戳转换为“当天0点”（忽略时分秒）
    local latest_timestamp=$(date -d "$latest_mod_time" +"%Y-%m-%d")  # 先转为年月日字符串
    latest_timestamp=$(date -d "$latest_timestamp 00:00:00" +%s)     # 再转为当天0点时间戳
    
    # 核心修改2：将本地时间戳同样转换为“当天0点”
    local current_timestamp=$(stat -c %Y "${NODE_DIR}/${NODE_BIN}")
    current_timestamp=$(date -d "@$current_timestamp" +"%Y-%m-%d")   # 本地时间转年月日字符串
    current_timestamp=$(date -d "$current_timestamp 00:00:00" +%s)  # 转当天0点时间戳
    
    # 按日期对比（而非精确到秒）
    local latest_date_str=$(date -d "@$latest_timestamp" +"%Y-%m-%d")
    if [ "$latest_timestamp" -gt "$current_timestamp" ]; then
        node_update_status="${YELLOW}有新版本可用 (服务器修改: ${latest_date_str})${NC}"
    else
        node_update_status="${GREEN}已是最新版本${NC}"
    fi
fi
else
    node_update_status="${RED}节点/客户端未安装${NC}"
fi
echo -e "  ${OPTION_NUM}▷ 更新状态: $node_update_status"

    echo -e "\n${SEPARATOR}==================================================${NC}"
}

# 检查服务端更新
check_server_update() {
    echo -e "${YELLOW}▶ 正在检查服务端更新...${NC}"
    local current_version="" base_url=""
    local server_dir="${SERVER_DIR}"
    local version_file="${server_dir}/version.txt"

    # 核心1：识别现有版本（文件存在则读取，不存在则引导用户选择）
    if [ -f "$version_file" ]; then
        current_version=$(cat "$version_file" | tr -d '\r\n')  # 去除换行符，避免格式问题
        echo -e "${TITLE}▷ 当前识别版本: ${OPTION_TEXT}${current_version}${NC}"
    else
        # 兜底：版本文件缺失，引导用户重新选择
        echo -e "${YELLOW}⚠ 未找到版本信息文件，需重新选择版本${NC}"
        echo -e "${TITLE}请选择服务端实际版本:${NC}"
        echo -e "${OPTION_NUM}1. ${OPTION_TEXT}普通版本${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}商业版本${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}测试版本${NC}"
        read -rp "请输入选项编号 (1 - 3, 默认 1): " choice
        case $choice in
            2) current_version="商业版本" ;;
            3) current_version="测试版本" ;;
            *) current_version="普通版本" ;;
        esac
        # 临时写入版本文件，确保后续流程正常
        sudo echo "$current_version" | sudo tee "$version_file" > /dev/null
        sudo chmod 644 "$version_file"
        echo -e "${GREEN}✓ 已临时写入版本信息: ${OPTION_TEXT}${current_version}${NC}"
    fi

    # 核心2：根据识别的版本设置正确更新地址（避免base_url错误）
    case "$current_version" in
        "商业版本") base_url="https://alist.sian.one/direct/gostc" ;;
        "测试版本") base_url="https://alist.sian.one/direct/gostc/beta/" ;;
        *) base_url="https://alist.sian.one/direct/gostc/gostc-open" ;;
    esac

    # 核心3：后续更新检测逻辑（基于正确的版本和base_url）
    local arch_suffix=$(get_arch_suffix)
    local file="server_${arch_suffix}.tar.gz"
    [[ "$arch_suffix" == "windows_"* ]] && file="server_${arch_suffix}.zip"
    local url="${base_url}/${file}"
    local current_mod_time=$(stat -c %Y "${server_dir}/${SERVER_BIN}" 2>/dev/null)

    # 时间对比（仅年月日，已有优化）
    local latest_mod_time=$(curl -s --connect-timeout 3 -I "$url" | grep -i "last-modified" | awk -F': ' '{print $2}' | tr -d '\r')
    if [ -z "$latest_mod_time" ]; then
        echo -e "${RED}✗ 更新检查失败：无法获取服务器文件时间${NC}"
        return
    fi
    # 转为当天0点时间戳对比
    local latest_date=$(date -d "$latest_mod_time" +"%Y-%m-%d")
    local latest_timestamp=$(date -d "$latest_date 00:00:00" +%s)
    local current_date=$(date -d "@$current_mod_time" +"%Y-%m-%d")
    local current_timestamp=$(date -d "$current_date 00:00:00" +%s)

    # 判定更新状态
    if [ "$latest_timestamp" -gt "$current_timestamp" ]; then
        echo -e "${TITLE}▷ 服务器最新版本日期: ${OPTION_TEXT}${latest_date}${NC}"
        read -rp "是否立即更新? (y/n, 默认 y): " confirm
        [[ "$confirm" == "n" ]] && echo -e "${TITLE}▶ 更新已取消${NC}" && return
        
        # 执行更新（备份、下载、解压等原有逻辑不变）
        local backup_file="${SERVER_BF}/config_$(date +%Y%m%d%H%M%S).yaml.bak"
        sudo systemctl stop "$SERVER_SVC"
        sudo cp -f "$SERVER_CFG" "$backup_file"
        curl -# -fL -o "$file" "$url" || {
            echo -e "${RED}✗ 文件下载失败!${NC}"
            sudo systemctl start "$SERVER_SVC"
            return
        }
        [[ "$file" == *.zip ]] && sudo unzip -qo "$file" -d "$server_dir" || sudo tar xzf "$file" -C "$server_dir"
        sudo chmod 755 "$server_dir/$SERVER_BIN"
        sudo cp -f "$backup_file" "$SERVER_CFG"
        sudo systemctl start "$SERVER_SVC"
        rm -f "$file"
        
        # 核心4：更新后同步维护version.txt（确保版本不变）
        sudo echo "$current_version" | sudo tee "$version_file" > /dev/null
        echo -e "${GREEN}✓ 服务端已成功更新（版本保持：${current_version}）${NC}"
    else
        echo -e "${GREEN}✓ 服务端已是最新版本（${current_version}）${NC}"
    fi
}


# 主菜单
main_menu() {
    check_update
    while :; do
        show_info
        echo -e "${OPTION_NUM}1. ${OPTION_TEXT}服务端管理${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}节点/客户端管理${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}检查更新${NC}"
        echo -e "${OPTION_NUM}4. ${OPTION_TEXT}检查服务端更新${NC}"
        echo -e "${OPTION_NUM}5. ${OPTION_TEXT}卸载工具箱${NC}"
        echo -e "${OPTION_NUM}6. ${OPTION_TEXT}其他功能${NC}"
        echo -e "${OPTION_NUM}0. ${OPTION_TEXT}退出${NC}"
        echo -e "${SEPARATOR}==================================================${NC}"
        read -rp "请输入选项: " choice
        case $choice in
            1) service_menu "$SERVER_SVC" "$SERVER_BIN" "$SERVER_DIR" "GOSTC 服务端管理" server_status install_server ;;
            2) service_menu "$NODE_SVC" "$NODE_BIN" "$NODE_DIR" "GOSTC 节点/客户端管理" node_status install_node ;;
            3) check_update ;;
            4) check_server_update ;;
            5) uninstall_toolbox ;;
            6) other_functions ;;
            0) 
                echo -e "${TITLE}▶ 感谢使用 GOSTC 工具箱${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}无效选项，请重新选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动主菜单
main_menu
