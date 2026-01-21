/**
 * TX Issue Autocomplete
 * 일감 ID 다중 자동완성 기능을 제공하는 공통 유틸리티
 * 
 * 이 라이브러리는 Redmine의 기본 multipleAutocompleteField 함수를 확장하여
 * 일감 ID나 제목을 입력받아 자동완성 기능을 제공합니다.
 * 
 * @fileoverview Redmine TX Base 플러그인의 일감 자동완성 공통 라이브러리
 * @version 1.0.0
 * @author Redmine TX Team
 * 
 * @requires jQuery
 * @requires jQuery UI Autocomplete
 * @requires Redmine application.js (multipleAutocompleteField)
 * 
 * @description
 * 주요 기능:
 * - 일감 번호 또는 제목으로 검색
 * - 여러 개의 일감 ID를 쉼표, 세미콜론, 공백으로 구분하여 입력
 * - 프로젝트별 또는 전체 범위 검색 지원
 * - 선택 후 콜백 함수 지원
 * 
 * 사용 방법:
 * 1. 뷰 파일에 JavaScript 파일 포함:
 *    <%= javascript_include_tag 'tx_issue_autocomplete', plugin: 'redmine_tx_0_base' %>
 * 
 * 2. 입력 필드 준비:
 *    <textarea id="issue-ids"></textarea>
 * 
 * 3. 자동완성 초기화:
 *    setupIssueAutocomplete('issue-ids', url, options);
 * 
 * @example
 * // 기본 사용법
 * setupIssueAutocomplete('issue-ids', '/tx_base/autocompletes/top_parent_issues', {
 *   projectId: '123'
 * });
 * 
 * @example
 * // 콜백 함수 사용
 * setupIssueAutocomplete('issue-ids', '/tx_base/autocompletes/top_parent_issues', {
 *   scope: 'all',
 *   onSelect: function() {
 *     console.log('Selected:', this.value);
 *   }
 * });
 * 
 * @see README.rdoc - 전체 문서
 */

/**
 * 일감 ID 다중 자동완성 설정
 * 
 * textarea 또는 input 필드에 일감 자동완성 기능을 추가합니다.
 * 사용자가 일감 번호나 제목을 입력하면 자동완성 목록이 표시되며,
 * 여러 개의 일감 ID를 쉼표(,), 세미콜론(;), 공백으로 구분하여 입력할 수 있습니다.
 * 
 * @param {string} fieldId - 입력 필드의 DOM ID (# 없이)
 * @param {string} url - 자동완성 데이터를 가져올 URL (일반적으로 tx_base_top_parent_issues_path)
 * @param {Object} [options={}] - 추가 옵션
 * @param {string} [options.projectId] - 특정 프로젝트로 검색을 제한할 프로젝트 ID
 * @param {string} [options.scope] - 검색 범위 (예: 'all'), projectId가 없을 때 사용
 * @param {function} [options.onSelect] - 일감 선택 후 실행될 콜백 함수. this는 입력 필드를 가리킴
 * 
 * @returns {void}
 * 
 * @example
 * // 프로젝트 범위로 제한
 * setupIssueAutocomplete('issue-ids', '/tx_base/autocompletes/top_parent_issues', {
 *   projectId: '123'
 * });
 * 
 * @example
 * // 전체 프로젝트 검색 + 콜백
 * setupIssueAutocomplete('issue-ids', '/tx_base/autocompletes/top_parent_issues', {
 *   scope: 'all',
 *   onSelect: function() {
 *     var ids = parseIssueIds(this.value);
 *     console.log('선택된 일감 수:', ids.length);
 *   }
 * });
 */
function setupIssueAutocomplete(fieldId, url, options) {
  options = options || {};
  
  // 일감 ID 구분자 (쉼표, 세미콜론, 공백)
  var issueIdSplitter = /[,;\s]+/;
  
  multipleAutocompleteField(
    fieldId,
    url,
    {
      source: function(request, response) {
        var term = request.term.split(issueIdSplitter).pop();
        if (!term) { 
          response([]); 
          return; 
        }

        var data = { term: term };
        
        // 프로젝트 ID가 제공되면 추가
        if (options.projectId) {
          data['project_id'] = options.projectId;
        }
        
        // 검색 범위가 제공되면 추가
        if (options.scope) {
          data['scope'] = options.scope;
        }

        $.getJSON(url, data, response);
      },
      select: function(event, ui) {
        var terms = this.value.split(issueIdSplitter).filter(function(v){ 
          return v.length > 0; 
        });
        terms.pop(); // 기존 입력 토큰 제거
        terms.push(String(ui.item.value)); // 선택한 일감 ID만 추가
        this.value = terms.join(", ") + ", ";
        
        // 콜백 함수가 제공되면 실행
        if (options.onSelect && typeof options.onSelect === 'function') {
          options.onSelect.call(this);
        }
        
        return false;
      }
    }
  );
}

/**
 * 입력된 일감 ID들을 파싱하는 유틸리티 함수
 * 
 * 쉼표(,), 세미콜론(;), 공백으로 구분된 문자열에서 유효한 일감 ID만 추출합니다.
 * 숫자가 아닌 값, 0 이하의 값은 자동으로 필터링됩니다.
 * 
 * @param {string} input - 파싱할 입력 문자열
 * @returns {Array<number>} 파싱된 일감 ID 배열 (중복 제거되지 않음, 입력 순서 유지)
 * 
 * @example
 * // 쉼표 구분
 * parseIssueIds("1234, 5678, 9012");
 * // => [1234, 5678, 9012]
 * 
 * @example
 * // 혼합 구분자
 * parseIssueIds("1234, 5678; 9012 3456");
 * // => [1234, 5678, 9012, 3456]
 * 
 * @example
 * // 잘못된 값 필터링
 * parseIssueIds("1234, abc, 5678, -1, 0");
 * // => [1234, 5678]
 * 
 * @example
 * // 빈 문자열
 * parseIssueIds("");
 * // => []
 */
function parseIssueIds(input) {
  if (!input) return [];
  
  var issueIdSplitter = /[,;\s]+/;
  
  return input.split(issueIdSplitter)
    .map(function(id) { return id.trim(); })
    .filter(function(id) { 
      return id.length > 0 && !isNaN(id) && parseInt(id) > 0; 
    })
    .map(function(id) { return parseInt(id); });
}
