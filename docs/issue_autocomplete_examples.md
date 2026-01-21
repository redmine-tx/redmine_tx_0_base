# TX Issue Autocomplete 사용 예제

## 목차
1. [기본 사용법](#기본-사용법)
2. [프로젝트별 검색](#프로젝트별-검색)
3. [전체 프로젝트 검색](#전체-프로젝트-검색)
4. [콜백 함수 활용](#콜백-함수-활용)
5. [버튼 활성화 연동](#버튼-활성화-연동)
6. [여러 일감 처리](#여러-일감-처리)

---

## 기본 사용법

가장 간단한 형태의 자동완성 구현입니다.

### HTML
```erb
<!-- JavaScript 파일 포함 -->
<%= javascript_include_tag 'tx_issue_autocomplete', plugin: 'redmine_tx_0_base' %>

<!-- 입력 필드 -->
<textarea id="issue-ids" placeholder="일감 ID나 제목을 입력하세요"></textarea>
```

### JavaScript
```javascript
<script>
$(document).ready(function() {
  setupIssueAutocomplete(
    'issue-ids',
    '<%= tx_base_top_parent_issues_path %>',
    {
      projectId: '<%= @project.id %>'
    }
  );
});
</script>
```

---

## 프로젝트별 검색

특정 프로젝트의 일감만 검색하는 경우입니다.

```erb
<!-- 뷰 파일 (예: app/views/milestone/_tetris_select_target_issue.html.erb) -->
<%= javascript_include_tag 'tx_issue_autocomplete', plugin: 'redmine_tx_0_base' %>

<div class="form-group">
  <label for="issue-id-input">일감 ID:</label>
  <textarea id="issue-id-input" placeholder="일감 ID나 제목을 입력하세요"></textarea>
</div>

<script>
$(document).ready(function() {
  setupIssueAutocomplete(
    'issue-id-input',
    '<%= j tx_base_top_parent_issues_path %>',
    {
      <% if @project.present? %>
      projectId: '<%= @project.id %>'
      <% end %>
    }
  );
});
</script>
```

---

## 전체 프로젝트 검색

모든 프로젝트를 대상으로 검색하는 경우입니다.

```erb
<%= javascript_include_tag 'tx_issue_autocomplete', plugin: 'redmine_tx_0_base' %>

<textarea id="global-issue-search"></textarea>

<script>
$(document).ready(function() {
  setupIssueAutocomplete(
    'global-issue-search',
    '<%= tx_base_top_parent_issues_path %>',
    {
      scope: 'all'
    }
  );
});
</script>
```

---

## 콜백 함수 활용

일감 선택 후 추가 동작이 필요한 경우입니다.

```javascript
$(document).ready(function() {
  setupIssueAutocomplete(
    'issue-ids',
    '<%= tx_base_top_parent_issues_path %>',
    {
      projectId: '<%= @project.id %>',
      onSelect: function() {
        // this는 입력 필드를 가리킴
        console.log('선택된 값:', this.value);
        
        // 선택된 일감 수 카운트
        var issueIds = parseIssueIds(this.value);
        $('#issue-count').text(issueIds.length + '개의 일감 선택됨');
        
        // 추가 작업 수행
        validateSelection();
      }
    }
  );
});
```

---

## 버튼 활성화 연동

입력 값에 따라 버튼을 활성화/비활성화하는 예제입니다.

```erb
<%= javascript_include_tag 'tx_issue_autocomplete', plugin: 'redmine_tx_0_base' %>

<div class="form-group">
  <label for="issue-id-input">일감 ID (여러 개 입력 가능):</label>
  <textarea id="issue-id-input" 
            placeholder="일감 ID나 제목을 입력하세요 (예: 12312, 32123)" 
            class="issue-id-field"></textarea>
  <div class="hint">쉼표(,), 세미콜론(;), 공백으로 구분하여 여러 일감 ID를 입력하세요.</div>
</div>

<div class="form-actions">
  <button type="button" id="start-button" class="button button-primary" disabled>
    시작
  </button>
</div>

<script>
$(document).ready(function() {
  // 버튼 활성화 상태를 업데이트하는 함수
  function updateButtonState() {
    var inputValue = $('#issue-id-input').val().trim();
    var issueIds = parseIssueIds(inputValue);
    var startButton = $('#start-button');
    
    if (issueIds.length > 0) {
      startButton.prop('disabled', false);
    } else {
      startButton.prop('disabled', true);
    }
  }
  
  // 자동완성 설정
  setupIssueAutocomplete(
    'issue-id-input',
    '<%= j tx_base_top_parent_issues_path %>',
    {
      projectId: '<%= @project.id %>',
      onSelect: updateButtonState  // 선택 후 버튼 상태 업데이트
    }
  );
  
  // 수동 입력 시에도 버튼 상태 업데이트
  $('#issue-id-input').on('input', function() {
    updateButtonState();
  });
});
</script>
```

---

## 여러 일감 처리

여러 개의 일감 ID를 처리하는 완전한 예제입니다.

```erb
<%= javascript_include_tag 'tx_issue_autocomplete', plugin: 'redmine_tx_0_base' %>

<div class="issue-selection">
  <div class="form-group">
    <label for="issue-ids">일감 ID (여러 개 입력 가능):</label>
    <textarea id="issue-ids" 
              placeholder="일감 ID나 제목을 입력하세요"
              rows="3"></textarea>
    <div class="hint">
      쉼표(,), 세미콜론(;), 공백으로 구분하여 여러 일감 ID를 입력하세요.
    </div>
  </div>
  
  <div class="selected-info">
    <span id="selected-count">0개 선택됨</span>
  </div>
  
  <div class="form-actions">
    <button type="button" id="process-button" disabled>처리</button>
    <button type="button" id="clear-button">초기화</button>
  </div>
  
  <div id="result" style="margin-top: 20px;"></div>
</div>

<script>
$(document).ready(function() {
  var projectId = '<%= params[:project_id] %>';
  
  // 선택된 일감 수 업데이트
  function updateSelectedCount() {
    var inputValue = $('#issue-ids').val().trim();
    var issueIds = parseIssueIds(inputValue);
    
    $('#selected-count').text(issueIds.length + '개 선택됨');
    $('#process-button').prop('disabled', issueIds.length === 0);
  }
  
  // 자동완성 설정
  setupIssueAutocomplete(
    'issue-ids',
    '<%= j tx_base_top_parent_issues_path %>',
    {
      <% if @project.present? %>
      projectId: '<%= @project.id %>',
      <% else %>
      scope: 'all',
      <% end %>
      onSelect: updateSelectedCount
    }
  );
  
  // 수동 입력 시에도 업데이트
  $('#issue-ids').on('input', updateSelectedCount);
  
  // Ctrl+Enter로 처리 시작
  $('#issue-ids').on('keydown', function(e) {
    if (e.which === 13 && e.ctrlKey) {
      e.preventDefault();
      $('#process-button').click();
    }
  });
  
  // 처리 버튼 클릭
  $('#process-button').click(function() {
    var inputValue = $('#issue-ids').val().trim();
    var issueIds = parseIssueIds(inputValue);
    
    if (issueIds.length === 0) {
      alert('올바른 일감 ID를 입력해주세요.');
      return;
    }
    
    // 결과 표시
    var resultHtml = '<h4>처리할 일감:</h4><ul>';
    issueIds.forEach(function(issueId) {
      resultHtml += '<li>일감 #' + issueId + '</li>';
    });
    resultHtml += '</ul>';
    $('#result').html(resultHtml);
    
    // 실제 처리 로직
    // processIssues(issueIds);
  });
  
  // 초기화 버튼
  $('#clear-button').click(function() {
    $('#issue-ids').val('');
    updateSelectedCount();
    $('#result').html('');
  });
});
</script>

<style>
.issue-selection {
  background: #f9f9f9;
  padding: 20px;
  border-radius: 5px;
}

.form-group {
  margin-bottom: 15px;
}

.form-group label {
  display: block;
  margin-bottom: 5px;
  font-weight: bold;
}

.form-group textarea {
  width: 100%;
  max-width: 600px;
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-family: monospace;
  resize: vertical;
}

.hint {
  color: #888;
  font-size: 0.9em;
  margin-top: 5px;
}

.selected-info {
  margin: 10px 0;
  color: #666;
  font-weight: bold;
}
</style>
```

---

## parseIssueIds 함수 사용 예제

입력 값을 파싱하여 배열로 변환하는 유틸리티 함수입니다.

```javascript
// 쉼표 구분
var input1 = "1234, 5678, 9012";
var ids1 = parseIssueIds(input1);
console.log(ids1); // [1234, 5678, 9012]

// 혼합 구분자
var input2 = "1234, 5678; 9012 3456";
var ids2 = parseIssueIds(input2);
console.log(ids2); // [1234, 5678, 9012, 3456]

// 잘못된 값 필터링
var input3 = "1234, abc, 5678, -1, 0";
var ids3 = parseIssueIds(input3);
console.log(ids3); // [1234, 5678]

// 빈 문자열
var input4 = "";
var ids4 = parseIssueIds(input4);
console.log(ids4); // []

// 유효성 검사
function validateIssues(input) {
  var issueIds = parseIssueIds(input);
  
  if (issueIds.length === 0) {
    return { valid: false, message: '일감 ID를 입력해주세요.' };
  }
  
  if (issueIds.length > 10) {
    return { valid: false, message: '최대 10개까지만 선택할 수 있습니다.' };
  }
  
  return { valid: true, issueIds: issueIds };
}
```

---

## 고급 예제: 실시간 유효성 검사

```javascript
$(document).ready(function() {
  var $input = $('#issue-ids');
  var $feedback = $('#feedback');
  var $submitBtn = $('#submit-btn');
  
  setupIssueAutocomplete('issue-ids', '/tx_base/autocompletes/top_parent_issues', {
    scope: 'all',
    onSelect: validateInput
  });
  
  $input.on('input', validateInput);
  
  function validateInput() {
    var input = $input.val().trim();
    var issueIds = parseIssueIds(input);
    
    // 피드백 메시지
    if (input === '') {
      $feedback.text('일감 ID를 입력하세요').removeClass('error success');
      $submitBtn.prop('disabled', true);
    } else if (issueIds.length === 0) {
      $feedback.text('유효한 일감 ID가 없습니다').addClass('error').removeClass('success');
      $submitBtn.prop('disabled', true);
    } else if (issueIds.length > 10) {
      $feedback.text('최대 10개까지만 선택할 수 있습니다 (현재: ' + issueIds.length + '개)')
        .addClass('error').removeClass('success');
      $submitBtn.prop('disabled', true);
    } else {
      $feedback.text(issueIds.length + '개의 일감 선택됨')
        .addClass('success').removeClass('error');
      $submitBtn.prop('disabled', false);
    }
  }
});
```

---

## 참고 사항

1. **최소 입력 길이**: 자동완성은 최소 2자 이상 입력해야 활성화됩니다.
2. **유효한 값**: parseIssueIds는 양의 정수만 반환합니다.
3. **입력 형식**: 쉼표(,), 세미콜론(;), 공백을 자유롭게 조합하여 사용할 수 있습니다.
4. **필드 타입**: `<textarea>` 또는 `<input type="text">` 모두 사용 가능합니다.
5. **권한**: 사용자가 접근 가능한 일감만 검색됩니다.

---

더 자세한 내용은 [README.rdoc](../README.rdoc)를 참조하세요.
