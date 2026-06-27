#!/bin/sh
set -e

REPO="kavass168/luci-app-timecontrol-25.12"

echo "正在获取最新 Release..."
TAG=$(uclient-fetch -qO- "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
  | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

[ -n "$TAG" ] || { echo "错误：无法获取最新 Release"; exit 1; }

echo "最新标签：$TAG"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

# 获取该 Release 的所有 asset 文件名（从 "name" 字段提取）
ASSETS_JSON=$(uclient-fetch -qO- "https://api.github.com/repos/${REPO}/releases/tags/${TAG}" 2>/dev/null)
APK_NAMES=$(echo "$ASSETS_JSON" | grep -o '"name":"[^"]*\.apk"' | sed 's/"name":"//;s/"//')

if [ -z "$APK_NAMES" ]; then
    echo "错误：该 Release 中没有 .apk 文件。"
    exit 1
fi

echo "找到的 .apk 文件："
echo "$APK_NAMES" | while read name; do echo "  $name"; done

# 精确匹配主包和语言包
MAIN_NAME=$(echo "$APK_NAMES" | grep '^luci-app-timecontrol-.*\.apk$' | head -1)
LANG_NAME=$(echo "$APK_NAMES" | grep '^luci-i18n-timecontrol-zh-cn-.*\.apk$' | head -1)

if [ -z "$MAIN_NAME" ]; then
    echo "错误：未找到主包（期望文件名：luci-app-timecontrol-*.apk）"
    exit 1
fi

echo "下载主包：$MAIN_NAME"
uclient-fetch -qO /tmp/main.apk "$BASE_URL/$MAIN_NAME"

if [ -n "$LANG_NAME" ]; then
    echo "下载语言包：$LANG_NAME"
    uclient-fetch -qO /tmp/lang.apk "$BASE_URL/$LANG_NAME"
    INSTALL_LIST="/tmp/main.apk /tmp/lang.apk"
else
    echo "警告：未找到中文语言包，只安装主包。"
    INSTALL_LIST="/tmp/main.apk"
fi

echo "安装（跳过签名验证）..."
apk add --allow-untrusted $INSTALL_LIST

rm -f /tmp/main.apk /tmp/lang.apk 2>/dev/null

# 刷新 LuCI
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null
/etc/init.d/rpcd reload >/dev/null 2>&1

echo "✅ 安装完成！"
