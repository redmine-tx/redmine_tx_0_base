/**
 * TX XLSX Exporter - 공용 엑셀 로드맵 익스포터
 * 
 * @fileoverview ExcelJS 기반의 로드맵 타임라인 엑셀 익스포터
 * @version 1.0.0
 * @author Redmine TX Team
 * 
 * @requires ExcelJS (https://github.com/exceljs/exceljs)
 * 
 * @description
 * 주요 기능:
 * - 로드맵 타임라인 시트 생성 (월/일 헤더 + 스케줄 바)
 * - 스케줄 리스트 시트 생성 (테이블 형식)
 * - 카테고리별 색상 구분
 * - 일감 하이퍼링크 연결
 * - 셀 메모(코멘트) 지원
 * - 범례(Legend) 표시
 * - 자동 날짜 범위 계산
 * 
 * @example
 * // 간단한 사용법
 * var jsonData = { categories: [ /* ... */ ] };
 * TxXlsxExporter.exportToXlsx(jsonData, '로드맵_2024');
 * 
 * @example
 * // 수동 워크북 생성
 * var workbook = new ExcelJS.Workbook();
 * TxXlsxExporter.createRoadmapTimelineSheet(workbook, jsonData);
 * TxXlsxExporter.createScheduleListSheet(workbook, jsonData);
 * 
 * @see README.rdoc
 * @see docs/tx_xlsx_exporter_guide.md
 * 
 * JSON 데이터 형식:
 *   {
 *     options: {                   // 선택적 - 모든 옵션은 기본값 있음
 *       startDate: "2024-01-01",   // 타임라인 시작일 (생략 시 스케줄에서 자동 계산)
 *       endDate: "2025-01-01",     // 타임라인 종료일 (생략 시 스케줄에서 자동 계산)
 *       categoryLabel: "카테고리", // 헤더 A열 라벨 (기본값: "카테고리")
 *       eventLabel: "이벤트",      // 헤더 B열 라벨 (기본값: "이벤트")
 *       rowHeight: 30,             // 데이터 행 높이 (기본값: 30)
 *       showScheduleName: true     // 스케줄 바에 이름 표시 여부 (기본값: true)
 *     },
 *     legends: [                   // 선택적 - 범례 정보 (타임라인 시트 하단에 표시)
 *       {
 *         title: "#12345 : 백엔드 개발 프로젝트",
 *         color: "#4A90E2",
 *         url: "https://example.com/issues/12345"  // 선택적 - 없으면 링크 없이 표시
 *       },
 *       {
 *         title: "#23456 : 프론트엔드 개발",
 *         color: "#50C878",
 *         url: "https://example.com/issues/23456"
 *       },
 *       {
 *         title: "#34567 : 인프라 구축",
 *         color: "#FF6B6B"
 *         // url 없음 - 링크 없이 텍스트만 표시
 *       }
 *     ],
 *     categories: [
 *       {
 *         name: "백엔드 개발",
 *         customColor: "#4A90D9",  // 선택적 (없으면 배경색 없음)
 *         events: [
 *           {
 *             name: "API 개발",
 *             schedules: [
 *               {
 *                 name: "사용자 API",
 *                 startDate: "2024-01-15",
 *                 endDate: "2024-01-30",
 *                 issue: "#101",
 *                 doneRatio: "80",
 *                 memo: "추가 설명이나 메모",  // 선택적 - 엑셀 셀 메모로 표시
 *                 link: "https://example.com/issues/101"  // 선택적 - 셀에 하이퍼링크 추가
 *                 // customColor 없음 - 카테고리 색상(#4A90D9) 사용
 *               },
 *               {
 *                 name: "상품 API",
 *                 startDate: "2024-02-01",
 *                 endDate: "2024-02-20",
 *                 issue: "#102",
 *                 doneRatio: "50",
 *                 customColor: "#FF6B6B"  // 개별 스케줄 색상
 *               }
 *             ]
 *           },
 *           {
 *             name: "DB 마이그레이션",
 *             schedules: [
 *               {
 *                 name: "스키마 설계",
 *                 startDate: "2024-01-10",
 *                 endDate: "2024-01-20",
 *                 issue: "#103",
 *                 doneRatio: "100"
 *               },
 *               {
 *                 name: "데이터 이관",
 *                 startDate: "2024-02-10",
 *                 endDate: "2024-02-25",
 *                 issue: "#104",
 *                 doneRatio: "30"
 *               }
 *             ]
 *           }
 *         ]
 *       },
 *       {
 *         name: "프론트엔드 개발",
 *         // customColor 없음 - 배경색 없이 표시
 *         events: [
 *           {
 *             name: "UI 구현",
 *             schedules: [
 *               {
 *                 name: "로그인 페이지",
 *                 startDate: "2024-01-20",
 *                 endDate: "2024-02-05",
 *                 issue: "#201",
 *                 doneRatio: "90",
 *                 customColor: "#50C878"  // 카테고리 색상이 없어도 스케줄 색상 적용
 *               },
 *               {
 *                 name: "대시보드",
 *                 startDate: "2024-02-10",
 *                 endDate: "2024-03-01",
 *                 issue: "#202",
 *                 doneRatio: "40"
 *                 // customColor 없고 카테고리 색상도 없음 - 배경색 없이 표시
 *               }
 *             ]
 *           },
 *           {
 *             name: "반응형 최적화",
 *             schedules: [
 *               {
 *                 name: "모바일 최적화",
 *                 startDate: "2024-03-05",
 *                 endDate: "2024-03-20",
 *                 issue: "#203",
 *                 doneRatio: "20"
 *               }
 *             ]
 *           }
 *         ]
 *       }
 *     ]
 *   }
 */

