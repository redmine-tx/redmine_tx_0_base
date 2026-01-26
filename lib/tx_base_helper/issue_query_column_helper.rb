module TxBaseHelper
  module IssueQueryColumnHelper
    # 일반 컬럼을 IssueQuery에 추가하는 헬퍼 메소드
    # @param column_name [Symbol] 컬럼명
    # @param options [Hash] 옵션
    #   - :column_class [Class] QueryColumn 또는 TimestampQueryColumn (기본: QueryColumn)
    #   - :sortable [String, Proc] 정렬 설정 (기본: "#{Issue.table_name}.컬럼명")
    #   - :default_order [String] 기본 정렬 순서 (기본: 'desc')
    #   - :groupable [Boolean] 그룹화 가능 여부 (기본: true)
    def add_issue_column(column_name, options = {})
      column_class = options.delete(:column_class) || QueryColumn
      sortable = options[:sortable] || "#{Issue.table_name}.#{column_name}"
      default_order = options[:default_order] || 'desc'
      groupable = options.key?(:groupable) ? options[:groupable] : true

      column_options = {
        sortable: sortable,
        default_order: default_order,
        groupable: groupable
      }.merge(options.except(:column_class, :sortable, :default_order, :groupable))

      add_available_column column_class.new(column_name, column_options)
    end

    # 타임스탬프 컬럼을 IssueQuery에 추가하는 헬퍼 메소드
    # @param column_name [Symbol] 컬럼명
    # @param options [Hash] 옵션 (add_issue_column과 동일)
    def add_issue_timestamp_column(column_name, options = {})
      add_issue_column(column_name, options.merge(column_class: TimestampQueryColumn))
    end

    # 가상 컬럼을 IssueQuery에 추가하는 헬퍼 메소드 (DB에 없는 컬럼)
    # @param column_name [Symbol] 컬럼명
    # @param options [Hash] 옵션
    #   - :value_proc [Proc] 값을 계산하는 람다/Proc (필수)
    #   - :caption [Symbol, String] 컬럼 캡션 (기본: :field_컬럼명)
    #   - :sortable [String, Boolean] 정렬 설정 (기본: 컬럼명 문자열)
    #   - :default_order [String] 기본 정렬 순서 (기본: 'desc')
    #   - :groupable [Boolean] 그룹화 가능 여부 (기본: true)
    def add_issue_virtual_column(column_name, options = {})
      value_proc = options.delete(:value_proc)
      raise ArgumentError, "value_proc is required for virtual columns" unless value_proc

      caption = options[:caption] || "field_#{column_name}".to_sym
      sortable = options.key?(:sortable) ? options[:sortable] : column_name.to_s
      default_order = options[:default_order] || 'desc'
      groupable = options.key?(:groupable) ? options[:groupable] : true

      column_options = {
        caption: caption,
        sortable: sortable,
        default_order: default_order,
        groupable: groupable
      }.merge(options.except(:value_proc, :caption, :sortable, :default_order, :groupable))

      IssueQuery.available_columns << TxBaseHelper::CustomQueryColumn.new(
        column_name,
        value_proc,
        column_options
      )
    end

    # 날짜 필터를 IssueQuery에 추가하는 헬퍼 메소드
    # @param filter_name [String] 필터명
    # @param options [Hash] 필터 옵션
    #   - :type [Symbol] 필터 타입 (기본: :date_past)
    def add_issue_date_filter(filter_name, options = {})
      filter_type = options[:type] || :date_past
      add_available_filter filter_name.to_s, { type: filter_type }.merge(options.except(:type))
    end

    # 커스텀 필터를 IssueQuery에 추가하는 헬퍼 메소드
    # @param filter_name [String] 필터명
    # @param options [Hash] 필터 옵션 (add_available_filter와 동일)
    def add_issue_filter(filter_name, options = {})
      add_available_filter filter_name.to_s, options
    end
  end

  # 가상 컬럼을 위한 커스텀 QueryColumn 클래스
  class CustomQueryColumn < QueryColumn
    attr_reader :value_proc

    def initialize(name, value_proc, options={})
      @value_proc = value_proc
      super(name, options)
    end

    # 컬럼의 값을 계산
    def value(issue)
      @value_proc.call(issue)
    end
  end
end
