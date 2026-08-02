#!/bin/bash
set -euo pipefail

VERSION="${1:-latest}"
REPO="xdfnet/iCodex"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

echo "==> 下载 iCodex $VERSION..."

# 确定下载 URL
if [ "$VERSION" = "latest" ]; then
    URL="https://github.com/$REPO/releases/latest/download/iCodex.zip"
else
    URL="https://github.com/$REPO/releases/download/v$VERSION/iCodex.zip"
fi

# 下载到临时目录
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

echo "   从 $URL 下载..."
curl -sL -o "$TMPDIR/iCodex.zip" "$URL"

echo "==> 安装到 $INSTALL_DIR..."
unzip -qo "$TMPDIR/iCodex.zip" -d "$TMPDIR"
if [ -d "$INSTALL_DIR/iCodex.app" ]; then
    rm -rf "$INSTALL_DIR/iCodex.app"
fi
mv "$TMPDIR/iCodex.app" "$INSTALL_DIR/"

echo ""
echo "✅ iCodex 已安装到 $INSTALL_DIR/iCodex.app"
echo ""
echo "运行: open $INSTALL_DIR/iCodex.app"
echo ""
echo "首次运行请右键 -> 打开（未签名应用需要确认）"
