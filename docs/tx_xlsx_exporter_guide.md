# TX XLSX Exporter 사용 가이드

## 개요

TX XLSX Exporter는 ExcelJS 라이브러리를 기반으로 로드맵 타임라인과 스케줄 리스트를 엑셀 파일로 내보내는 공통 라이브러리입니다.

**주요 기능:**
- 📊 로드맵 타임라인 시트 생성
- 📋 스케줄 리스트 시트 생성
- 🎨 카테고리별 색상 구분
- 🔗 일감 하이퍼링크 연결
- 📝 셀 메모(코멘트) 지원
- 📌 범례(Legend) 표시
- 🗓️ 자동 날짜 범위 계산

## 의존성

```html
<!-- ExcelJS 라이브러리 (필수) -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/exceljs/4.3.0/exceljs.min.js"></script>

<!-- TX XLSX Exporter -->
<%= javascript_include_tag 'tx_xlsx_exporter', plugin: 'redmine_tx_0_base' %>
```

## 기본 사용법

### 1. 간단한 예제

```javascript
// JSON 데이터 준비
var jsonData = {
  options: {
    categoryLabel: "팀",
    eventLabel: "담당자",
    rowHeight: 30
  },
  categories: [
    {
      name: "백엔드 개발",
      customColor: "#4A90E2",
      events: [
        {
          name: "API 개발",
          schedules: [
            {
              name: "사용자 API",
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
};

// 엑셀 다운로드
TxXlsxExporter.exportToXlsx(jsonData, '로드맵_2024')
  .then(function() {
    console.log('다운로드 완료');
  })
  .catch(function(error) {
    console.error('다운로드 실패:', error);
  });
```

### 2. 수동으로 워크북 생성

```javascript
var workbook = new ExcelJS.Workbook();

// 타임라인 시트 생성
TxXlsxExporter.createRoadmapTimelineSheet(workbook, jsonData);

// 스케줄 리스트 시트 생성
TxXlsxExporter.createScheduleListSheet(workbook, jsonData);

// 다운로드
workbook.xlsx.writeBuffer().then(function(buffer) {
  var blob = new Blob([buffer], { 
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' 
  });
  var url = URL.createObjectURL(blob);
  var a = document.createElement('a');
  a.href = url;
  a.download = '로드맵.xlsx';
  a.click();
  URL.revokeObjectURL(url);
});
```

## JSON 데이터 구조

### 전체 구조

```javascript
{
  options: {                      // 선택사항
    startDate: "2024-01-01",      // 시작일 (생략 시 자동 계산)
    endDate: "2024-12-31",        // 종료일 (생략 시 자동 계산)
    categoryLabel: "카테고리",     // A열 헤더 (기본값: "카테고리")
    eventLabel: "이벤트",          // B열 헤더 (기본값: "이벤트")
    rowHeight: 30,                // 행 높이 (기본값: 30)
    showScheduleName: true        // 스케줄 바에 이름 표시 (기본값: true)
  },
  legends: [                      // 선택사항: 범례
    {
      title: "#12345 : 백엔드 개발",
      color: "#4A90E2",
      url: "https://example.com/issues/12345"  // 선택사항
    }
  ],
  categories: [                   // 필수
    {
      name: "백엔드 개발",
      customColor: "#4A90E2",     // 선택사항
      events: [
        {
          name: "API 개발",
          schedules: [
            {
              name: "사용자 API",
              startDate: "2024-01-15",
              endDate: "2024-01-30",
              issue: "#101",              // 선택사항
              doneRatio: "80",            // 선택사항
              customColor: "#FF6B6B",     // 선택사항
              customFontColor: "#FFFFFF", // 선택사항
              isMuted: false,             // 선택사항
              memo: "추가 설명",           // 선택사항: 셀 메모
              link: "https://..."         // 선택사항: 하이퍼링크
            }
          ]
        }
      ]
    }
  ]
}
```

### 필드 설명

#### options (선택사항)

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `startDate` | string | 자동 계산 | 타임라인 시작일 (YYYY-MM-DD) |
| `endDate` | string | 자동 계산 | 타임라인 종료일 (YYYY-MM-DD) |
| `categoryLabel` | string | "카테고리" | 첫 번째 열 헤더 텍스트 |
| `eventLabel` | string | "이벤트" | 두 번째 열 헤더 텍스트 |
| `rowHeight` | number | 30 | 데이터 행의 높이 (픽셀) |
| `showScheduleName` | boolean | true | 스케줄 바에 이름 표시 여부 |

**참고:** `startDate`와 `endDate`를 생략하면 `categories`의 모든 스케줄 날짜로부터 자동으로 계산됩니다.

