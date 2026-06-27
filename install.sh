#!/bin/sh
set -e

REPO="kavass168/luci-app-timecontrol-25.12"
TAG="main-luci-app-timecontrol"

echo "正在获取 Release 文件列表..."
# 获取 Release 页面的 HTML，提取所有 .apk 文件名
PAGE_URL="https://github.com/${REPO}/releases/tag/${TAG}"
APK_NAMES=$(uclient-fetch -qO- "$PAGE_URL" 2>/dev/null | \
    grep -o 'href="[^"]*\.apk"' | \
    sed 's/href="\/[^\/]*\/[^\/]*\/releases\/download\/[^\/]*\///;s/"//' | \
    sort -u)

if [ -z "$APK_NAMES" ]; then
    echo "错误：未找到任何 .apk 文件。"
    echo "请检查 Release 页面：$PAGE_URL"
    exit 1
fi

echo "找到以下 .apk 文件："
echo "$APK_NAMES"

# 筛选主包和语言包
MAIN_FILE=$(echo "$APK_NAMES" | grep '^luci-app-timecontrol-.*\.apk$' | head -1)
LANG_FILE=$(echo "$APK_NAMES" | grep '^luci-i18n-timecontrol-zh-cn-.*\.apk$' | head -1)

if [ -z "$MAIN_FILE" ] || [ -z "$LANG_FILE" ]; then
    echo "错误：未找到主包或语言包。"
    exit 1
fi

BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

echo "下载主包：$MAIN_FILE"
uclient-fetch -qO /tmp/main.apk "$BASE_URL/$MAIN_FILE"

echo "下载语言包：$LANG_FILE"
uclient-fetch -qO /tmp/lang.apk "$BASE_URL/$LANG_FILE"

echo "安装（跳过签名验证）..."
apk add --allow-untrusted /tmp/main.apk /tmp/lang.apk

rm -f /tmp/main.apk /tmp/lang.apk

# 刷新 LuCI
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null
/etc/init.d/rpcd reload >/dev/null 2>&1

echo "✅ 安装完成！"
