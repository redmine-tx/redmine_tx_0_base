# TX Timeline Grid 사용 가이드

## 개요

TX Timeline Grid는 순수 JavaScript로 작성된 웹 기반 타임라인 렌더러입니다. 로드맵과 스케줄을 시각적으로 표현하며, TX XLSX Exporter와 동일한 JSON 데이터 구조를 사용합니다.

**주요 기능:**
- 📊 웹 타임라인 그리드 렌더링
- 🎨 카테고리별 색상 구분
- 📍 세로선 마커 (Today, 마일스톤 등)
- 📌 범례(Legend) 표시
- 🖱️ 스케줄 클릭 이벤트
- 📱 반응형 스크롤
- ⚡ 순수 JavaScript (외부 의존성 없음)

## 의존성

```html
<!-- TX Timeline Grid -->
<%= javascript_include_tag 'tx_timeline_grid', plugin: 'redmine_tx_0_base' %>
<%= stylesheet_link_tag 'tx_timeline_grid', plugin: 'redmine_tx_0_base' %>
```

**특징:** jQuery 등 외부 라이브러리 없이 순수 JavaScript로 동작합니다.

## 기본 사용법

### 1. HTML 컨테이너 준비

```html
<div id="timeline-container"></div>
```

### 2. JavaScript로 렌더링

```javascript
// JSON 데이터 준비 (TX XLSX Exporter와 동일한 구조)
var jsonData = {
  options: {
    categoryLabel: "팀",
    eventLabel: "담당자",
    showScheduleName: true,
    holidays: ["2024-01-01", "2024-03-01", "2024-05-05"]  // 공휴일 배열 (선택)
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
              doneRatio: "80",
              link: "http://redmine.example.com/issues/101"
            }
          ]
        }
      ]
    }
  ]
};

// 타임라인 렌더링
TxTimelineGrid.render('#timeline-container', jsonData);
```

## JSON 데이터 구조

TX XLSX Exporter와 **동일한 JSON 구조**를 사용합니다.

