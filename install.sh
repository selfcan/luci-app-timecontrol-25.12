#!/bin/sh
set -e

REPO="kavass168/luci-app-timecontrol-25.12"

echo "正在获取最新 Release 信息..."

# 1. 获取最新 Release 的 API 响应
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
JSON=$(uclient-fetch -qO- "$API_URL" 2>/dev/null)

# 2. 提取所有 .apk 文件的下载 URL（用 grep/sed 代替 jq）
#    格式： "browser_download_url": "https://..."
APK_URLS=$(echo "$JSON" | grep -o '"browser_download_url": *"[^"]*\.apk"' | sed 's/.*"\([^"]*\)"/\1/')

if [ -z "$APK_URLS" ]; then
    echo "错误：未找到任何 .apk 文件，请检查仓库或 Release。"
    exit 1
fi

# 3. 筛选出主包和语言包（按文件名匹配）
MAIN_URL=$(echo "$APK_URLS" | grep 'luci-app-timecontrol-.*\.apk' | head -1)
LANG_URL=$(echo "$APK_URLS" | grep 'luci-i18n-timecontrol-zh-cn-.*\.apk' | head -1)

if [ -z "$MAIN_URL" ] || [ -z "$LANG_URL" ]; then
    echo "错误：未找到主包或语言包。"
    echo "找到的 .apk 文件如下："
    echo "$APK_URLS"
    exit 1
fi

echo "找到主包：$(basename "$MAIN_URL")"
echo "找到语言包：$(basename "$LANG_URL")"

echo "下载中..."
uclient-fetch -qO /tmp/main.apk "$MAIN_URL"
uclient-fetch -qO /tmp/lang.apk "$LANG_URL"

echo "安装（跳过签名验证）..."
apk add --allow-untrusted /tmp/main.apk /tmp/lang.apk

rm -f /tmp/main.apk /tmp/lang.apk

# 刷新 LuCI
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null
/etc/init.d/rpcd reload >/dev/null 2>&1

echo "✅ 安装完成！"
