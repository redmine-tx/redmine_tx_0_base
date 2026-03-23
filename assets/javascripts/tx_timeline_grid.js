/**
 * TX Timeline Grid - 공용 웹 타임라인 렌더러
 * 
 * @fileoverview 순수 JavaScript로 작성된 웹 기반 타임라인 렌더러
 * @version 1.0.0
 * @author Redmine TX Team
 * 
 * @requires 없음 (순수 JavaScript, 외부 의존성 없음)
 * 
 * @description
 * 주요 기능:
 * - 웹 타임라인 그리드 렌더링 (월/일 헤더 + 스케줄 바)
 * - 카테고리별 색상 구분
 * - 세로선 마커 (Today, 마일스톤 등)
 * - 범례(Legend) 표시
 * - 스케줄 클릭 이벤트 (tx-schedule-click)
 * - 반응형 스크롤
 * - Today 위치로 자동 스크롤 옵션
 * 
 * @example
 * // 기본 사용법
 * var jsonData = { categories: [  ...  ] };
 * TxTimelineGrid.render('#timeline-container', jsonData);
 * 
 * @example
 * // 옵션 사용
 * TxTimelineGrid.render('#timeline-container', jsonData, {
 *   scrollToToday: true,
 *   scrollAlign: 'center',
 *   verticalMarkers: [{ date: '2024-12-31', name: 'v1.0 출시', color: '#FF6B6B' }]
 * });
 * 
 * @see README.rdoc
 * @see docs/tx_timeline_grid_guide.md
 * 
 * JSON 데이터 형식: tx_xlsx_exporter.js와 동일
 */