#### legends (선택사항)

범례 섹션은 타임라인 시트 하단에 표시됩니다.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `title` | string | 필수 | 범례 제목 |
| `color` | string | 필수 | 배경 색상 (#RRGGBB) |
| `url` | string | 선택 | 클릭 시 이동할 URL |

#### categories (필수)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | string | 필수 | 카테고리 이름 |
| `customColor` | string | 선택 | 카테고리 배경 색상 (#RRGGBB) |
| `events` | array | 필수 | 이벤트 목록 |

#### events

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | string | 필수 | 이벤트 이름 |
| `schedules` | array | 필수 | 스케줄 목록 |

#### schedules

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | string | 필수 | 스케줄 이름 |
| `startDate` | string | 필수 | 시작일 (YYYY-MM-DD) |
| `endDate` | string | 필수 | 종료일 (YYYY-MM-DD) |
| `issue` | string | 선택 | 일감 번호 |
| `doneRatio` | string | 선택 | 완료율 (%) |
| `customColor` | string | 선택 | 스케줄 배경 색상 (#RRGGBB) |
| `customFontColor` | string | 선택 | 폰트 색상 (#RRGGBB) |
| `isMuted` | boolean | 선택 | muted 상태 (굵기 제거) |
| `memo` | string | 선택 | 셀 메모(코멘트) 내용 |
| `link` | string | 선택 | 하이퍼링크 URL |

## API 레퍼런스

### TxXlsxExporter.exportToXlsx(jsonData, fileName)

JSON 데이터로부터 엑셀 파일을 생성하고 다운로드합니다.

**파라미터:**
- `jsonData` (Object, 필수) - JSON 데이터
- `fileName` (string, 선택) - 파일명 (확장자 제외, 기본값: 'roadmap')

**반환값:**
- `Promise` - 다운로드 완료 Promise

**예제:**
```javascript
TxXlsxExporter.exportToXlsx(jsonData, '2024_로드맵')
  .then(function() {
    alert('다운로드 완료');
  })
  .catch(function(error) {
    alert('오류: ' + error.message);
  });
```

### TxXlsxExporter.createRoadmapTimelineSheet(workbook, jsonData)

워크북에 로드맵 타임라인 시트를 추가합니다.

**파라미터:**
- `workbook` (ExcelJS.Workbook, 필수) - ExcelJS 워크북 객체
- `jsonData` (Object, 필수) - JSON 데이터

**반환값:** 없음

**생성되는 시트:**
- 시트 이름: "로드맵 타임라인"
- 구조: 월/일 헤더 + 카테고리/이벤트 + 스케줄 바
- 특징: 틀 고정 (상위 2행, 좌측 2열)

### TxXlsxExporter.createScheduleListSheet(workbook, jsonData)

워크북에 스케줄 리스트 시트를 추가합니다.

**파라미터:**
- `workbook` (ExcelJS.Workbook, 필수) - ExcelJS 워크북 객체
- `jsonData` (Object, 필수) - JSON 데이터

**반환값:** 없음

**생성되는 시트:**
- 시트 이름: "스케줄 리스트"
- 컬럼: 카테고리, 이벤트, 스케줄명, 시작일, 종료일, 이슈, 기간, 완료율

## 색상 처리

### 자동 폰트 색상 계산

배경 색상의 밝기를 자동으로 계산하여 폰트 색상을 결정합니다:
- 밝은 배경 (brightness > 128): 검정색 폰트
- 어두운 배경 (brightness ≤ 128): 흰색 폰트

### 색상 우선순위

스케줄 바의 배경 색상은 다음 우선순위로 결정됩니다:

1. `schedule.customColor` (스케줄 개별 색상)
2. `category.customColor` (카테고리 색상)
3. 배경 색상 없음

폰트 색상:
1. `schedule.customFontColor` (명시적 폰트 색상)
2. 배경 색상 밝기 기반 자동 계산

## 실전 예제

### 예제 1: 프로젝트 로드맵

```javascript
var projectRoadmap = {
  options: {
    categoryLabel: "프로젝트",
    eventLabel: "팀",
    rowHeight: 35,
    showScheduleName: true
  },
  legends: [
    {
      title: "#12345 : 사용자 관리 시스템",
      color: "#4A90E2",
      url: "http://redmine.example.com/issues/12345"
    },
    {
      title: "#12346 : 상품 관리 시스템",
      color: "#50C878",
      url: "http://redmine.example.com/issues/12346"
    }
  ],
  categories: [
    {
      name: "사용자 관리 시스템",
      customColor: "#4A90E2",
      events: [
        {
          name: "백엔드팀",
          schedules: [
            {
              name: "API 개발",
              startDate: "2024-01-15",
              endDate: "2024-02-15",
              issue: "#101",
              doneRatio: "75",
              memo: "진행 중 - 테스트 필요"
            },
            {
              name: "DB 설계",
              startDate: "2024-01-10",
              endDate: "2024-01-20",
              issue: "#102",
              doneRatio: "100"
            }
          ]
        },
        {
          name: "프론트엔드팀",
          schedules: [
            {
              name: "UI 구현",
              startDate: "2024-02-01",
              endDate: "2024-02-28",
              issue: "#103",
              doneRatio: "50",
              link: "http://redmine.example.com/issues/103"
            }
          ]
        }
      ]
    },
    {
      name: "상품 관리 시스템",
      customColor: "#50C878",
      events: [
        {
          name: "백엔드팀",
          schedules: [
            {
              name: "상품 API",
              startDate: "2024-02-20",
              endDate: "2024-03-20",
              issue: "#201",
              doneRatio: "30",
              customColor: "#FF6B6B"  // 개별 색상 지정
            }
          ]
        }
      ]
    }
  ]
};

// 다운로드
TxXlsxExporter.exportToXlsx(projectRoadmap, '프로젝트_로드맵_2024');
```

### 예제 2: 자동 날짜 범위 계산

```javascript
// startDate, endDate를 생략하면 자동으로 계산됩니다
var autoDateData = {
  options: {
    // startDate, endDate 생략
    categoryLabel: "마일스톤",
    eventLabel: "일감"
  },
  categories: [
    {
      name: "Phase 1",
      events: [
        {
          name: "기획",
          schedules: [
            {
              name: "요구사항 분석",
              startDate: "2024-01-01",  // 가장 이른 날짜
              endDate: "2024-01-15"
            }
          ]
        }
      ]
    },
    {
      name: "Phase 2",
      events: [
        {
          name: "개발",
          schedules: [
            {
              name: "최종 배포",
              startDate: "2024-06-01",
              endDate: "2024-06-30"     // 가장 늦은 날짜
            }
          ]
        }
      ]
    }
  ]
};

// 2024-01-01 ~ 2024-06-30 범위로 자동 계산됩니다
TxXlsxExporter.exportToXlsx(autoDateData, '자동날짜');
```

### 예제 3: muted 상태 사용

```javascript
var mutedExample = {
  categories: [
    {
      name: "개발",
      customColor: "#4A90E2",
      events: [
        {
          name: "담당자 A",
          schedules: [
            {
              name: "메인 작업",
              startDate: "2024-01-10",
              endDate: "2024-01-20",
              doneRatio: "80"
              // isMuted 없음: 굵은 폰트
            },
            {
              name: "참고 작업",
              startDate: "2024-01-25",
              endDate: "2024-01-30",
              doneRatio: "100",
              isMuted: true,              // muted 상태
              customFontColor: "#999999"  // 연한 회색
              // 굵기 제거, 연한 회색으로 표시
            }
          ]
        }
      ]
    }
  ]
};
```

## 주의사항

1. **ExcelJS 의존성**: ExcelJS 라이브러리가 먼저 로드되어야 합니다.
2. **날짜 형식**: 날짜는 반드시 `YYYY-MM-DD` 형식이어야 합니다.
3. **색상 형식**: 색상은 `#RRGGBB` 형식의 헥스 코드를 사용합니다.
4. **브라우저 호환성**: 최신 브라우저에서 동작하며, IE는 지원하지 않습니다.
5. **파일 크기**: 매우 큰 데이터(1000+ 행)는 생성 시간이 오래 걸릴 수 있습니다.

## 에러 처리

```javascript
TxXlsxExporter.exportToXlsx(jsonData, 'filename')
  .then(function() {
    console.log('성공');
  })
  .catch(function(error) {
    console.error('엑셀 생성 실패:', error);
    
    if (error.message.includes('ExcelJS')) {
      alert('ExcelJS 라이브러리가 로드되지 않았습니다.');
    } else if (error.message.includes('날짜')) {
      alert('날짜 데이터가 올바르지 않습니다.');
    } else {
      alert('엑셀 생성 중 오류가 발생했습니다.');
    }
  });
```

## 참고 자료

- [ExcelJS Documentation](https://github.com/exceljs/exceljs)
- [TX Timeline Grid Guide](./tx_timeline_grid_guide.md) - 동일한 JSON 구조 사용
- [README.rdoc](../README.rdoc) - 전체 문서

---

**버전:** 1.0.0  
**최종 업데이트:** 2026-01-20