자세한 데이터 구조는 [TX XLSX Exporter Guide](./tx_xlsx_exporter_guide.md#json-데이터-구조)를 참조하세요.

### 추가 필드

TX Timeline Grid에서 추가로 지원하는 필드:

#### options

| 필드 | 타입 | 설명 |
|------|------|------|
| `holidays` | array | 공휴일 날짜 배열 (YYYY-MM-DD 형식) |

#### schedules

| 필드 | 타입 | 설명 |
|------|------|------|
| `link` | string | 스케줄 클릭 시 이동할 URL |
| `issueId` | string/number | 일감 ID (툴팁 표시용) |
| `customFontColor` | string | 폰트 색상 (#RRGGBB) |
| `isMuted` | boolean | muted 상태 (흐리게 표시) |

## API 레퍼런스

### TxTimelineGrid.render(container, jsonData, renderOptions)

타임라인 그리드를 렌더링합니다.

**파라미터:**
- `container` (string|HTMLElement, 필수) - 컨테이너 선택자 또는 DOM 요소
- `jsonData` (Object, 필수) - JSON 데이터
- `renderOptions` (Object, 선택) - 렌더링 옵션

**렌더링 옵션 (renderOptions):**

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `showLegend` | boolean | true | 범례 표시 여부 |
| `verticalMarkers` | array | [] | 추가 세로선 마커 |
| `scrollToToday` | boolean | false | Today 위치로 스크롤 |
| `scrollAlign` | string | 'start' | 스크롤 정렬 ('start', 'center', 'end') |
| `scrollBehavior` | string | 'smooth' | 스크롤 동작 ('auto', 'smooth') |

**반환값:** 없음

**예제:**

```javascript
// 기본 렌더링
TxTimelineGrid.render('#timeline', jsonData);

// 옵션 사용
TxTimelineGrid.render('#timeline', jsonData, {
  showLegend: true,
  scrollToToday: true,
  scrollAlign: 'center',
  scrollBehavior: 'auto',
  verticalMarkers: [
    {
      date: '2024-06-30',
      name: 'v1.0 출시',
      color: '#FF6B6B',
      side: 'right'
    }
  ]
});

// DOM 요소 직접 전달
var element = document.getElementById('timeline');
TxTimelineGrid.render(element, jsonData);
```

## 세로선 마커

타임라인에 세로 점선을 표시할 수 있습니다.

### 마커 데이터 구조

```javascript
{
  date: "2024-06-30",    // 날짜 (YYYY-MM-DD) 또는 Date 객체
  name: "v1.0 출시",     // 마커 이름
  color: "#FF6B6B",      // 선 색상 (기본값: #e00000)
  side: "right"          // 선 위치: 'left' | 'right' (기본값: right)
}
```

### 마커 사용 예제

```javascript
// jsonData.options에 포함
var jsonData = {
  options: {
    verticalMarkers: [
      {
        date: '2024-03-31',
        name: 'Q1 종료',
        color: '#9999ff',
        side: 'right'
      },
      {
        date: '2024-06-30',
        name: 'Q2 종료',
        color: '#9999ff',
        side: 'right'
      }
    ]
  },
  categories: [ /* ... */ ]
};

// 또는 renderOptions에 추가
TxTimelineGrid.render('#timeline', jsonData, {
  verticalMarkers: [
    {
      date: '2024-12-25',
      name: 'v2.0 출시',
      color: '#FF6B6B'
    }
  ]
});

// Today 마커는 자동으로 추가됩니다
```

### Today 마커

현재 날짜(`Today`)는 자동으로 빨간색 점선으로 표시됩니다.

## 이벤트 처리

### 스케줄 클릭 이벤트

스케줄 바를 클릭하면 `tx-schedule-click` 커스텀 이벤트가 발생합니다.

```javascript
// 타임라인 렌더링
TxTimelineGrid.render('#timeline-container', jsonData);

// 클릭 이벤트 리스너 등록
document.getElementById('timeline-container').addEventListener('tx-schedule-click', function(e) {
  console.log('클릭된 스케줄:', e.detail);
  
  // e.detail 구조:
  // {
  //   scheduleName: "사용자 API",
  //   issueId: "101",
  //   link: "http://...",
  //   startDate: "2024-01-15",
  //   endDate: "2024-01-30",
  //   categoryName: "백엔드 개발",
  //   eventName: "API 개발"
  // }
  
  // 링크가 있으면 자동으로 이동하지만, 원하면 preventDefault로 막을 수 있음
  if (e.detail.issueId) {
    // 커스텀 동작
    alert('일감 #' + e.detail.issueId + ' 클릭');
  }
});
```

### 링크 처리

- `schedule.link`가 있으면 클릭 시 해당 URL로 이동
- 이벤트 리스너에서 `preventDefault()`를 호출하면 기본 동작 차단 가능

## 스크롤 옵션

### Today 위치로 자동 스크롤

```javascript
TxTimelineGrid.render('#timeline', jsonData, {
  scrollToToday: true,      // Today로 스크롤
  scrollAlign: 'center',    // 화면 중앙에 배치
  scrollBehavior: 'smooth'  // 부드러운 스크롤
});
```

### scrollAlign 옵션

- `'start'`: Today가 화면 좌측에 위치
- `'center'`: Today가 화면 중앙에 위치 (기본값)
- `'end'`: Today가 화면 우측에 위치

### scrollBehavior 옵션

- `'auto'`: 즉시 스크롤
- `'smooth'`: 부드러운 애니메이션 스크롤

## 공휴일 표시

타임라인에서 공휴일을 일요일처럼 빨간색으로 표시할 수 있습니다.

### 공휴일 설정

```javascript
var jsonData = {
  options: {
    categoryLabel: "팀",
    eventLabel: "담당자",
    holidays: [
      "2024-01-01",  // 신정
      "2024-03-01",  // 삼일절
      "2024-05-05",  // 어린이날
      "2024-06-06",  // 현충일
      "2024-08-15",  // 광복절
      "2024-10-03",  // 개천절
      "2024-12-25"   // 크리스마스
    ]
  },
  categories: [ /* ... */ ]
};

TxTimelineGrid.render('#timeline', jsonData);
```

### Redmine 연동 예제

Redmine의 Holiday API를 사용하여 공휴일 데이터를 가져올 수 있습니다:

```ruby
<%
  # 타임라인 표시 기간 계산
  timeline_start_date = display_start_date
  timeline_end_date = max_due_date + 60.days

  # 공휴일 조회 (TxBaseHelper::HolidayApi 사용)
  holidays = if TxBaseHelper::HolidayApi.available?
    holiday_data = TxBaseHelper::HolidayApi.for_date_range(timeline_start_date, timeline_end_date)
    # [[date, name], ...] 형태를 날짜 문자열 배열로 변환
    holiday_data.map { |date, name| date.strftime('%Y-%m-%d') }
  else
    []
  end
%>

<script>
var jsonData = {
  options: {
    categoryLabel: "팀",
    eventLabel: "담당자",
    holidays: <%= holidays.to_json.html_safe %>
  },
  categories: [ /* ... */ ]
};

TxTimelineGrid.render('#timeline-grid-container', jsonData);
</script>
```

### 공휴일 표시 규칙

- **공휴일**: 빨간색 배경 (#ffe6e6), 빨간색 텍스트 (#ff0000)
- **일요일**: 공휴일과 동일한 스타일
- **토요일**: 파란색 배경 (#e6f2ff), 파란색 텍스트 (#0000ff)
- **우선순위**: 공휴일 > 일요일 > 토요일 (겹치는 경우 공휴일 스타일 우선)

## CSS 커스터마이징

### 기본 스타일 오버라이드

```css
/* 스케줄 바 높이 조정 */
.tx-schedule-bar {
  height: 20px !important;
}

/* 헤더 배경색 변경 */
.tx-timeline-header th {
  background-color: #f0f0f0 !important;
}

/* 주말 및 공휴일 색상 커스터마이징 */
.tx-day-cell.tx-sunday,
.tx-day-cell.tx-holiday {
  color: #cc0000 !important;
  background-color: #ffcccc !important;
}

.tx-day-cell.tx-saturday {
  color: #0000cc !important;
  background-color: #ccddff !important;
}

/* Today 마커 색상 변경 */
.tx-timeline-marker-lines div[style*="border-left:2px dashed #e00000"] {
  border-color: #ff0000 !important;
}
```

### 범례 스타일

```css
/* 범례 위치 조정 */
.tx-timeline-legends {
  margin-top: 30px !important;
}

/* 범례 아이템 크기 */
.tx-legend-item {
  padding: 8px 16px !important;
  font-size: 14px !important;
}
```

## 실전 예제

### 예제 1: 기본 타임라인

```javascript
var basicTimeline = {
  options: {
    categoryLabel: "프로젝트",
    eventLabel: "팀"
  },
  categories: [
    {
      name: "백엔드 개발",
      customColor: "#4A90E2",
      events: [
        {
          name: "개발팀",
          schedules: [
            {
              name: "API 개발",
              startDate: "2024-01-15",
              endDate: "2024-02-15",
              issue: "#101",
              doneRatio: "75"
            }
          ]
        }
      ]
    }
  ]
};

TxTimelineGrid.render('#timeline', basicTimeline);
```

### 예제 2: 마커와 범례 포함

```javascript
var advancedTimeline = {
  options: {
    categoryLabel: "마일스톤",
    eventLabel: "담당자",
    verticalMarkers: [
      {
        date: '2024-03-31',
        name: 'Alpha 릴리스',
        color: '#9999ff',
        side: 'right'
      },
      {
        date: '2024-06-30',
        name: 'Beta 릴리스',
        color: '#9999ff',
        side: 'right'
      }
    ]
  },
  legends: [
    {
      title: "#12345 : 사용자 관리",
      color: "#4A90E2",
      url: "http://redmine.example.com/issues/12345"
    },
    {
      title: "#12346 : 상품 관리",
      color: "#50C878",
      url: "http://redmine.example.com/issues/12346"
    }
  ],
  categories: [
    {
      name: "Phase 1",
      customColor: "#4A90E2",
      events: [
        {
          name: "개발자 A",
          schedules: [
            {
              name: "사용자 API",
              startDate: "2024-01-10",
              endDate: "2024-02-10",
              link: "http://redmine.example.com/issues/101",
              doneRatio: "80"
            }
          ]
        }
      ]
    },
    {
      name: "Phase 2",
      customColor: "#50C878",
      events: [
        {
          name: "개발자 B",
          schedules: [
            {
              name: "상품 API",
              startDate: "2024-03-01",
              endDate: "2024-04-01",
              link: "http://redmine.example.com/issues/201",
              doneRatio: "50"
            }
          ]
        }
      ]
    }
  ]
};

TxTimelineGrid.render('#timeline', advancedTimeline, {
  scrollToToday: true,
  scrollAlign: 'center'
});
```

### 예제 3: muted 상태와 폰트 색상

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
              // 기본 스타일
            },
            {
              name: "참고 작업",
              startDate: "2024-01-25",
              endDate: "2024-01-30",
              doneRatio: "100",
              isMuted: true,              // 흐리게 표시
              customFontColor: "#AAAAAA"  // 연한 회색
            }
          ]
        }
      ]
    }
  ]
};

