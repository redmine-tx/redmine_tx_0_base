module TxBaseHelper
  module IssuesHelperPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.send(:alias_method, :show_detail_without_tx_base, :show_detail)
      base.send(:alias_method, :show_detail, :show_detail_with_tx_base)
    end

    module InstanceMethods
      def show_detail_with_tx_base(detail, no_html=false, options={})
        if detail.property == 'attr'
          case detail.prop_key
          when 'end_date_changed_on', 'end_date_delayed_on'
            field = detail.prop_key.to_s
            label = l(("field_#{field}").to_sym)

            begin
              value = detail.value.present? ? format_time(Time.parse(detail.value.to_s)) : nil
              old_value = detail.old_value.present? ? format_time(Time.parse(detail.old_value.to_s)) : nil
            rescue ArgumentError
              value = detail.value.to_s if detail.value.present?
              old_value = detail.old_value.to_s if detail.old_value.present?
            end

            return render_tx_base_detail(detail, label, value, old_value, no_html, options)

          when 'end_date_delayed_by_id'
            field = detail.prop_key.to_s.delete_suffix('_id')
            label = l(("field_#{field}").to_sym)
            value = find_name_by_reflection(field, detail.value)
            old_value = find_name_by_reflection(field, detail.old_value)

            return render_tx_base_detail(detail, label, value, old_value, no_html, options)
          end
        end

        show_detail_without_tx_base(detail, no_html, options)
      end

      private

      def render_tx_base_detail(detail, label, value, old_value, no_html, options)
        call_hook(:helper_issues_show_detail_after_setting,
                  {:detail => detail, :label => label, :value => value, :old_value => old_value})

        value ||= ""
        old_value ||= ""

        unless no_html
          label = content_tag('strong', label)
          old_value = content_tag("i", h(old_value)) if detail.old_value.present?
          old_value = content_tag("del", old_value) if detail.old_value.present? && detail.value.blank?
          value = content_tag("i", h(value)) if value.present?
        end

        if detail.value.present?
          if detail.old_value.present?
            l(:text_journal_changed, :label => label, :old => old_value, :new => value).html_safe
          else
            l(:text_journal_set_to, :label => label, :value => value).html_safe
          end
        elsif detail.old_value.present?
          l(:text_journal_deleted, :label => label, :old => old_value).html_safe
        else
          l(:text_journal_changed_no_detail, :label => label).html_safe
        end
      end
    end
  end
end

unless IssuesHelper.included_modules.include?(TxBaseHelper::IssuesHelperPatch)
  IssuesHelper.send(:include, TxBaseHelper::IssuesHelperPatch)
end
