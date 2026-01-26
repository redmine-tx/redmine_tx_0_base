module TxBaseHelper
  module Patches
    module IssueQueryPatch
      def self.included(base)
        base.class_eval do
          extend TxBaseHelper::IssueQueryColumnHelper
          include TxBaseHelper::IssueQueryColumnHelper

          # 컬럼 추가
          add_issue_column :end_date_changed_on
          add_issue_column :end_date_delayed_on

          # 필터 추가를 위해 메소드 오버라이딩 (alias_method chain 패턴)
          alias_method :initialize_available_filters_without_tx_base, :initialize_available_filters
          alias_method :initialize_available_filters, :initialize_available_filters_with_tx_base
        end
      end

      def initialize_available_filters_with_tx_base
        initialize_available_filters_without_tx_base

        # 날짜 필터 추가
        add_issue_date_filter :end_date_changed_on
        add_issue_date_filter :end_date_delayed_on
      end
    end
  end
end

unless IssueQuery.included_modules.include?(TxBaseHelper::Patches::IssueQueryPatch)
  IssueQuery.send(:include, TxBaseHelper::Patches::IssueQueryPatch)
end