var TxTimelineGrid = (function() {
  'use strict';

  // ============================================================
  // 헬퍼 함수 (tx_xlsx_exporter.js에서 가져옴)
  // ============================================================
  
  /**
   * 월별 헤더 정보 생성
   * @param {Date} startDate - 시작 날짜
   * @param {Date} endDate - 종료 날짜
   * @returns {Array} 월별 헤더 배열 [{name: '2024년 1월', days: 31, year: 2024, month: 0}, ...]
   */
  function generateMonthHeaders(startDate, endDate) {
    var months = [];
    var currentDate = new Date(startDate);
    
    while (currentDate <= endDate) {
      var year = currentDate.getFullYear();
      var month = currentDate.getMonth();
      var monthName = year + '년 ' + (month + 1) + '월';
      
      var lastDayOfMonth = new Date(year, month + 1, 0);
      
      var monthStartDay = (currentDate.getMonth() === startDate.getMonth() && currentDate.getFullYear() === startDate.getFullYear()) 
                          ? startDate.getDate() : 1;
      var monthEndDay = (currentDate.getMonth() === endDate.getMonth() && currentDate.getFullYear() === endDate.getFullYear()) 
                        ? endDate.getDate() : lastDayOfMonth.getDate();
      
      var daysInMonth = monthEndDay - monthStartDay + 1;
      
      if (daysInMonth > 0) {
        months.push({
          name: monthName,
          days: daysInMonth,
          year: year,
          month: month
        });
      }
      
      currentDate = new Date(year, month + 1, 1);
    }
    
    return months;
  }
  
  /**
   * 일별 헤더 정보 생성
   * @param {Date} startDate - 시작 날짜
   * @param {Date} endDate - 종료 날짜
   * @param {Array} holidays - 공휴일 배열 (YYYY-MM-DD 형식)
   * @returns {Array} 일별 헤더 배열 [{day: 1, dayOfWeek: 0, date: Date, isHoliday: Boolean}, ...]
   */
  function generateDayHeaders(startDate, endDate, holidays) {
    var days = [];
    var currentDate = new Date(startDate);
    holidays = holidays || [];

    // 공휴일 Set 생성 (빠른 검색을 위해)
    var holidaySet = new Set();
    holidays.forEach(function(holiday) {
      holidaySet.add(holiday);
    });

    while (currentDate <= endDate) {
      var dateStr = formatDateYMD(currentDate);
      days.push({
        day: currentDate.getDate(),
        dayOfWeek: currentDate.getDay(), // 0: 일요일, 6: 토요일
        date: new Date(currentDate),
        isHoliday: holidaySet.has(dateStr)
      });
      currentDate.setDate(currentDate.getDate() + 1);
    }

    return days;
  }

  /**
   * Date 객체를 YYYY-MM-DD 문자열로 변환
   * @param {Date} date - 날짜 객체
   * @returns {string} YYYY-MM-DD 형식 문자열
   */
  function formatDateYMD(date) {
    var year = date.getFullYear();
    var month = String(date.getMonth() + 1).padStart(2, '0');
    var day = String(date.getDate()).padStart(2, '0');
    return year + '-' + month + '-' + day;
  }

  /**
   * categories에서 스케줄의 최초/최종 날짜를 계산
   * @param {Array} categories - 카테고리 배열
   * @returns {Object|null} { startDate: Date, endDate: Date } 또는 null
   */
  function calculateTimelineFromCategories(categories) {
    var minDate = null;
    var maxDate = null;
    
    if (!categories || !Array.isArray(categories)) {
      return null;
    }
    
    categories.forEach(function(category) {
      if (!category.events) return;
      
      category.events.forEach(function(event) {
        if (!event.schedules) return;
        
        event.schedules.forEach(function(schedule) {
          if (schedule.startDate) {
            var start = new Date(schedule.startDate);
            if (!isNaN(start.getTime())) {
              if (!minDate || start < minDate) minDate = start;
              if (!maxDate || start > maxDate) maxDate = start;
            }
          }
          if (schedule.endDate) {
            var end = new Date(schedule.endDate);
            if (!isNaN(end.getTime())) {
              if (!minDate || end < minDate) minDate = end;
              if (!maxDate || end > maxDate) maxDate = end;
            }
          }
        });
      });
    });
    
    if (minDate && maxDate) {
      return { startDate: minDate, endDate: maxDate };
    }
    return null;
  }

  /**
   * 색상의 밝기 계산 (폰트 색상 결정용)
   * @param {string} hexColor - 헥스 색상 (#RRGGBB)
   * @returns {number} 밝기 값 (0-255)
   */
  function getBrightness(hexColor) {
    var rgb = hexColor.replace('#', '');
    var r = parseInt(rgb.substr(0, 2), 16);
    var g = parseInt(rgb.substr(2, 2), 16);
    var b = parseInt(rgb.substr(4, 2), 16);
    return (r * 299 + g * 587 + b * 114) / 1000;
  }

  /**
   * hex 색상을 어둡게 만들기
   * @param {string} hexColor - #RRGGBB 형식
   * @param {number} factor - 0~1 사이 값 (0에 가까울수록 더 어두움)
   * @returns {string} 어두운 hex 색상
   */
  function darkenColor(hexColor, factor) {
    var rgb = hexColor.replace('#', '');
    var r = Math.round(parseInt(rgb.substr(0, 2), 16) * factor);
    var g = Math.round(parseInt(rgb.substr(2, 2), 16) * factor);
    var b = Math.round(parseInt(rgb.substr(4, 2), 16) * factor);
    return '#' + ('0' + r.toString(16)).slice(-2) + ('0' + g.toString(16)).slice(-2) + ('0' + b.toString(16)).slice(-2);
  }

  /**
   * 날짜 문자열을 Date 객체로 변환
   * @param {string} dateStr - YYYY-MM-DD 형식
   * @returns {Date|null}
   */
  function parseDate(dateStr) {
    if (!dateStr) return null;
    var date = new Date(dateStr);
    return isNaN(date.getTime()) ? null : date;
  }

  /**
   * HTML 이스케이프
   * @param {string} str - 원본 문자열
   * @returns {string} 이스케이프된 문자열
   */
  function escapeHtml(str) {
    if (!str) return '';
    var div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  /**
   * YYYY-MM-DD 또는 Date를 "로컬 자정" Date로 정규화
   * (날짜 비교/인덱스 계산 시 타임존 이슈 최소화)
   * @param {string|Date} input
   * @returns {Date|null}
   */
  function normalizeMarkerDate(input) {
    if (!input) return null;
    if (input instanceof Date) {
      var d = new Date(input);
      d.setHours(0, 0, 0, 0);
      return d;
    }
    if (typeof input === 'string') {
      // YYYY-MM-DD 우선 파싱
      var m = input.match(/^(\d{4})-(\d{2})-(\d{2})$/);
      if (m) {
        var d2 = new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10));
        d2.setHours(0, 0, 0, 0);
        return d2;
      }
      // fallback
      var d3 = new Date(input);
      if (!isNaN(d3.getTime())) {
        d3.setHours(0, 0, 0, 0);
        return d3;
      }
    }
    return null;
  }

  /**
   * 세로선 마커 데이터 처리
   * @param {Array} markers - [{date, name, color, side}]
   * @param {Date} startDate
   * @param {number} totalDays
   * @param {Object} widths - {category:number, event:number, day:number}
   * @returns {Object} { linesHtml: string, markerItems: Array }
   */
  function buildVerticalMarkersData(markers, startDate, totalDays, widths) {
    var result = { linesHtml: '', markerItems: [] };
    if (!markers || !markers.length) return result;
    
    var start = new Date(startDate);
    start.setHours(0, 0, 0, 0);
    var msPerDay = 1000 * 60 * 60 * 24;
    
    // 같은 날짜의 마커를 추적하기 위한 맵 (dayIndex -> 현재 층 수)
    var dayIndexRowMap = {};

    markers.forEach(function(marker) {
      if (!marker) return;
      var date = normalizeMarkerDate(marker.date);
      if (!date) return;

      var idx = Math.floor((date - start) / msPerDay);
      if (idx < 0 || idx >= totalDays) return;

      var color = marker.color || '#e00000';
      var name = marker.name || '';
      // 'left' | 'right' (default: right)
      var side = (marker.side === 'left' || marker.side === 'right') ? marker.side : 'right';

      // 날짜 컬럼 경계선 위치 (타임라인 영역 내부 좌표, default: 우측 경계선)
      var leftPx = (idx * widths.day) + (side === 'right' ? widths.day : 0);

      // 점선: 바디 영역용 (헤더 아래에서 시작)
      var lineStyle = marker.lineStyle === 'solid' ? 'solid' : 'dashed';
      result.linesHtml += '<div aria-hidden="true" style="position:absolute; top:0; bottom:0; left:' + leftPx + 'px; border-left:2px ' + lineStyle + ' ' + escapeHtml(color) + '; pointer-events:none;"></div>';

      // 마커 아이템 정보 (헤더 마커 행에서 사용)
      if (name) {
        // 같은 날짜에 이미 마커가 있으면 다음 층에 배치
        var row = dayIndexRowMap[idx] || 0;
        dayIndexRowMap[idx] = row + 1;
        
        result.markerItems.push({
          dayIndex: idx,
          leftPx: leftPx,
          name: name,
          color: color,
          row: row  // 층 번호 (0부터 시작)
        });
      }
    });

    return result;
  }

  // ============================================================
  // 렌더링 함수
  // ============================================================

  /**
   * 타임라인 그리드 렌더링
   * @param {HTMLElement|string} container - 컨테이너 요소 또는 선택자
   * @param {Object} jsonData - JSON 데이터
   * @param {Object} renderOptions - 렌더링 옵션 (선택적)
   */
  function render(container, jsonData, renderOptions) {
    try {
      // 컨테이너 요소 확인
      var containerEl = typeof container === 'string' 
        ? document.querySelector(container) 
        : container;
      
      if (!containerEl) {
        throw new Error('컨테이너 요소를 찾을 수 없습니다: ' + container);
      }

      // 옵션 추출 및 기본값 설정
      var options = jsonData.options || {};
      var categoryLabel = options.categoryLabel || '카테고리';
      var eventLabel = options.eventLabel || '이벤트';
      var showScheduleName = options.showScheduleName !== false;
      
      // 렌더링 옵션 병합
      renderOptions = renderOptions || {};
      var showLegend = renderOptions.showLegend !== false;
      
      var startDate, endDate;
      
      // 스케줄에서 날짜 범위 자동 계산 (startDate/endDate가 없는 경우 사용)
      var calculatedTimeline = calculateTimelineFromCategories(jsonData.categories);
      
      // 날짜 범위 결정: 명시된 값이 있으면 사용, 없으면 자동 계산 값 사용
      if (options.startDate) {
        startDate = new Date(options.startDate);
        
        // startDate가 명시된 경우, 해당 날짜가 속한 주의 시작일(월요일)로 조정
        var dayOfWeek = startDate.getDay();
        // 일요일(0)이면 6일 전 월요일, 그 외에는 (요일-1)일 전 월요일
        var daysToSubtract = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
        if (daysToSubtract > 0) {
          startDate.setDate(startDate.getDate() - daysToSubtract);
        }
      } else if (calculatedTimeline) {
        startDate = calculatedTimeline.startDate;
      } else {
        throw new Error('스케줄 날짜를 계산할 수 없습니다.');
      }
      
      if (options.endDate) {
        endDate = new Date(options.endDate);
      } else if (calculatedTimeline) {
        endDate = calculatedTimeline.endDate;
      } else {
        throw new Error('스케줄 날짜를 계산할 수 없습니다.');
      }

      var months = generateMonthHeaders(startDate, endDate);
      var holidays = options.holidays || [];
      var days = generateDayHeaders(startDate, endDate, holidays);

      // 이벤트별 스케줄 매핑 생성 (행 단위 스케줄 배치용)
      var eventScheduleMap = buildEventScheduleMap(jsonData.categories, startDate, days.length);

      // 컬럼 너비 설정
      var categoryColWidth = 120;
      var eventColWidth = 100;
      var dayColWidth = 22;
      var totalWidth = categoryColWidth + eventColWidth + (days.length * dayColWidth);
      var timelineOffsetLeft = categoryColWidth + eventColWidth;

      // 세로선 마커 데이터 생성 (점선 + 마커 아이템)
      var optionMarkers = (options && options.verticalMarkers) ? options.verticalMarkers : [];
      var renderMarkers = renderOptions.verticalMarkers || [];
      // Today 마커를 맨 뒤에 추가하여 다른 마커와 겹칠 때 위에 표시되도록 함
      var verticalMarkers = optionMarkers.concat(renderMarkers, [{ date: new Date(), name: 'Today', color: '#e00000' }]);
      var markersData = buildVerticalMarkersData(
        verticalMarkers,
        startDate,
        days.length,        
        { category: categoryColWidth, event: eventColWidth, day: dayColWidth }
      );

      // HTML 생성
      var html = '<div class="tx-timeline-wrapper">';
      html += '<div class="tx-timeline-scroll">';
      // 컨텐츠 래퍼: position:relative만 (z-index 없음 → 스태킹 컨텍스트 안 생김)
      html += '<div class="tx-timeline-content" style="position:relative; display:inline-block;">';
      // 마커 점선 레이어: 바디 영역에만 표시 (헤더 아래로 이동됨)
      html += '<div class="tx-timeline-marker-lines" aria-hidden="true" style="position:absolute; top:0; bottom:0; left:' + timelineOffsetLeft + 'px; right:0; overflow:hidden; pointer-events:none; z-index:4;">';
      html += markersData.linesHtml;
      html += '</div>';
      html += '<table class="tx-timeline-table" style="width: ' + totalWidth + 'px;">';
      
      // colgroup으로 열 너비 강제 지정
      html += '<colgroup>';
      html += '<col style="width: ' + categoryColWidth + 'px;">';
      html += '<col style="width: ' + eventColWidth + 'px;">';
      for (var i = 0; i < days.length; i++) {
        html += '<col style="width: ' + dayColWidth + 'px;">';
      }
      html += '</colgroup>';
      
      // 헤더 생성 (마커 이름 행 포함)
      html += buildHeaderHtml(months, days, categoryLabel, eventLabel, markersData.markerItems, dayColWidth);
      
      // 바디 생성
      html += buildBodyHtml(jsonData.categories, days, eventScheduleMap, showScheduleName);
      
      html += '</table>';
      html += '</div>'; // .tx-timeline-content
      html += '</div>'; // .tx-timeline-scroll
      
      // 범례 생성
      if (showLegend && jsonData.legends && jsonData.legends.length > 0) {
        html += buildLegendHtml(jsonData.legends);
      }
      
      html += '</div>';

      containerEl.innerHTML = html;

      // 헤더 높이를 측정해 점선 레이어의 top을 헤더 아래로 내림
      // (마커 이름은 헤더의 마커 행에 표시되므로 점선만 바디 영역에 표시)
      var theadEl = containerEl.querySelector('.tx-timeline-table thead');
      var linesLayer = containerEl.querySelector('.tx-timeline-marker-lines');
      if (theadEl && linesLayer) {
        linesLayer.style.top = theadEl.offsetHeight + 'px';
      }

      // 이벤트 바인딩
      bindEvents(containerEl);

      // ============================================================
      // 렌더링 후 가로 스크롤 위치 조정 (선택 옵션)
      // - renderOptions.scrollToToday: true  => 오늘 날짜로 스크롤
      // - renderOptions.scrollToDate: Date|string(YYYY-MM-DD) => 해당 날짜로 스크롤
      // - renderOptions.scrollAlign: 'center' | 'left' (default: center)
      // - renderOptions.scrollBehavior: 'auto' | 'smooth' (default: auto)
      // ============================================================
      (function autoScrollAfterRender() {
        var scrollToDateOpt = (renderOptions && renderOptions.scrollToDate) ? renderOptions.scrollToDate : null;
        var scrollToToday = !!(renderOptions && renderOptions.scrollToToday);
        if (!scrollToDateOpt && !scrollToToday) return;

        var scrollEl = containerEl.querySelector('.tx-timeline-scroll');
        if (!scrollEl) return;

        // 타임라인 시작일(월요일 보정된 startDate)을 기준으로 인덱스 계산
        var baseStart = new Date(startDate);
        baseStart.setHours(0, 0, 0, 0);
        var msPerDay = 1000 * 60 * 60 * 24;

        var target;
        if (scrollToDateOpt) {
          target = (scrollToDateOpt instanceof Date) ? new Date(scrollToDateOpt) : parseDate(String(scrollToDateOpt));
        } else {
          target = new Date();
        }
        if (!target || isNaN(target.getTime())) return;
        target.setHours(0, 0, 0, 0);

        var dayIndex = Math.floor((target - baseStart) / msPerDay);
        if (dayIndex < 0) dayIndex = 0;
        if (dayIndex >= days.length) dayIndex = days.length - 1;

        // 날짜 컬럼의 중심 X 좌표 (테이블 좌측 기준)
        var dayCenterX = categoryColWidth + eventColWidth + (dayIndex * dayColWidth) + (dayColWidth / 2);

        var align = (renderOptions && renderOptions.scrollAlign) ? String(renderOptions.scrollAlign) : 'center';
        var behavior = (renderOptions && renderOptions.scrollBehavior) ? String(renderOptions.scrollBehavior) : 'auto';

        function computeDesiredLeft() {
          var viewportWidth = scrollEl.clientWidth || 0;
          var maxScrollLeft = Math.max(0, (scrollEl.scrollWidth || 0) - viewportWidth);

          var desiredLeft;
          if (align === 'left') {
            desiredLeft = dayCenterX - (dayColWidth / 2);
          } else {
            desiredLeft = dayCenterX - (viewportWidth / 2);
          }
          if (desiredLeft < 0) desiredLeft = 0;
          if (desiredLeft > maxScrollLeft) desiredLeft = maxScrollLeft;
          return desiredLeft;
        }

        // 1) 가능하면 즉시 점프(애니메이션 없이)해서 "로딩 후 이동"처럼 보이는 현상 최소화
        try {
          scrollEl.scrollLeft = computeDesiredLeft();
        } catch (e) {
          // ignore
        }

        // 2) 레이아웃 완료 후 한 번 더 보정 (scrollWidth/clientWidth 값 안정화)
        requestAnimationFrame(function() {
          var desiredLeft = computeDesiredLeft();
          try {
            if (behavior === 'smooth' && typeof scrollEl.scrollTo === 'function') {
              scrollEl.scrollTo({ left: desiredLeft, behavior: 'smooth' });
            } else {
              scrollEl.scrollLeft = desiredLeft;
            }
          } catch (e) {
            scrollEl.scrollLeft = desiredLeft;
          }
        });
      })();

    } catch (error) {
      console.error('TxTimelineGrid.render 오류:', error);
      throw error;
    }
  }

  /**
   * 이벤트별 스케줄 위치 매핑 생성
   * @param {Array} categories - 카테고리 배열
   * @param {Date} startDate - 시작 날짜
   * @param {number} totalDays - 전체 일수
   * @returns {Map} 이벤트 키 -> 스케줄 배열
   */
  function buildEventScheduleMap(categories, startDate, totalDays) {
    var map = new Map();
    var categoryIndex = 0;
    
    categories.forEach(function(category) {
      var eventIndex = 0;
      category.events.forEach(function(event) {
        var key = categoryIndex + '_' + eventIndex;
        var schedules = [];
        
        event.schedules.forEach(function(schedule) {
          var scheduleStart = parseDate(schedule.startDate);
          var scheduleEnd = parseDate(schedule.endDate);
          
          if (scheduleStart && scheduleEnd) {
            var startDayIndex = Math.floor((scheduleStart - startDate) / (1000 * 60 * 60 * 24));
            var endDayIndex = Math.floor((scheduleEnd - startDate) / (1000 * 60 * 60 * 24));
            
            // 타임라인 시작일 이전에 시작한 스케줄은 시작일부터 잘려서 표시
            if (startDayIndex < 0) {
              startDayIndex = 0;
            }
            
            // 범위 내에 있는지 확인 (끝이 타임라인 내에 있거나, 시작이 타임라인 내에 있으면 표시)
            if (endDayIndex >= 0 && startDayIndex < totalDays) {
              schedules.push({
                name: schedule.name,
                issue: schedule.issue,
                doneRatio: schedule.doneRatio,
                memo: schedule.memo,
                link: schedule.link || schedule.issueUrl,
                issueId: schedule.issueId,
                color: schedule.customColor || category.customColor,
                fontColor: schedule.customFontColor,  // 커스텀 폰트 색상 지원
                isMuted: schedule.isMuted,  // muted(흐림) 상태 지원
                startIndex: startDayIndex,
                endIndex: Math.min(endDayIndex, totalDays - 1),
                colspan: Math.min(endDayIndex, totalDays - 1) - startDayIndex + 1
              });
            }
          }
        });
        
        map.set(key, schedules);
        eventIndex++;
      });
      categoryIndex++;
    });
    
    return map;
  }

  /**
   * 헤더 HTML 생성
   * @param {Array} months - 월 헤더 정보
   * @param {Array} days - 일 헤더 정보
   * @param {string} categoryLabel - 카테고리 라벨
   * @param {string} eventLabel - 이벤트 라벨
   * @param {Array} markerItems - 마커 아이템 배열 [{dayIndex, leftPx, name, color, row}]
   * @param {number} dayColWidth - 날짜 컬럼 너비
   */
  function buildHeaderHtml(months, days, categoryLabel, eventLabel, markerItems, dayColWidth) {
    var html = '<thead>';
    var hasMarkers = markerItems && markerItems.length > 0;
    var rowspan = hasMarkers ? 3 : 2;
    
    // 마커 행 높이는 고정 (18px)
    var rowHeight = 18;
    var markerRowHeight = 18;
    
    // 월 헤더 행 (첫 번째 행)
    html += '<tr class="tx-month-row">';
    // 좌측 고정 헤더 (rowspan으로 아래 행들과 병합)
    html += '<th class="tx-header-cell tx-category-col" rowspan="' + rowspan + '" style="z-index:1000;">' + escapeHtml(categoryLabel) + '</th>';
    html += '<th class="tx-header-cell tx-event-col" rowspan="' + rowspan + '" style="z-index:1000;">' + escapeHtml(eventLabel) + '</th>';
    
    months.forEach(function(month) {
      html += '<th class="tx-header-cell tx-month-cell" colspan="' + month.days + '">' + escapeHtml(month.name) + '</th>';
    });
    html += '</tr>';
    
    // 일 헤더 행 (두 번째 행)
    html += '<tr class="tx-day-row">';
    days.forEach(function(dayInfo, index) {
      var dayClass = 'tx-header-cell tx-day-cell';
      // 공휴일이 일요일/토요일보다 우선 (공휴일은 빨간색으로 표시)
      if (dayInfo.isHoliday) {
        dayClass += ' tx-holiday';
      } else if (dayInfo.dayOfWeek === 0) {
        dayClass += ' tx-sunday';
      } else if (dayInfo.dayOfWeek === 6) {
        dayClass += ' tx-saturday';
      }
      if (dayInfo.day === 1) dayClass += ' tx-month-start';

      html += '<th class="' + dayClass + '" data-day-index="' + index + '">' + dayInfo.day + '</th>';
    });
    html += '</tr>';
    
    // 마커 이름 행 (세 번째 행, 마커가 있을 때만)
    if (hasMarkers) {
      html += '<tr class="tx-marker-row">';
      // 날짜 영역: 전체를 하나의 셀로 병합, 내부에 마커 이름들을 absolute로 배치
      // 높이는 고정 (18px), overflow:visible로 위로 넘치도록 허용
      html += '<th class="tx-header-cell tx-marker-cell" colspan="' + days.length + '" style="position:relative; height:' + markerRowHeight + 'px; padding:0; vertical-align:top; background:#f5f5f5; overflow:visible;">';
      // 마커 이름들 배치 (층에 따라 위로 올라가도록 음수 top 사용)
      markerItems.forEach(function(item) {
        // leftPx는 날짜 영역 내부 좌표 (dayIndex * dayColWidth + offset)
        var labelLeft = (item.dayIndex * dayColWidth) + 2;
        // row=0: top=1px (정상 위치)
        // row=1: top=-17px (위로 올라감)
        // row=2: top=-35px (더 위로 올라감)
        var labelTop = (item.row === 0) ? 1 : (1 - (item.row * rowHeight));
        html += '<span style="position:absolute; top:' + labelTop + 'px; left:' + labelLeft + 'px; padding:1px 4px; font-size:11px; line-height:1.2; background:rgba(255,255,255,0.9); color:' + escapeHtml(item.color) + '; border:1px solid ' + escapeHtml(item.color) + '; border-radius:3px; white-space:nowrap; font-weight:normal; z-index:' + (100 + item.row) + ';">' + escapeHtml(item.name) + '</span>';
      });
      html += '</th>';
      html += '</tr>';
    }
    
    html += '</thead>';
    return html;
  }

  /**
   * 바디 HTML 생성
   */
  function buildBodyHtml(categories, days, eventScheduleMap, showScheduleName) {
    var html = '<tbody>';
    var categoryIndex = 0;
    
    categories.forEach(function(category) {
      var categoryRowCount = category.events.length || 1;
      var isFirstEvent = true;
      var eventIndex = 0;
      
      // 카테고리 스타일 계산
      var categoryStyle = '';
      var categoryClass = 'tx-category-cell';
      if (category.customColor) {
        var brightness = getBrightness(category.customColor);
        var fontColor = brightness > 128 ? '#000000' : '#ffffff';
        categoryStyle = 'background-color: ' + category.customColor + '; color: ' + fontColor + ';';
      }
      
      if (category.events.length === 0) {
        // 이벤트가 없는 카테고리
        html += '<tr class="tx-data-row tx-category-start tx-category-end" data-category="' + categoryIndex + '">';
        html += '<td class="' + categoryClass + '" style="' + categoryStyle + '">' + escapeHtml(category.name) + '</td>';
        html += '<td class="tx-event-cell">(이벤트 없음)</td>';
        
        days.forEach(function(dayInfo) {
          var cellClass = 'tx-schedule-cell';
          if (dayInfo.day === 1) cellClass += ' tx-month-start';
          html += '<td class="' + cellClass + '"></td>';
        });
        
        html += '</tr>';
      } else {
        category.events.forEach(function(event, evtIdx) {
          var rowClass = 'tx-data-row';
          if (isFirstEvent) rowClass += ' tx-category-start';
          if (evtIdx === category.events.length - 1) rowClass += ' tx-category-end';
          
          html += '<tr class="' + rowClass + '" data-category="' + categoryIndex + '" data-event="' + eventIndex + '">';
          
          // 카테고리 셀 (첫 번째 이벤트에서만 표시)
          if (isFirstEvent) {
            html += '<td class="' + categoryClass + '" rowspan="' + categoryRowCount + '" style="' + categoryStyle + '">' + escapeHtml(category.name) + '</td>';
          }
          
          // 이벤트 셀 (링크 지원)
          var eventContent = escapeHtml(event.name);
          if (event.link) {
            eventContent = '<a href="' + escapeHtml(event.link) + '" class="tx-event-link" target="_blank">' + eventContent + '</a>';
          }
          html += '<td class="tx-event-cell">' + eventContent + '</td>';
          
          // 스케줄 셀들
          var key = categoryIndex + '_' + eventIndex;
          var schedules = eventScheduleMap.get(key) || [];
          html += buildScheduleCellsHtml(days, schedules, showScheduleName);
          
          html += '</tr>';
          
          isFirstEvent = false;
          eventIndex++;
        });
      }
      
      categoryIndex++;
    });
    
    html += '</tbody>';
    return html;
  }

  /**
   * 스케줄 셀들 HTML 생성 (한 행의 일별 셀)
   */
  function buildScheduleCellsHtml(days, schedules, showScheduleName) {
    var html = '';
    var skipUntil = -1;
    
    days.forEach(function(dayInfo, index) {
      // 이전 스케줄의 colspan으로 인해 스킵해야 하는 경우
      if (index <= skipUntil) {
        return;
      }
      
      var cellClass = 'tx-schedule-cell';
      if (dayInfo.day === 1) cellClass += ' tx-month-start';
      // 공휴일이 일요일/토요일보다 우선 (공휴일은 빨간색으로 표시)
      if (dayInfo.isHoliday) {
        cellClass += ' tx-holiday';
      } else if (dayInfo.dayOfWeek === 0) {
        cellClass += ' tx-sunday';
      } else if (dayInfo.dayOfWeek === 6) {
        cellClass += ' tx-saturday';
      }
      
      // 이 인덱스에서 시작하는 스케줄 찾기
      var schedule = schedules.find(function(s) {
        return s.startIndex === index;
      });
      
      if (schedule) {
        // 스케줄 바 셀
        var barClass = 'tx-schedule-bar';
        var barStyle = '';
        
        // muted 상태면 클래스 추가
        if (schedule.isMuted) {
          barClass += ' tx-schedule-bar-muted';
        }
        
        var fontColor = '';  // 폰트 색상 변수 (링크에도 사용)
        if (schedule.color) {
          var brightness = getBrightness(schedule.color);
          // customFontColor가 있으면 사용, 없으면 밝기 기반 자동 계산
          fontColor = schedule.fontColor || (brightness > 128 ? '#000000' : '#ffffff');
          barStyle = 'background-color: ' + schedule.color + '; color: ' + fontColor + ';';
          if (!schedule.isMuted) {
            barStyle += ' border-color: ' + darkenColor(schedule.color, 0.65) + ';';
          }
        } else if (schedule.fontColor) {
          // 배경색 없이 폰트 색상만 있는 경우
          fontColor = schedule.fontColor;
          barStyle = 'color: ' + fontColor + ';';
        }
        
        var tooltip = schedule.name;
        if (schedule.issue) tooltip += ' (' + schedule.issue + ')';
        if (schedule.doneRatio) tooltip += ' - ' + schedule.doneRatio + '%';
        if (schedule.memo) tooltip += '\n' + schedule.memo;
        
        var content = showScheduleName ? escapeHtml(schedule.name) : '';
        
        // 이슈 URL 확인 (link 속성 사용, 기존 호환성을 위해 issueUrl도 fallback)
        var linkUrl = schedule.link || schedule.issueUrl;
        var issueId = schedule.issueId || (schedule.issue ? schedule.issue.replace('#', '') : null);
        
        // 하이퍼링크가 있으면 링크로 감싸기 (redmine_tx_tooltip 지원)
        // 링크에도 폰트 색상 적용
        if (linkUrl && issueId) {
          var linkStyle = fontColor ? ' style="color: ' + fontColor + ';"' : '';
          var linkAttrs = 'href="' + escapeHtml(linkUrl) + '" class="tx-schedule-link" target="_blank"' + linkStyle;
          if (issueId) {
            linkAttrs += ' data-issue-tooltip="' + escapeHtml(issueId) + '"';
          }
          content = '<a ' + linkAttrs + '>' + content + '</a>';
        } else if (linkUrl) {
          var linkStyle = fontColor ? ' style="color: ' + fontColor + ';"' : '';
          content = '<a href="' + escapeHtml(linkUrl) + '" class="tx-schedule-link" target="_blank"' + linkStyle + '>' + content + '</a>';
        }
        
        // 링크가 있으면 클릭 가능 표시
        if (linkUrl) {
          barClass += ' tx-schedule-bar-clickable';
        }
        
        html += '<td class="' + cellClass + ' ' + barClass + '" colspan="' + schedule.colspan + '" style="' + barStyle + '" title="' + escapeHtml(tooltip) + '" data-schedule="' + escapeHtml(schedule.name) + '">';
        html += '<div class="tx-schedule-bar-content">' + content + '</div>';
        html += '</td>';
        
        skipUntil = index + schedule.colspan - 1;
      } else {
        // 빈 셀
        html += '<td class="' + cellClass + '"></td>';
      }
    });
    
    return html;
  }

  /**
   * 범례 HTML 생성
   */
  function buildLegendHtml(legends) {
    var html = '<div class="tx-timeline-legend">';
    html += '<div class="tx-legend-title">📌 범례</div>';
    html += '<div class="tx-legend-items">';
    
    legends.forEach(function(legend) {
      if (!legend.title || !legend.color) return;
      
      var brightness = getBrightness(legend.color);
      var fontColor = brightness > 128 ? '#000000' : '#ffffff';
      var style = 'background-color: ' + legend.color + '; color: ' + fontColor + ';';
      
      html += '<div class="tx-legend-item" style="' + style + '">';
      
      if (legend.url) {
        html += '<a href="' + escapeHtml(legend.url) + '" target="_blank" class="tx-legend-link">' + escapeHtml(legend.title) + '</a>';
      } else {
        html += escapeHtml(legend.title);
      }
      
      html += '</div>';
    });
    
    html += '</div>';
    html += '</div>';
    
    return html;
  }

  /**
   * 이벤트 바인딩
   */
  function bindEvents(containerEl) {
    // 스케줄 바 클릭 이벤트
    containerEl.querySelectorAll('.tx-schedule-bar').forEach(function(bar) {
      bar.addEventListener('click', function(e) {
        // 링크 클릭은 제외 (링크 자체가 처리)
        if (e.target.tagName === 'A' || e.target.closest('a')) return;
        
        // 링크가 있으면 링크로 이동
        var link = this.querySelector('.tx-schedule-link');
        if (link) {
          link.click();
          return;
        }
        
        // 링크가 없으면 커스텀 이벤트 발생
        var scheduleName = this.getAttribute('data-schedule');
        var event = new CustomEvent('tx-schedule-click', {
          detail: { scheduleName: scheduleName, element: this }
        });
        containerEl.dispatchEvent(event);
      });
    });
  }

  /**
   * 타임라인 업데이트 (데이터 변경 시)
   * @param {HTMLElement|string} container - 컨테이너 요소 또는 선택자
   * @param {Object} jsonData - JSON 데이터
   * @param {Object} renderOptions - 렌더링 옵션
   */
  function update(container, jsonData, renderOptions) {
    render(container, jsonData, renderOptions);
  }

  /**
   * 타임라인 제거
   * @param {HTMLElement|string} container - 컨테이너 요소 또는 선택자
   */
  function destroy(container) {
    var containerEl = typeof container === 'string' 
      ? document.querySelector(container) 
      : container;
    
    if (containerEl) {
      containerEl.innerHTML = '';
    }
  }

  // ============================================================
  // Public API
  // ============================================================
  
  return {
    render: render,
    update: update,
    destroy: destroy,
    
    // 헬퍼 함수도 공개 (필요시 사용)
    generateMonthHeaders: generateMonthHeaders,
    generateDayHeaders: generateDayHeaders,
    calculateTimelineFromCategories: calculateTimelineFromCategories
  };

})();

