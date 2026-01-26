module TxBaseHelper
  module QueryExtension
    mattr_accessor :registered_columns
    self.registered_columns = []

    def self.register_column(name, options = {})
      unless self.registered_columns.any? { |c| c[:name] == name }
        self.registered_columns << { name: name, options: options }
      end
    end

    module IssueQueryPatch
      def self.included(base)
        base.class_eval do
          # 1. 필터 패치
          alias_method :initialize_available_filters_without_tx_base_extension, :initialize_available_filters
          alias_method :initialize_available_filters, :initialize_available_filters_with_tx_base_extension
        end

        # 2. 컬럼 추가 (included 시점에 즉시 실행)
        # 예전 코드(issue_query_patch.rb)에서 class_eval 블록 안에 add_available_column을 썼던 것과 동일한 효과
        TxBaseHelper::QueryExtension.registered_columns.each do |entry|
          name = entry[:name]
          opts = entry[:options]
          
          # 중복 체크 (혹시 모를 중복 방지)
          next if base.available_columns.any? { |c| c.name == name }

          col_class = opts[:class] || QueryColumn
          
          col_args = {}
          col_args[:sortable] = opts[:sortable] if opts.key?(:sortable)
          col_args[:groupable] = opts.key?(:groupable) ? opts[:groupable] : true
          col_args[:default_order] = opts[:default_order] if opts.key?(:default_order)
          
          column = col_class.new(name, col_args)
          base.add_available_column(column)
        end
      end

      def initialize_available_filters_with_tx_base_extension
        initialize_available_filters_without_tx_base_extension

        # 등록된 컬럼들에 대해 필터 추가
        TxBaseHelper::QueryExtension.registered_columns.each do |entry|
          name = entry[:name]
          opts = entry[:options]
          
          if opts[:type]
            filter_opts = opts[:filter_options] ? opts[:filter_options].dup : {}
            filter_opts[:type] = opts[:type]
            filter_name = opts[:filter_name] || name.to_s
            add_available_filter(filter_name, filter_opts)
          end
        end
      end
    end
    
    def self.apply_patch
      return unless ActiveRecord::Base.connection.data_source_exists?('issues') rescue false

      # 패치 모듈 include
      # 이 순간 self.included 콜백이 실행되면서 컬럼들이 추가됨
      unless IssueQuery.included_modules.include?(IssueQueryPatch)
        IssueQuery.send(:include, IssueQueryPatch)
      end
    end
  end
end
