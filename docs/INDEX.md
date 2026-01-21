# Redmine TX Base 문서 인덱스

Redmine TX Base 플러그인의 전체 문서 목록입니다.

## 📚 주요 문서

### [README.rdoc](../README.rdoc)
전체 플러그인 개요 및 빠른 시작 가이드

**내용:**
- 플러그인 소개
- 제공 기능 개요
- 설치 방법
- 각 라이브러리 기본 사용법

---

## 🔧 JavaScript 라이브러리

### 1. TX Issue Autocomplete (일감 자동완성)

#### [issue_autocomplete_examples.md](./issue_autocomplete_examples.md)
실전 예제 중심의 상세 가이드

**내용:**
- 기본 사용법
- 프로젝트별 검색
- 전체 프로젝트 검색
- 콜백 함수 활용
- 버튼 활성화 연동
- 여러 일감 처리
- parseIssueIds 함수 사용법
- 실시간 유효성 검사

**대상:** 일감 자동완성 기능을 구현하려는 개발자

---

### 2. TX Timeline Grid (웹 타임라인 렌더러)

#### [tx_timeline_grid_guide.md](./tx_timeline_grid_guide.md)
웹 타임라인 렌더링 완전 가이드

**내용:**
- 기본 사용법
- JSON 데이터 구조
- API 레퍼런스
- 세로선 마커 사용법
- 이벤트 처리 (클릭 이벤트)
- 스크롤 옵션
- CSS 커스터마이징
- 실전 예제 (기본, 마커, muted 상태, 동적 업데이트)
- TX XLSX Exporter와 함께 사용하기

**대상:** 웹에서 타임라인을 표시하려는 개발자

**의존성:** 없음 (순수 JavaScript)

---

### 3. TX XLSX Exporter (엑셀 익스포터)

#### [tx_xlsx_exporter_guide.md](./tx_xlsx_exporter_guide.md)
엑셀 파일 생성 완전 가이드

**내용:**
- 기본 사용법
- JSON 데이터 구조 (상세)
- API 레퍼런스
- 색상 처리 (자동 폰트 색상 계산)
- 실전 예제 (프로젝트 로드맵, 자동 날짜 계산, muted 상태)
- 에러 처리

**대상:** 로드맵을 엑셀 파일로 내보내려는 개발자

**의존성:** ExcelJS 라이브러리 (필수)

---

## 📝 변경 이력

### [CHANGELOG.md](../CHANGELOG.md)
버전별 변경 사항 및 추가 기능

**내용:**
- 최신 변경 사항
- 새로운 기능 추가
- 버그 수정
- 문서 업데이트

---

## 🎯 빠른 참조

### 라이브러리 선택 가이드

| 목적 | 사용할 라이브러리 | 문서 |
|------|------------------|------|
| 일감 ID 자동완성 | TX Issue Autocomplete | [예제 문서](./issue_autocomplete_examples.md) |
| 웹 타임라인 표시 | TX Timeline Grid | [가이드](./tx_timeline_grid_guide.md) |
| 엑셀 파일 생성 | TX XLSX Exporter | [가이드](./tx_xlsx_exporter_guide.md) |
| 웹 + 엑셀 동시 제공 | Timeline Grid + XLSX Exporter | 각 가이드 참조 |

### 데이터 구조

TX Timeline Grid와 TX XLSX Exporter는 **동일한 JSON 구조**를 사용합니다.

```javascript
{
  options: {
    categoryLabel: "카테고리",
    eventLabel: "이벤트"
  },
  legends: [ /* 범례 배열 */ ],
  categories: [
    {
      name: "카테고리명",
      customColor: "#4A90E2",
      events: [
        {
          name: "이벤트명",
          schedules: [
            {
              name: "스케줄명",
              startDate: "2024-01-15",
              endDate: "2024-01-30",
              issue: "#101",
              doneRatio: "80"
            }
          ]
        }
      ]
    }
  ]
}
```

자세한 구조는 각 라이브러리 가이드 참조.

---

## 📖 학습 순서 추천

### 초보자

1. [README.rdoc](../README.rdoc) - 플러그인 개요 파악
2. 필요한 라이브러리의 가이드 "기본 사용법" 섹션 읽기
3. "실전 예제" 섹션에서 유사한 예제 찾아 적용

### 중급자

1. 필요한 라이브러리의 전체 가이드 읽기
2. "API 레퍼런스" 섹션으로 상세 스펙 확인
3. JavaScript 파일의 JSDoc 주석 참고

### 고급자

1. 전체 문서 읽기
2. JavaScript 소스 코드 직접 분석
3. 커스터마이징 및 확장

---

## 🔗 관련 링크

- **GitHub**: (프로젝트 저장소 URL)
- **이슈 트래커**: (이슈 트래커 URL)
- **ExcelJS 문서**: https://github.com/exceljs/exceljs

---

## 📧 문의

문제가 발생하거나 질문이 있으면 이슈 트래커에 등록해주세요.

---

**최종 업데이트:** 2026-01-20  
**플러그인 버전:** 1.0.0