TxTimelineGrid.render('#timeline', mutedExample);
```

### 예제 4: 클릭 이벤트 처리

```javascript
var jsonData = {
  categories: [
    {
      name: "개발",
      events: [
        {
          name: "개발자",
          schedules: [
            {
              name: "작업 1",
              startDate: "2024-01-10",
              endDate: "2024-01-20",
              issueId: "101",
              link: "http://redmine.example.com/issues/101"
            }
          ]
        }
      ]
    }
  ]
};

TxTimelineGrid.render('#timeline-container', jsonData);

// 클릭 이벤트 처리
document.getElementById('timeline-container').addEventListener('tx-schedule-click', function(e) {
  console.log('클릭:', e.detail.scheduleName);
  
  // 기본 링크 이동을 막고 커스텀 동작 수행
  e.preventDefault();
  
  // 모달 열기 등
  showIssueModal(e.detail.issueId);
});
```

### 예제 5: 동적 업데이트

```javascript
// 초기 렌더링
TxTimelineGrid.render('#timeline', jsonData);

// 데이터 변경 후 재렌더링
setTimeout(function() {
  // 새로운 데이터
  var newData = {
    /* 업데이트된 데이터 */
  };
  
  // 재렌더링 (기존 내용 자동 교체)
  TxTimelineGrid.render('#timeline', newData);
}, 3000);
```

## TX XLSX Exporter와 함께 사용

동일한 JSON 데이터로 웹 타임라인과 엑셀 파일을 모두 생성할 수 있습니다.

```javascript
var jsonData = {
  options: {
    categoryLabel: "팀",
    eventLabel: "담당자"
  },
  categories: [
    /* 데이터 */
  ]
};

