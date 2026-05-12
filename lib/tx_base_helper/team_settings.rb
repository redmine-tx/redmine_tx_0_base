require 'digest'
require 'json'

module TxBaseHelper
  class TeamSettings
    def initialize(raw = nil)
      @raw = raw || Setting.plugin_redmine_tx_0_base || {}
    end

    def configured?
      truthy?(value_for('organization_team_settings_enabled')) || legacy_display_group_ids.any?
    end

    def excluded_group_ids
      normalize_ids(value_for('organization_excluded_group_ids'))
    end

    def excluded_groups
      ids = excluded_group_ids
      return [] if ids.empty?

      Group.where(:id => ids).order(:name).to_a
    end

    def display_group_ids
      if truthy?(value_for('organization_team_settings_enabled'))
        Group.all.order(:name).pluck(:id) - excluded_group_ids
      else
        legacy_display_group_ids
      end
    end

    def display_groups
      ids = display_group_ids
      return [] if ids.empty?

      groups = Group.where(:id => ids).to_a
      if groupings.any?
        groups.sort_by { |group| group_sort_key(group) }
      elsif truthy?(value_for('organization_team_settings_enabled'))
        groups.sort_by(&:name)
      else
        groups.sort_by { |group| ids.index(group.id) || ids.length }
      end
    end

    def excluded_user_ids(group_id)
      by_group = value_for('organization_excluded_user_ids_by_group') || {}
      normalize_ids(hash_lookup(by_group, group_id))
    end

    def effective_users(group)
      excluded = excluded_user_ids(group.id)
      users = group.users.active.to_a
      users = users.reject { |user| excluded.include?(user.id) } if excluded.any?
      users.sort_by(&:name)
    end

    def groupings
      raw_groupings = value_for('organization_groupings') || []
      raw_groupings = raw_groupings.values if raw_groupings.is_a?(Hash)

      Array(raw_groupings).filter_map.with_index do |entry, index|
        next unless entry.is_a?(Hash)

        name = hash_lookup(entry, 'name').to_s.strip
        group_ids = normalize_ids(hash_lookup(entry, 'group_ids'))
        next if name.blank? || group_ids.empty?

        {
          :name => name,
          :group_ids => group_ids,
          :position => index
        }
      end
    end

    def room_name_for_group(group_id)
      grouping = groupings.find { |entry| entry[:group_ids].include?(group_id.to_i) }
      grouping && grouping[:name]
    end

    def groups_by_room
      display_groups.group_by { |group| room_name_for_group(group.id).presence || '미분류' }
    end

    def digest
      Digest::SHA1.hexdigest(JSON.dump({
        :enabled => configured?,
        :display_group_ids => display_group_ids,
        :excluded_group_ids => excluded_group_ids,
        :excluded_user_ids_by_group => value_for('organization_excluded_user_ids_by_group') || {},
        :groupings => groupings
      }))
    end

    private

    def group_sort_key(group)
      grouping = groupings.find { |entry| entry[:group_ids].include?(group.id) }
      grouping_position = grouping ? grouping[:position] : 9999
      [grouping_position, group.name]
    end

    def legacy_display_group_ids
      normalize_ids(value_for('organization_display_group_ids'))
    end

    def value_for(key)
      hash_lookup(@raw, key)
    end

    def hash_lookup(hash, key)
      return nil unless hash.respond_to?(:[])

      value = hash[key]
      value = hash[key.to_s] if value.nil?
      value = hash[key.to_sym] if value.nil? && key.respond_to?(:to_sym)
      value
    end

    def normalize_ids(value)
      Array(value).flatten.map { |item| item.to_s.strip }.reject(&:blank?).map(&:to_i).select(&:positive?).uniq
    end

    def truthy?(value)
      %w[1 true yes on].include?(value.to_s)
    end
  end
end
