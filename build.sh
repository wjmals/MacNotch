#!/bin/bash
set -e

echo "🔨 MacNotch 빌드 시작..."

# 1. Release 빌드
swift build -c release

# 빌드된 바이너리 경로 확인
BINARY=$(swift build -c release --show-bin-path)/MacNotch

if [ ! -f "$BINARY" ]; then
    echo "❌ 빌드 실패: 바이너리를 찾을 수 없습니다"
    echo "빌드 경로: $(swift build -c release --show-bin-path)"
    ls "$(swift build -c release --show-bin-path)" 2>/dev/null || true
    exit 1
fi

echo "✅ 바이너리 확인: $BINARY"

# 2. 기존 앱 번들 제거
APP="MacNotch.app"
rm -rf "$APP"

# 3. 앱 번들 구조 생성
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# 4. 실행 파일 복사
cp "$BINARY" "$APP/Contents/MacOS/MacNotch"
chmod +x "$APP/Contents/MacOS/MacNotch"
echo "✅ 실행 파일 복사 완료"

# 5. Info.plist 복사
cp "Sources/MacNotch/Info.plist" "$APP/Contents/Info.plist"
echo "✅ Info.plist 복사 완료"

# 6. 아이콘 생성
ASSET_DIR="Sources/MacNotch/Assets.xcassets/AppIcon.appiconset"
ICONSET="MacNotch.iconset"

if [ -d "$ASSET_DIR" ]; then
    mkdir -p "$ICONSET"
    cp "$ASSET_DIR/icon_16x16.png"    "$ICONSET/icon_16x16.png"    2>/dev/null || true
    cp "$ASSET_DIR/icon_32x32.png"    "$ICONSET/icon_16x16@2x.png" 2>/dev/null || true
    cp "$ASSET_DIR/icon_32x32.png"    "$ICONSET/icon_32x32.png"    2>/dev/null || true
    cp "$ASSET_DIR/icon_64x64.png"    "$ICONSET/icon_32x32@2x.png" 2>/dev/null || true
    cp "$ASSET_DIR/icon_128x128.png"  "$ICONSET/icon_128x128.png"  2>/dev/null || true
    cp "$ASSET_DIR/icon_256x256.png"  "$ICONSET/icon_128x128@2x.png" 2>/dev/null || true
    cp "$ASSET_DIR/icon_256x256.png"  "$ICONSET/icon_256x256.png"  2>/dev/null || true
    cp "$ASSET_DIR/icon_512x512.png"  "$ICONSET/icon_256x256@2x.png" 2>/dev/null || true
    cp "$ASSET_DIR/icon_512x512.png"  "$ICONSET/icon_512x512.png"  2>/dev/null || true
    cp "$ASSET_DIR/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png" 2>/dev/null || true

    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null && \
        echo "✅ 앱 아이콘 생성 완료" || echo "⚠️ 아이콘 생성 생략"
    rm -rf "$ICONSET"
fi

# 7. 코드 서명 (Ad-hoc)
codesign --force --deep --sign "-" "$APP" 2>/dev/null && \
    echo "✅ 코드 서명 완료" || echo "⚠️ 코드 서명 생략"

# 8. 확인
echo ""
echo "✅ MacNotch.app 생성 완료!"
echo "   크기: $(du -sh "$APP" | cut -f1)"
echo ""

# 9. Applications에 설치
echo "📂 Applications에 설치 중..."
rm -rf "/Applications/MacNotch.app"
cp -r "$APP" "/Applications/MacNotch.app"
echo "✅ 설치 완료!"
echo ""
echo "🚀 실행:"
open "/Applications/MacNotch.app"
