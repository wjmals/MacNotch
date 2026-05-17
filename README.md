<div align="center">

# 🏝️ MacNotch

**맥북 노치를 다이나믹 아일랜드처럼 활용하는 macOS 앱**

![macOS](https://img.shields.io/badge/macOS-14.0+-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![Free](https://img.shields.io/badge/가격-무료-green?style=flat-square)

</div>

---

## ✨ 주요 기능

### 🎵 음악 Live Activity
음악을 재생하면 노치 양옆에 앨범아트와 뮤직바가 자동으로 표시됩니다.
- Spotify, Apple Music 지원
- 노치를 가리지 않고 양옆으로 자연스럽게 확장

### 📅 달력
- 기본 달력 앱의 일정을 노치에서 바로 확인
- 가장 가까운 일정을 소형 뷰에서 즉시 표시
- 한 달 미니 캘린더와 일정 목록

### 🎵 음악 컨트롤
- 재생 중인 곡 정보, 앨범 아트 표시
- ⏮ 이전 / ▶ 재생·일시정지 / ⏭ 다음 컨트롤

### 📁 파일 허브
- 노치로 파일을 드래그 앤 드롭
- 드롭한 파일 바로 열기 / Finder에서 보기 / 공유

### 🖥️ 시스템 모니터
- 실시간 CPU · 메모리 사용량
- 볼륨 슬라이더
- AirPlay 출력 기기 설정

---

## 🖱️ 사용 방법

| 동작 | 결과 |
|------|------|
| 노치에 마우스 올리기 | 패널 펼쳐짐 |
| 마우스 내리기 | 자동으로 닫힘 |
| 패널 밖 클릭 | 즉시 닫힘 |
| 파일 드래그 | 파일 탭 자동 열림 |

---

## 💻 시스템 요구사항

- macOS 14 (Sonoma) 이상
- 노치가 있는 MacBook Pro / MacBook Air 권장
- 노치 없는 Mac에서도 동작

---

## 🚀 설치 방법

### 방법 1 — 다운로드 (권장)

1. [Releases](../../releases) 페이지에서 최신 `MacNotch.zip` 다운로드
2. 압축 해제 후 `MacNotch.app`을 `/Applications` 폴더로 이동
3. 처음 실행 시 아래 명령어 실행 (보안 경고 해제):

```bash
xattr -cr /Applications/MacNotch.app
```

4. `MacNotch.app` 실행 → 메뉴바에 ✦ 아이콘 확인

### 방법 2 — 직접 빌드

```bash
git clone https://github.com/yourusername/MacNotch.git
cd MacNotch
bash build.sh
```

---

## ⚙️ 권한 설정

최초 실행 시 아래 권한을 허용해주세요.

| 권한 | 용도 | 경로 |
|------|------|------|
| 달력 | 일정 표시 | 시스템 설정 → 개인정보 → 달력 |
| 자동화 | 음악 앨범아트 | 시스템 설정 → 개인정보 → 자동화 |

---

## 🔄 로그인 시 자동 실행

**시스템 설정 → 일반 → 로그인 항목 → + → MacNotch.app 추가**

---

## 🛠️ 기술 스택

- **Swift 5.9** + **SwiftUI**
- **EventKit** — 달력 연동
- **MediaRemote** — 음악 정보
- **DistributedNotificationCenter** — 실시간 음악 알림
- **NSPanel** — 노치 오버레이

---

## 📄 라이선스

MIT License — 자유롭게 사용, 수정, 배포 가능합니다.

---

<div align="center">

**⭐ 유용하게 쓰고 계신다면 Star를 눌러주세요!**

</div>
