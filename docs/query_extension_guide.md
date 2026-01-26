= Redmine Tx Base Plugin

Redmine Tx 플러그인 시리즈의 공통 기능을 제공하는 베이스 플러그인입니다.

== 기능

* 일감 자동완성 (Autocomplete)
* 타임라인 그리드 (Timeline Grid)
* 엑셀 내보내기 (Excel Export)
* **QueryExtension**: IssueQuery 컬럼 및 필터 등록 간소화

== 개발 가이드

=== QueryExtension 사용법

Redmine의 `IssueQuery`에 새로운 컬럼과 필터를 추가할 때, 매번 `IssueQueryPatch`를 만들 필요 없이 `TxBaseHelper::QueryExtension`을 사용하여 간단하게 등록할 수 있습니다.

==== 1. `init.rb`에 등록 코드 추가

`init.rb` 파일의 `Rails.configuration.to_prepare` 블록 내에서 다음과 같이 등록합니다.

```ruby
Rails.configuration.to_prepare do
  # TxBaseHelper가 로드되어 있는지 확인
  if defined?(TxBaseHelper::QueryExtension)
    
    # 1. 단순 날짜 컬럼 추가
    TxBaseHelper::QueryExtension.register_column(:my_date_column, 
      sortable: "#{Issue.table_name}.my_date_column", # 정렬 기준 DB 컬럼
      type: :date # 필터 타입 (:date, :date_past, :string, :list 등)
    )

    # 2. 커스텀 QueryColumn 클래스 사용
    require_dependency 'my_plugin/my_custom_column'
    TxBaseHelper::QueryExtension.register_column(:my_complex_column, 
      class: MyPlugin::MyCustomColumn,
      sortable: '...',
      type: :string
    )

    # 3. 컬럼 이름과 필터 이름이 다른 경우 (예: worker 컬럼, worker_id 필터)
    TxBaseHelper::QueryExtension.register_column(:worker, 
      sortable: '...',
      type: :list,
      filter_name: 'worker_id', # 필터 이름 지정
      filter_options: { :values => lambda { ... } } # 필터 옵션
    )

    # 변경 사항 적용
    TxBaseHelper::QueryExtension.apply_patch
  end
end
```

==== 옵션 설명

* `name`: 컬럼 이름 (Symbol)
* `options`:
  * `:class`: 사용할 컬럼 클래스 (Class). 기본값은 `QueryColumn`.
  * `:sortable`: 정렬 기준 (String 또는 Lambda). DB 컬럼명 등을 지정.
  * `:groupable`: 그룹화 가능 여부 (Boolean 또는 String). 기본값 `true`.
  * `:default_order`: 기본 정렬 순서 ('asc' 또는 'desc'). 기본값 `'desc'`.
  * `:type`: 필터 타입 (Symbol). `:date`, `:date_past`, `:string`, `:list`, `:list_optional`, `:list_status`, `:list_subprojects` 등. `nil`이면 필터는 생성하지 않고 컬럼만 추가.
  * `:filter_name`: 필터 이름을 컬럼 이름과 다르게 설정하고 싶을 때 사용 (String).
  * `:filter_options`: `add_available_filter`에 전달할 추가 옵션 (Hash). `:values` 등을 설정할 때 사용.