var TxXlsxExporter = (function() {
  'use strict';

  // ============================================================
  // 헬퍼 함수
  // ============================================================
  
  /**
   * 월별 헤더 정보 생성 (startDate, endDate로부터 계산)
   * @param {Date} startDate - 시작 날짜
   * @param {Date} endDate - 종료 날짜
   * @returns {Array} 월별 헤더 배열 [{name: '2024년 1월', days: 31}, ...]
   */
  function generateMonthHeaders(startDate, endDate) {
    var months = [];
    var currentDate = new Date(startDate);
    
    while (currentDate <= endDate) {
      var year = currentDate.getFullYear();
      var month = currentDate.getMonth(); // 0-based
      var monthName = year + '년 ' + (month + 1) + '월';
      
      // 해당 월의 마지막 날 계산
      var lastDayOfMonth = new Date(year, month + 1, 0);
      
      // 해당 월에서 표시할 일수 계산
      var monthStartDay = (currentDate.getMonth() === startDate.getMonth() && currentDate.getFullYear() === startDate.getFullYear()) 
                          ? startDate.getDate() : 1;
      var monthEndDay = (currentDate.getMonth() === endDate.getMonth() && currentDate.getFullYear() === endDate.getFullYear()) 
                        ? endDate.getDate() : lastDayOfMonth.getDate();
      
      var daysInMonth = monthEndDay - monthStartDay + 1;
      
      if (daysInMonth > 0) {
        months.push({
          name: monthName,
          days: daysInMonth
        });
      }
      
      // 다음 월로 이동
      currentDate = new Date(year, month + 1, 1);
    }
    
    return months;
  }
  
  /**
   * 일별 헤더 정보 생성 (startDate, endDate로부터 계산)
   * @param {Date} startDate - 시작 날짜
   * @param {Date} endDate - 종료 날짜
   * @returns {Array} 일별 헤더 배열 ['1', '2', '3', ...]
   */
  function generateDayHeaders(startDate, endDate) {
    var days = [];
    var currentDate = new Date(startDate);
    
    while (currentDate <= endDate) {
      days.push(currentDate.getDate().toString());
      currentDate.setDate(currentDate.getDate() + 1);
    }
    
    return days;
  }

  /**
   * 날짜 값에서 요일 계산하는 함수
   * @param {string} dayValue - 일(day) 값
   * @param {number} colIndex - 엑셀 컬럼 인덱스
   * @param {string} startDateStr - 시작 날짜 문자열 (YYYY-MM-DD)
   * @returns {number} 요일 (0: 일요일, 1: 월요일, ..., 6: 토요일)
   */
  function getDayOfWeekFromTimeline(dayValue, colIndex, startDateStr) {
    try {
      var startDate = new Date(startDateStr);
      var dayNumber = parseInt(dayValue);
      
      if (isNaN(dayNumber)) {
        return -1;
      }
      
      var daysFromStart = colIndex - 3;
      var currentDate = new Date(startDate);
      currentDate.setDate(startDate.getDate() + daysFromStart);
      
      return currentDate.getDay();
    } catch (error) {
      console.error('getDayOfWeekFromTimeline 오류:', error);
      return -1;
    }
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
   * 스케줄 바 스타일 적용 함수
   * @param {Object} options - 스타일 옵션
   * @param {string} options.customFontColor - 커스텀 폰트 색상 (#RRGGBB)
   * @param {boolean} options.isMuted - muted 상태 여부
   */
  function applyScheduleBarStyle(worksheet, rowIndex, startCol, endCol, issueNumber, categoryColor, doneRatio, memo, link, options) {
    try {
      options = options || {};
      var cell = worksheet.getCell(rowIndex, startCol);
      
      var fontColor = 'FF000000';  // 기본 검정색
      var isBold = true;
      
      // customFontColor가 지정된 경우 우선 사용
      if (options.customFontColor) {
        fontColor = options.customFontColor.replace('#', 'FF');
      }
      
      // muted 상태면 bold 해제
      if (options.isMuted) {
        isBold = false;
      }
      
      // customColor가 있을 때만 배경색 적용
      if (categoryColor) {
        var fillColor = categoryColor.replace('#', 'FF');
        
        // customFontColor가 없을 때만 밝기 기반 자동 계산
        if (!options.customFontColor) {
          var rgb = categoryColor.replace('#', '');
          var r = parseInt(rgb.substr(0, 2), 16);
          var g = parseInt(rgb.substr(2, 2), 16);
          var b = parseInt(rgb.substr(4, 2), 16);
          var brightness = (r * 299 + g * 587 + b * 114) / 1000;
          
          fontColor = brightness > 128 ? 'FF000000' : 'FFFFFFFF';
        }
        
        cell.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: fillColor }
        };
      }
      
      cell.font = {
        color: { argb: fontColor },
        bold: isBold,
        size: 8
      };
      
      cell.alignment = {
        horizontal: 'center',
        vertical: 'middle',
        wrapText: false
      };
      
      cell.border = {
        top: { style: 'thin' },
        left: { style: 'thin' },
        bottom: { style: 'thin' },
        right: { style: 'thin' }
      };
      
      // 메모가 있으면 셀 메모(코멘트) 추가
      if (memo) {
        cell.note = {
          texts: [
            {
              font: { size: 10, name: '맑은 고딕' },
              text: memo
            }
          ],
          margins: {
            insetmode: 'auto',
            inset: [0.13, 0.13, 0.13, 0.13]
          }
        };
      }
      
      // 이슈 URL이 있으면 셀에 하이퍼링크 추가
      if (link) {
        // 현재 셀의 텍스트 값 저장 (객체가 아닌 문자열로)
        var cellText = '';
        if (cell.value) {
          if (typeof cell.value === 'object' && cell.value.text) {
            cellText = cell.value.text;
          } else if (typeof cell.value === 'string') {
            cellText = cell.value;
          } else {
            cellText = String(cell.value);
          }
        }
        
        // 하이퍼링크 객체로 설정
        cell.value = {
          text: cellText,
          hyperlink: link,
          tooltip: link
        };
        
        // 하이퍼링크 스타일 추가 (기존 폰트 속성 유지하면서 밑줄 추가)
        var existingFont = cell.font || {};
        var newFont = {};
        for (var key in existingFont) {
          if (existingFont.hasOwnProperty(key)) {
            newFont[key] = existingFont[key];
          }
        }
        newFont.underline = true;
        cell.font = newFont;
      }
      
    } catch (error) {
      console.error('applyScheduleBarStyle 오류:', error);
    }
  }

  /**
   * 헤더 스타일 적용 함수
   * @param {ExcelJS.Worksheet} worksheet - 워크시트
   * @param {number} columnCount - 컬럼 수
   * @param {string} startDateStr - 시작 날짜 문자열 (YYYY-MM-DD)
   */
  function applyHeaderStyles(worksheet, columnCount, startDateStr) {
    try {
      
      // 첫 번째 행 (월 헤더)
      for (var col = 1; col <= columnCount; col++) {
        var cell = worksheet.getCell(1, col);
        cell.font = { bold: true };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE6E6E6' } };
        cell.alignment = { horizontal: 'center', vertical: 'middle' };
        
        var isMonthBoundary = false;
        if (col >= 3) {
          var dayHeaderCell = worksheet.getCell(2, col);
          var dayValue = dayHeaderCell.value;
          if (dayValue && dayValue.toString() === '1') {
            isMonthBoundary = true;
          }
        }
        
        // C열(col 3)의 left는 B열의 right와 공유
        var leftBorder = col === 3 ? { style: 'medium' } : { style: 'thin', color: { argb: col >= 3 ? 'FFD0D0D0' : 'FF000000' } };
        
        if (isMonthBoundary) {
          cell.border = {
            top: { style: 'thin' },
            left: leftBorder,
            bottom: { style: 'thin' },
            right: { style: 'thin', color: { argb: 'FFD0D0D0' } }
          };
        } else {
          cell.border = {
            top: { style: 'thin' },
            left: leftBorder,
            bottom: { style: 'thin' },
            right: col === 2 ? { style: 'medium' } : { style: 'thin', color: { argb: col >= 3 ? 'FFD0D0D0' : 'FF000000' } }
          };
        }
      }
      
      // 두 번째 행 (일 헤더)
      for (var col = 1; col <= columnCount; col++) {
        var cell = worksheet.getCell(2, col);
        var cellValue = cell.value;
        
        cell.font = { bold: false };
        
        if (col >= 3 && cellValue) {
          var dayValue = cellValue.toString();
          var dayOfWeek = getDayOfWeekFromTimeline(dayValue, col, startDateStr);
          
          if (dayOfWeek === 0) {
            cell.font = { bold: false, color: { argb: 'FFFF0000' } };
          } else if (dayOfWeek === 6) {
            cell.font = { bold: false, color: { argb: 'FF0000FF' } };
          }
        }
        
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE6E6E6' } };
        cell.alignment = { horizontal: 'center', vertical: 'middle' };
        
        var isMonthBoundary = false;
        if (col >= 3 && cellValue && cellValue.toString() === '1') {
          isMonthBoundary = true;
        }
        
        // C열(col 3)의 left는 B열의 right와 공유
        var leftBorder = col === 3 ? { style: 'medium' } : { style: 'thin', color: { argb: col >= 3 ? 'FFD0D0D0' : 'FF000000' } };
        
        if (isMonthBoundary) {
          cell.border = {
            top: { style: 'thin' },
            left: leftBorder,
            bottom: { style: 'thin' },
            right: { style: 'thin', color: { argb: 'FFD0D0D0' } }
          };
        } else {
          cell.border = {
            top: { style: 'thin' },
            left: leftBorder,
            bottom: { style: 'thin' },
            right: col === 2 ? { style: 'medium' } : { style: 'thin', color: { argb: col >= 3 ? 'FFD0D0D0' : 'FF000000' } }
          };
        }
      }
      
      // 카테고리 및 이벤트 컬럼 스타일
      var rowCount = worksheet.rowCount;
      var categoryRanges = worksheet.categoryRanges || [];
      
      // 카테고리 시작/끝 행 Set 생성
      var categoryStartSet = {};
      var categoryEndSet = {};
      categoryRanges.forEach(function(range) {
        categoryStartSet[range.start] = true;
        categoryEndSet[range.end] = true;
      });
      
      for (var row = 3; row <= rowCount; row++) {
        var categoryCell = worksheet.getCell(row, 1);
        var eventCell = worksheet.getCell(row, 2);
        
        // 카테고리 시작/끝 행 판정
        var isCategoryStart = categoryStartSet[row] || false;
        var isCategoryEnd = categoryEndSet[row] || false;
        
        // 카테고리 시작 행: 굵은 상단 border, 끝 행: 굵은 하단 border
        var topBorder = isCategoryStart 
          ? { style: 'medium' } 
          : { style: 'thin', color: { argb: 'FFE0E0E0' } };
        var bottomBorder = isCategoryEnd 
          ? { style: 'medium' } 
          : { style: 'thin', color: { argb: 'FFE0E0E0' } };
        
        // 가운데 정렬
        categoryCell.alignment = { horizontal: 'center', vertical: 'middle' };
        categoryCell.border = {
          top: topBorder,
          left: { style: 'thin' },
          bottom: bottomBorder,
          right: { style: 'thin' }
        };
        
        // 가운데 정렬
        eventCell.alignment = { horizontal: 'center', vertical: 'middle' };
        eventCell.border = {
          top: topBorder,
          left: { style: 'thin' },
          bottom: bottomBorder,
          right: { style: 'medium' }
        };
        
        // 행 높이 설정 (옵션에서 가져오기, 기본값 30)
        var rowHeight = (worksheet.options && worksheet.options.rowHeight) || 30;
        worksheet.getRow(row).height = rowHeight;
        
        for (var col = 3; col <= columnCount; col++) {
          var cell = worksheet.getCell(row, col);
          
          var dayHeaderCell = worksheet.getCell(2, col);
          var dayValue = dayHeaderCell.value;
          var isMonthBoundary = (dayValue && dayValue.toString() === '1');
          
          // C열(col 3)의 left border는 B열의 right와 공유하므로 medium 처리
          var leftBorder = col === 3 ? { style: 'medium' } : { style: 'thin', color: { argb: 'FFD0D0D0' } };
          
          if (isMonthBoundary) {
            cell.border = {
              top: topBorder,
              left: leftBorder,
              bottom: bottomBorder,
              right: { style: 'thin', color: { argb: 'FFD0D0D0' } }
            };
          } else {
            cell.border = {
              top: topBorder,
              left: leftBorder,
              bottom: bottomBorder,
              right: { style: 'thin', color: { argb: 'FFD0D0D0' } }
            };
          }
        }
      }
      
    } catch (error) {
      console.error('applyHeaderStyles 오류:', error);
    }
  }

  /**
   * 범례 섹션 추가
   * @param {ExcelJS.Worksheet} worksheet - 워크시트
   * @param {Array} legends - 범례 배열 [{title: "제목", color: "#FF0000", url: "http://..."}, ...]
   * @param {number} startRow - 범례 시작 행 번호
   * @param {Object} options - 옵션 (rowHeight 등)
   */
  function addLegendSection(worksheet, legends, startRow, options) {
    try {
      if (!legends || !Array.isArray(legends) || legends.length === 0) {
        return;
      }
      
      var rowHeight = (options && options.rowHeight) || 30;
      var currentRow = startRow;
      
      // 빈 행 2줄 추가 (구분용)
      currentRow += 2;
      
      // 제목 행 추가 ("📌 범례")
      var titleCell = worksheet.getCell(currentRow, 1);
      titleCell.value = '📌 범례';
      titleCell.font = { bold: true, size: 11 };
      titleCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE6E6E6' } };
      titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
      titleCell.border = {
        top: { style: 'thin' },
        left: { style: 'thin' },
        bottom: { style: 'thin' },
        right: { style: 'thin' }
      };
      worksheet.getRow(currentRow).height = rowHeight;
      currentRow++;
      
      // 각 범례 항목 추가
      legends.forEach(function(legend) {
        if (!legend.title || !legend.color) {
          return;  // 필수 정보 없으면 스킵
        }
        
        var legendCell = worksheet.getCell(currentRow, 1);
        legendCell.value = legend.title;
        
        // 배경색 적용
        var fillColor = legend.color.replace('#', 'FF');
        legendCell.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: fillColor }
        };
        
        // 폰트 색상 자동 계산 (밝기 기반)
        var rgb = legend.color.replace('#', '');
        var r = parseInt(rgb.substr(0, 2), 16);
        var g = parseInt(rgb.substr(2, 2), 16);
        var b = parseInt(rgb.substr(4, 2), 16);
        var brightness = (r * 299 + g * 587 + b * 114) / 1000;
        var fontColor = brightness > 128 ? 'FF000000' : 'FFFFFFFF';
        
        legendCell.font = {
          color: { argb: fontColor },
          bold: true,
          size: 10
        };
        
        // 하이퍼링크 추가 (URL이 있으면)
        if (legend.url) {
          legendCell.value = {
            text: legend.title,
            hyperlink: legend.url,
            tooltip: legend.url
          };
          
          // 하이퍼링크 스타일 (밑줄)
          legendCell.font = {
            color: { argb: fontColor },
            bold: true,
            size: 10,
            underline: true
          };
        }
        
        // 정렬 및 테두리
        legendCell.alignment = { horizontal: 'left', vertical: 'middle' };
        legendCell.border = {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' }
        };
        
        worksheet.getRow(currentRow).height = rowHeight;
        currentRow++;
      });
      
    } catch (error) {
      console.error('addLegendSection 오류:', error);
    }
  }

  // ============================================================
  // 메인 함수
  // ============================================================

  /**
   * 로드맵 타임라인 시트 생성
   * @param {ExcelJS.Workbook} workbook - ExcelJS 워크북 객체
   * @param {Object} jsonData - JSON 데이터 (options.startDate/endDate 선택적 - 없으면 스케줄에서 자동 계산)
   */
  function createRoadmapTimelineSheet(workbook, jsonData) {
    try {
      // 옵션 추출 및 기본값 설정
      var options = jsonData.options || {};
      var categoryLabel = options.categoryLabel || '카테고리';
      var eventLabel = options.eventLabel || '이벤트';
      var rowHeight = options.rowHeight || 30;
      var showScheduleName = options.showScheduleName !== false;  // 기본값 true
      
      var startDate, endDate;
      var startDateStr, endDateStr;
      
      // options에서 날짜 정보 확인, 없으면 categories에서 자동 계산
      if (options.startDate && options.endDate) {
        startDate = new Date(options.startDate);
        endDate = new Date(options.endDate);
        startDateStr = options.startDate;
        endDateStr = options.endDate;
      } else {
        // categories의 스케줄에서 날짜 범위 자동 계산
        var calculatedTimeline = calculateTimelineFromCategories(jsonData.categories);
        if (!calculatedTimeline) {
          throw new Error('options에 startDate/endDate가 없고 스케줄에서 날짜를 계산할 수 없습니다.');
        }
        startDate = calculatedTimeline.startDate;
        endDate = calculatedTimeline.endDate;
        startDateStr = startDate.toISOString().split('T')[0];
        endDateStr = endDate.toISOString().split('T')[0];
        console.log('날짜 범위 자동 계산:', startDateStr, '~', endDateStr);
      }
      
      var months = generateMonthHeaders(startDate, endDate);
      var days = generateDayHeaders(startDate, endDate);
      
      var worksheet = workbook.addWorksheet('로드맵 타임라인');
      
      // 옵션을 worksheet에 저장 (applyHeaderStyles에서 사용)
      worksheet.options = { rowHeight: rowHeight };
      
      // 첫 번째 행: 월 헤더
      var monthRow = [categoryLabel, eventLabel];
      var colIndex = 3;
      months.forEach(function(month) {
        monthRow.push(month.name);
        for (var i = 1; i < month.days; i++) {
          monthRow.push('');
        }
      });
      worksheet.addRow(monthRow);
      
      // 두 번째 행: 일 헤더
      var dayRow = ['', ''];
      days.forEach(function(day) {
        dayRow.push(day);
      });
      worksheet.addRow(dayRow);
      
      // 월 헤더 병합
      colIndex = 3;
      months.forEach(function(month) {
        if (month.days > 1) {
          worksheet.mergeCells(1, colIndex, 1, colIndex + month.days - 1);
        }
        colIndex += month.days;
      });
      
      // 카테고리/이벤트 헤더 셀 병합 (A1-A2, B1-B2)
      worksheet.mergeCells('A1:A2');
      worksheet.mergeCells('B1:B2');
      
      // 병합된 헤더 셀 스타일 적용
      var categoryHeaderCell = worksheet.getCell('A1');
      categoryHeaderCell.alignment = { horizontal: 'center', vertical: 'middle' };
      
      var eventHeaderCell = worksheet.getCell('B1');
      eventHeaderCell.alignment = { horizontal: 'center', vertical: 'middle' };
      
      // 데이터 행들 및 스케줄 바 생성
      var currentRowIndex = 3;
      
      // 카테고리 범위 기록 (applyHeaderStyles에서 사용)
      worksheet.categoryRanges = [];  // [{start: 3, end: 5}, ...]
      
      jsonData.categories.forEach(function(category, categoryIndex) {
        var categoryName = category.name;
        var categoryColor = category.customColor;  // customColor 있을 때만 배경색 적용
        
        var categoryRowStart = currentRowIndex;
        var eventRowsCount = 0;
        var isFirstEvent = true;
        
        category.events.forEach(function(event) {
          var eventName = event.name;
          
          // 첫 번째 이벤트 행에 카테고리 이름 포함 (빈 행 제거)
          var eventRow = [isFirstEvent ? categoryName : '', eventName];
          days.forEach(function() {
            eventRow.push('');
          });
          
          event.schedules.forEach(function(schedule, scheduleIndex) {
            var scheduleName = schedule.name;
            var issueNumber = schedule.issue || '';
            var doneRatio = schedule.doneRatio || null;
            var scheduleColor = schedule.customColor || categoryColor;
            var memo = schedule.memo || null;
            var link = schedule.link || null;
            
            if (schedule.startDate && schedule.endDate) {
              var scheduleStartDate = new Date(schedule.startDate);
              var scheduleEndDate = new Date(schedule.endDate);
              
              if (!isNaN(scheduleStartDate.getTime()) && !isNaN(scheduleEndDate.getTime())) {
                var startDayIndex = Math.floor((scheduleStartDate - startDate) / (1000 * 60 * 60 * 24));
                var endDayIndex = Math.floor((scheduleEndDate - startDate) / (1000 * 60 * 60 * 24));
                
                var excelStartCol = startDayIndex + 3;
                var excelEndCol = endDayIndex + 3;
                
                if (excelStartCol >= 3 && excelStartCol <= eventRow.length) {
                  eventRow[excelStartCol - 1] = showScheduleName ? scheduleName : '';
                  
                  if (excelEndCol >= excelStartCol) {
                    if (!worksheet.scheduleMerges) {
                      worksheet.scheduleMerges = [];
                    }
                    worksheet.scheduleMerges.push({
                      row: currentRowIndex,
                      startCol: excelStartCol,
                      endCol: excelEndCol,
                      issueNumber: issueNumber,
                      categoryColor: scheduleColor,
                      scheduleName: scheduleName,
                      isCustomColor: !!schedule.customColor,
                      doneRatio: doneRatio,
                      memo: memo,
                      link: link,
                      customFontColor: schedule.customFontColor,
                      isMuted: schedule.isMuted
                    });
                  }
                }
              }
            }
          });
          
          worksheet.addRow(eventRow);
          eventRowsCount++;
          currentRowIndex++;
          isFirstEvent = false;
        });
        
        // 이벤트가 없는 카테고리 처리
        if (eventRowsCount === 0) {
          var emptyRow = [categoryName, '(이벤트 없음)'];
          days.forEach(function() {
            emptyRow.push('');
          });
          worksheet.addRow(emptyRow);
          eventRowsCount = 1;
          currentRowIndex++;
        }
        
        // 카테고리 범위 기록 (시작행, 끝행)
        var categoryRowEnd = currentRowIndex - 1;
        worksheet.categoryRanges.push({ start: categoryRowStart, end: categoryRowEnd });
        
        // 카테고리 병합 (이벤트가 2개 이상일 때만)
        if (eventRowsCount > 1) {
          worksheet.mergeCells(categoryRowStart, 1, categoryRowEnd, 1);
        }
        
        // 카테고리 셀 스타일 적용
        var categoryCell = worksheet.getCell(categoryRowStart, 1);
        
        if (categoryColor) {
          var fillColor = categoryColor.replace('#', 'FF');
          
          var rgb = categoryColor.replace('#', '');
          var r = parseInt(rgb.substr(0, 2), 16);
          var g = parseInt(rgb.substr(2, 2), 16);
          var b = parseInt(rgb.substr(4, 2), 16);
          var brightness = (r * 299 + g * 587 + b * 114) / 1000;
          var fontColor = brightness > 128 ? 'FF000000' : 'FFFFFFFF';
          
          categoryCell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: fillColor }
          };
          
          categoryCell.font = {
            color: { argb: fontColor },
            bold: true,
            size: 11
          };
        } else {
          categoryCell.font = {
            bold: true,
            size: 11
          };
        }
        
        categoryCell.alignment = {
          horizontal: 'center',
          vertical: 'middle'
        };
      });
      
      // 컬럼 너비 설정
      worksheet.getColumn(1).width = 20;
      worksheet.getColumn(2).width = 25;
      for (var i = 3; i <= days.length + 2; i++) {
        worksheet.getColumn(i).width = 2.8;
      }
      
      // 헤더 스타일 적용
      applyHeaderStyles(worksheet, days.length + 2, startDateStr);
      
      // 틀 고정 설정
      worksheet.views = [
        {
          state: 'frozen',
          xSplit: 2,
          ySplit: 2,
          topLeftCell: 'C3',
          activeCell: 'C3'
        }
      ];
      
      // 스케줄 바 병합 및 스타일 적용
      if (worksheet.scheduleMerges && worksheet.scheduleMerges.length > 0) {
        // 이미 병합된 셀 범위 추적
        var mergedRanges = {};
        
        worksheet.scheduleMerges.forEach(function(merge) {
          try {
            // 이 행에서 이미 병합된 범위와 겹치는지 확인
            var rangeKey = 'row_' + merge.row;
            if (!mergedRanges[rangeKey]) {
              mergedRanges[rangeKey] = [];
            }
            
            // 겹치는 범위가 있는지 확인
            var hasOverlap = mergedRanges[rangeKey].some(function(existing) {
              return !(merge.endCol < existing.startCol || merge.startCol > existing.endCol);
            });
            
            if (hasOverlap) {
              console.warn('스케줄 날짜 범위 겹침 - 병합 스킵:', merge.scheduleName, '행:', merge.row, '열:', merge.startCol, '-', merge.endCol);
              // 스타일만 적용 (병합 없이)
              applyScheduleBarStyle(worksheet, merge.row, merge.startCol, merge.startCol, merge.issueNumber, merge.categoryColor, merge.doneRatio, merge.memo, merge.link, {
                customFontColor: merge.customFontColor,
                isMuted: merge.isMuted
              });
              return;
            }
            
            // 병합 실행
            if (merge.startCol < merge.endCol) {
              worksheet.mergeCells(merge.row, merge.startCol, merge.row, merge.endCol);
            }
            
            // 병합된 범위 기록
            mergedRanges[rangeKey].push({ startCol: merge.startCol, endCol: merge.endCol });
            
            applyScheduleBarStyle(worksheet, merge.row, merge.startCol, merge.endCol, merge.issueNumber, merge.categoryColor, merge.doneRatio, merge.memo, merge.link, {
              customFontColor: merge.customFontColor,
              isMuted: merge.isMuted
            });
          } catch (mergeError) {
            console.error('병합 오류:', mergeError, merge);
          }
        });
      }
      
      // 범례 섹션 추가
      if (jsonData.legends && Array.isArray(jsonData.legends) && jsonData.legends.length > 0) {
        var lastDataRow = currentRowIndex - 1;  // 마지막 데이터 행
        addLegendSection(worksheet, jsonData.legends, lastDataRow, { rowHeight: rowHeight });
      }
      
    } catch (error) {
      console.error('createRoadmapTimelineSheet 오류:', error);
      throw error;
    }
  }

  /**
   * 스케줄 리스트 시트 생성
   * @param {ExcelJS.Workbook} workbook - ExcelJS 워크북 객체
   * @param {Object} jsonData - JSON 데이터
   */
  function createScheduleListSheet(workbook, jsonData) {
    try {
      // 옵션 추출 및 기본값 설정
      var options = jsonData.options || {};
      var categoryLabel = options.categoryLabel || '카테고리';
      var eventLabel = options.eventLabel || '이벤트';
      
      var worksheet = workbook.addWorksheet('스케줄 리스트');
      
      var headerRow = worksheet.addRow([categoryLabel, eventLabel, '스케줄명', '시작일', '종료일', '이슈', '기간', '완료율']);
      
      headerRow.eachCell(function(cell) {
        cell.font = { bold: true };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE6E6E6' } };
        cell.alignment = { horizontal: 'center', vertical: 'middle' };
        cell.border = {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' }
        };
      });
      
      jsonData.categories.forEach(function(category) {
        var categoryName = category.name;
        
        category.events.forEach(function(event) {
          var eventName = event.name;
          var hasSchedules = false;
          
          event.schedules.forEach(function(schedule) {
            var scheduleName = schedule.name;
            var startDateStr = schedule.startDate || '';
            var endDateStr = schedule.endDate || '';
            var duration = '';
            
            if (startDateStr && endDateStr) {
              var start = new Date(startDateStr);
              var end = new Date(endDateStr);
              if (!isNaN(start.getTime()) && !isNaN(end.getTime())) {
                var diffTime = Math.abs(end - start);
                var diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
                duration = diffDays + '일';
              }
            }
            
            var issueNumber = schedule.issue || '';
            var doneRatio = schedule.doneRatio || null;
            var memo = schedule.memo || null;
            
            var dataRow = worksheet.addRow([categoryName, eventName, scheduleName, startDateStr, endDateStr, issueNumber, duration, doneRatio]);
            
            dataRow.eachCell(function(cell, colNumber) {
              cell.border = {
                top: { style: 'thin' },
                left: { style: 'thin' },
                bottom: { style: 'thin' },
                right: { style: 'thin' }
              };
              cell.alignment = { horizontal: 'left', vertical: 'middle' };
              
              // 스케줄명 셀(3번째 컬럼)에 메모 추가
              if (colNumber === 3 && memo) {
                cell.note = {
                  texts: [
                    {
                      font: { size: 10, name: '맑은 고딕' },
                      text: memo
                    }
                  ],
                  margins: {
                    insetmode: 'auto',
                    inset: [0.13, 0.13, 0.13, 0.13]
                  }
                };
              }
            });
            
            hasSchedules = true;
          });
          
          if (!hasSchedules) {
            var dataRow = worksheet.addRow([categoryName, eventName, '(스케줄 없음)', '', '', '', '', '']);
            dataRow.eachCell(function(cell) {
              cell.border = {
                top: { style: 'thin' },
                left: { style: 'thin' },
                bottom: { style: 'thin' },
                right: { style: 'thin' }
              };
              cell.alignment = { horizontal: 'left', vertical: 'middle' };
            });
          }
        });
      });
      
      worksheet.getColumn(1).width = 20;
      worksheet.getColumn(2).width = 25;
      worksheet.getColumn(3).width = 30;
      worksheet.getColumn(4).width = 12;
      worksheet.getColumn(5).width = 12;
      worksheet.getColumn(6).width = 10;
      worksheet.getColumn(7).width = 8;
      
    } catch (error) {
      console.error('createScheduleListSheet 오류:', error);
      throw error;
    }
  }

  /**
   * JSON 데이터로부터 Excel 파일 생성 및 다운로드
   * @param {Object} jsonData - JSON 데이터
   * @param {string} fileName - 파일명 (확장자 제외)
   * @returns {Promise} 다운로드 완료 Promise
   */
  function exportToXlsx(jsonData, fileName) {
    return new Promise(function(resolve, reject) {
      try {
        if (typeof ExcelJS === 'undefined') {
          throw new Error('ExcelJS 라이브러리가 로드되지 않았습니다.');
        }
        
        var workbook = new ExcelJS.Workbook();
        
        createRoadmapTimelineSheet(workbook, jsonData);
        createScheduleListSheet(workbook, jsonData);
        
        var finalFileName = (fileName || 'roadmap') + '.xlsx';
        
        workbook.xlsx.writeBuffer().then(function(buffer) {
          var blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
          var url = URL.createObjectURL(blob);
          var a = document.createElement('a');
          a.href = url;
          a.download = finalFileName;
          a.click();
          URL.revokeObjectURL(url);
          resolve();
        }).catch(reject);
        
      } catch (error) {
        reject(error);
      }
    });
  }

  // ============================================================
  // Public API
  // ============================================================
  
  return {
    // 헬퍼 함수
    generateMonthHeaders: generateMonthHeaders,
    generateDayHeaders: generateDayHeaders,
    
    // 메인 함수
    createRoadmapTimelineSheet: createRoadmapTimelineSheet,
    createScheduleListSheet: createScheduleListSheet,
    exportToXlsx: exportToXlsx
  };

})();

