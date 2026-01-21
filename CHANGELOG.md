# Changelog

All notable changes to the Redmine TX Base plugin will be documented in this file.

## [Unreleased]

### Added
- **TX Issue Autocomplete**: 일감 ID 다중 자동완성 공통 라이브러리 추가
  - `setupIssueAutocomplete()` 함수: 일감 자동완성 설정
  - `parseIssueIds()` 함수: 일감 ID 파싱 유틸리티
  - 쉼표(,), 세미콜론(;), 공백 구분자 지원
  - 프로젝트별 또는 전체 범위 검색 지원
  - 선택 후 콜백 함수 지원
  - 상세 문서 및 예제 추가 (README.rdoc, docs/issue_autocomplete_examples.md)

### Changed
- README.rdoc 문서를 대폭 개선하여 상세한 사용법 추가

### Documentation
- TX Issue Autocomplete 사용 가이드 작성
- TX Timeline Grid 사용 가이드 작성 (docs/tx_timeline_grid_guide.md)
- TX XLSX Exporter 사용 가이드 작성 (docs/tx_xlsx_exporter_guide.md)
- JSDoc 주석을 추가하여 코드 문서화 개선
- 실전 예제 모음 문서 추가 (docs/issue_autocomplete_examples.md)
- 모든 JavaScript 라이브러리에 대한 상세 문서 완비

## [1.0.0] - Previous Release

### Existing Features
- TX Timeline Grid: 웹 기반 타임라인 렌더러
- TX XLSX Exporter: 공용 엑셀 익스포터
- TxBaseHelper: 공통 헬퍼 함수
- TxBaseAutocompletesController: 자동완성 데이터 제공
- 공통 일감 목록 컴포넌트 (_issue_list.html.erb)

---

## Version History

- **Unreleased**: TX Issue Autocomplete 추가 및 문서화
- **1.0.0**: 초기 버전 (Timeline Grid, XLSX Exporter 등)