// 1. 웹 타임라인 렌더링
TxTimelineGrid.render('#timeline-grid-container', jsonData, {
  scrollToToday: true,
  scrollAlign: 'center'
});

// 2. 엑셀 다운로드 버튼
$('#export-xlsx-btn').click(function() {
  var today = new Date();
  var dateStr = today.getFullYear() + 
                String(today.getMonth() + 1).padStart(2, '0') + 
                String(today.getDate()).padStart(2, '0');
  var fileName = '일정요약_' + dateStr;
  
  TxXlsxExporter.exportToXlsx(jsonData, fileName)
    .then(function() {
      console.log('엑셀 다운로드 완료');
    })
    .catch(function(error) {
      console.error('엑셀 다운로드 오류:', error);
      alert('엑셀 다운로드 중 오류가 발생했습니다.');
    });
});
```

## 주의사항

1. **컨테이너 크기**: 컨테이너의 너비가 충분해야 타임라인이 제대로 표시됩니다.
2. **날짜 형식**: 날짜는 반드시 `YYYY-MM-DD` 형식이어야 합니다.
3. **색상 형식**: 색상은 `#RRGGBB` 형식의 헥스 코드를 사용합니다.
4. **브라우저 호환성**: IE는 지원하지 않으며, 최신 브라우저에서 동작합니다.
5. **성능**: 매우 많은 스케줄(1000+)이 있을 경우 렌더링 시간이 오래 걸릴 수 있습니다.

## 에러 처리

```javascript
try {
  TxTimelineGrid.render('#timeline', jsonData);
} catch (error) {
  console.error('타임라인 렌더링 오류:', error);
  
  if (error.message.includes('컨테이너')) {
    alert('타임라인 컨테이너를 찾을 수 없습니다.');
  } else if (error.message.includes('날짜')) {
    alert('날짜 데이터가 올바르지 않습니다.');
  } else {
    alert('타임라인 렌더링 중 오류가 발생했습니다.');
  }
}
```

## 참고 자료

- [TX XLSX Exporter Guide](./tx_xlsx_exporter_guide.md) - 동일한 JSON 구조 사용
- [README.rdoc](../README.rdoc) - 전체 문서

---

**버전:** 1.1.0
**최종 업데이트:** 2026-01-27

## 변경 이력

### v1.1.0 (2026-01-27)
- 공휴일 표시 기능 추가 (`options.holidays`)
- 공휴일을 일요일처럼 빨간색으로 표시
- Redmine Holiday API 연동 예제 추가

### v1.0.0 (2026-01-20)
- 초기 릴리스
