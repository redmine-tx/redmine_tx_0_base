module TxBaseHelper
  # IssueQuery 컬럼/필터 등록을 위한 DSL
  class IssueQueryDsl
    def initialize
      @columns = []
      @filters = []
      @virtual_columns = []
    end

    # 일반 컬럼 등록
    def column(name, options = {})
      filter_options = options.delete(:filter)
      @columns << { name: name, type: :normal, options: options }

      if filter_options
        if filter_options == :date_past
          @filters << { name: name, type: :date_past }
        elsif filter_options.is_a?(Hash)
          @filters << { name: name }.merge(filter_options)
        end
      end
    end

    # 타임스탬프 컬럼 등록
    def timestamp_column(name, options = {})
      filter_options = options.delete(:filter)
      @columns << { name: name, type: :timestamp, options: options }

      if filter_options
        if filter_options == :date_past
          @filters << { name: name, type: :date_past }
        elsif filter_options.is_a?(Hash)
          @filters << { name: name }.merge(filter_options)
        end
      end
    end

    # 가상 컬럼 등록 (DB에 없는 컬럼)
    def virtual_column(name, options = {})
      value_proc = options.delete(:value)
      raise ArgumentError, "value proc is required for virtual columns" unless value_proc

      filter_options = options.delete(:filter)
      @virtual_columns << {
        name: name,
        value_proc: value_proc,
        options: options,
        filter: filter_options
      }

      if filter_options
        @filters << {
          name: name,
          type: filter_options.is_a?(Symbol) ? filter_options : filter_options[:type],
          virtual: true,
          value_proc: value_proc,
          filter_options: filter_options.is_a?(Hash) ? filter_options : {}
        }
      end
    end

    # 사용자(User) 타입 컬럼 등록
    # @param name [Symbol] 컬럼명 (예: :end_date_delayed_by)
    # @param options [Hash] 옵션
    #   - :association [Symbol] belongs_to 연관명 (기본: name)
    #   - :foreign_key [String, Symbol] issues 테이블의 사용자 FK (기본: "#{association}_id")
    #   - :join_alias [String, Symbol] 정렬용 users 테이블 alias (기본: association)
    #   - :filter_name [String, Symbol] 필터명 (기본: "#{name}_id")
    #   - :filter [Boolean] 필터 추가 여부 (기본: true)
    def user_column(name, options = {})
      association = options.delete(:association) || name
      foreign_key = (options.delete(:foreign_key) || "#{association}_id").to_s
      join_alias = (options.delete(:join_alias) || association).to_s
      filter_name = (options.delete(:filter_name) || "#{name}_id").to_s
      add_filter = options.delete(:filter) != false
      validate_sql_identifier!(:foreign_key, foreign_key)
      validate_sql_identifier!(:join_alias, join_alias)
      validate_unique_user_join_alias!(join_alias, foreign_key)

      @columns << {
        name: name,
        type: :user,
        association: association,
        foreign_key: foreign_key,
        join_alias: join_alias.to_s,
        options: options
      }

      if add_filter
        @filters << {
          name: filter_name,
          type: :list_optional,
          user_filter: true,
          association: association
        }
      end
    end

    # 독립적인 필터 등록 (컬럼 없이 필터만)
    def filter(name, options = {})
      @filters << { name: name }.merge(options)
    end

    def apply!
      patch_module = create_patch_module

      unless IssueQuery.included_modules.include?(patch_module)
        IssueQuery.send(:include, patch_module)
      end
    end

    private

    def validate_sql_identifier!(option_name, value)
      return if value.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)

      raise ArgumentError, "#{option_name} must be a simple SQL identifier"
    end

    def validate_unique_user_join_alias!(join_alias, foreign_key)
      existing = @columns.find do |col|
        col[:type] == :user && col[:join_alias] == join_alias
      end
      return if existing.nil? || existing[:foreign_key] == foreign_key

      raise ArgumentError, "join_alias #{join_alias.inspect} is already used with a different foreign_key"
    end

    def create_patch_module
      columns = @columns
      filters = @filters
      virtual_columns = @virtual_columns
      user_joins = columns.select { |col| col[:type] == :user }
      unique_suffix = "tx_dsl_#{object_id}"

      patch_module = Module.new

      if user_joins.any?
        patch_module.module_eval do
          define_method(:"joins_for_order_statement_with_#{unique_suffix}") do |order_options|
            joins = [send(:"joins_for_order_statement_without_#{unique_suffix}", order_options)]
            order_sql = order_options.to_s

            user_joins.each do |join_def|
              join_alias = join_def[:join_alias]
              next unless order_sql.match?(/(?:^|[^\w])`?#{Regexp.escape(join_alias)}`?\./)

              foreign_key = join_def[:foreign_key]
              joins <<
                "LEFT OUTER JOIN #{User.table_name} #{join_alias}" \
                  " ON #{join_alias}.id = #{queried_table_name}.#{foreign_key}"
            end

            joins.compact_blank.uniq.join(' ').presence
          end
        end
      end

      # 필터 초기화 메소드 정의 (먼저 정의해야 alias_method가 작동함)
      if filters.any?
        patch_module.module_eval do
          define_method(:"initialize_available_filters_with_#{unique_suffix}") do
            send(:"initialize_available_filters_without_#{unique_suffix}")

            filters.each do |filter_def|
              filter_name = filter_def[:name].to_s
              filter_type = filter_def[:type]

              if filter_type == :date_past
                add_issue_date_filter filter_name
              elsif filter_def[:user_filter]
                # 사용자 필터 - 활성 사용자 목록 제공
                add_available_filter filter_name, {
                  type: :list_optional,
                  values: lambda { User.active.sorted.map { |u| [u.name, u.id.to_s] } }
                }
              elsif filter_def[:virtual]
                # 가상 컬럼 필터
                filter_opts = filter_def[:filter_options].dup
                filter_opts[:type] = filter_type if filter_type
                add_issue_filter filter_name, filter_opts
              else
                # 일반 필터
                filter_opts = filter_def.except(:name, :type)
                filter_opts[:type] = filter_type if filter_type
                add_issue_filter filter_name, filter_opts
              end
            end
          end
        end

        # 가상 컬럼 필터를 위한 SQL 우회 메소드들
        virtual_filters = filters.select { |f| f[:virtual] }
        virtual_filters.each do |vfilter|
          patch_module.module_eval do
            define_method(:"sql_for_#{vfilter[:name]}_field") do |field, operator, value|
              "1=1"  # SQL 쿼리에서 제외
            end
          end
        end

        # 가상 컬럼 필터링을 위한 issues 메소드 오버라이드
        if virtual_filters.any?
          patch_module.module_eval do
            define_method(:"issues_with_#{unique_suffix}") do |options={}|
              issues = send(:"issues_without_#{unique_suffix}", options)

              virtual_filters.each do |vfilter|
                filter_name = vfilter[:name].to_s
                next unless has_filter?(filter_name)

                operator = operator_for(filter_name)
                values = values_for(filter_name)
                value_proc = vfilter[:value_proc]

                issues = issues.select do |issue|
                  field_value = value_proc.call(issue).to_s

                  case operator
                  when "~"   # contains
                    values.any? { |v| field_value.include?(v) }
                  when "!~"  # doesn't contain
                    values.none? { |v| field_value.include?(v) }
                  when "^"   # starts with
                    values.any? { |v| field_value.start_with?(v) }
                  when "$"   # ends with
                    values.any? { |v| field_value.end_with?(v) }
                  when "="   # is
                    values.any? { |v| field_value == v }
                  when "!"   # is not
                    values.none? { |v| field_value == v }
                  when "!*"  # none (empty)
                    field_value.blank?
                  when "*"   # any (not empty)
                    field_value.present?
                  else
                    true
                  end
                end
              end

              issues
            end
          end
        end
      end

      # included 훅 정의 (컬럼 추가 및 alias_method 체인 설정)
      patch_module.define_singleton_method(:included) do |base|
        base.class_eval do
          extend TxBaseHelper::IssueQueryColumnHelper
          include TxBaseHelper::IssueQueryColumnHelper

          # 일반 컬럼 추가 (이름 기반 중복 체크)
          columns.each do |col|
            col_id = col[:type] == :user ? col[:association] : col[:name]
            next if available_columns.any? { |c| c.name == col_id }

            if col[:type] == :timestamp
              add_issue_timestamp_column col[:name], col[:options]
            elsif col[:type] == :user
              # User 타입 컬럼은 일반 QueryColumn 사용 (belongs_to 관계가 User 객체 반환)
              # Redmine이 자동으로 User 객체에 link_to_user 적용
              association = col[:association]
              join_alias = col[:join_alias]
              sortable =
                if col[:options].key?(:sortable)
                  col[:options][:sortable]
                else
                  Proc.new { User.fields_for_order_statement(join_alias) }
                end
              column_options = {
                :caption => col[:options][:caption] || "field_#{col[:name]}".to_sym,
                :sortable => sortable,
                :groupable => col[:options].key?(:groupable) ? col[:options][:groupable] : sortable.present?
              }.merge(col[:options].except(:caption, :sortable, :groupable))

              add_available_column QueryColumn.new(association, column_options)
            else
              add_issue_column col[:name], col[:options]
            end
          end

          # 가상 컬럼 추가 (이름 기반 중복 체크)
          virtual_columns.each do |vcol|
            next if available_columns.any? { |c| c.name == vcol[:name] }
            add_issue_virtual_column vcol[:name], vcol[:options].merge(value_proc: vcol[:value_proc])
          end

          if user_joins.any?
            alias_method :"joins_for_order_statement_without_#{unique_suffix}", :joins_for_order_statement
            alias_method :joins_for_order_statement, :"joins_for_order_statement_with_#{unique_suffix}"
          end

          # 필터가 있으면 alias_method 체인 설정
          if filters.any?
            alias_method :"initialize_available_filters_without_#{unique_suffix}", :initialize_available_filters
            alias_method :initialize_available_filters, :"initialize_available_filters_with_#{unique_suffix}"

            # 가상 컬럼 필터가 있으면 issues 메소드도 오버라이드
            virtual_filters = filters.select { |f| f[:virtual] }
            if virtual_filters.any?
              alias_method :"issues_without_#{unique_suffix}", :issues
              alias_method :issues, :"issues_with_#{unique_suffix}"
            end
          end
        end
      end

      patch_module
    end
  end

  # DSL 진입점
  def self.register_issue_query_columns(&block)
    dsl = IssueQueryDsl.new
    dsl.instance_eval(&block)
    dsl.apply!
  end
end
