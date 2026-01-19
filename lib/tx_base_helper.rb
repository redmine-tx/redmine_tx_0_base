module TxBaseHelper
  def self.config_arr(key)
    Setting[:plugin_redmine_tx_0_base][key].to_s.tr('[]"','').split(',').map(&:to_i)
  end

  def self.config(key)
    Setting[:plugin_redmine_tx_0_base][key]
  end

  # 일감 리스트 테이블용 헬퍼 메서드들
  # 컬럼 정렬 값 반환
  def get_column_sort_value(issue, column)
    case column
    when :project then issue.project.name
    when :tracker then issue.tracker.name
    when :status then issue.status.position
    when :priority then issue.priority.position
    when :fixed_version then issue.fixed_version_sort_value
    else
      issue.send(column)
    end
  end

  # 진행률 막대 렌더링
  def progress_bar(done_ratio)
    if done_ratio == 0
      "<table class='progress' style='width: 80px;'><tr><td class='todo' style='width: 100%;'></td></tr></table>".html_safe
    elsif done_ratio == 100
      "<table class='progress' style='width: 80px;'><tr><td class='closed' style='width: 100%;'></td></tr></table>".html_safe
    else
      "<table class='progress' style='width: 80px;'><tr><td class='closed' style='width: #{done_ratio}%;'></td><td class='todo' style='width: #{100 - done_ratio}%;'></td></tr></table>".html_safe
    end
  end

  # 컬럼 값 반환
  def get_column_value(issue, column)
    case column
    when :project then link_to_project(issue.project)
    when :subject then link_to(issue.subject, issue_path(issue), class: issue.css_classes, title: issue.subject)
    when :fixed_version then issue.fixed_version_plus
    when :done_ratio then progress_bar(issue.done_ratio)
    when :updated_on then format_time(issue.updated_on)
    when :start_date then format_date(issue.start_date)
    when :due_date then format_date(issue.due_date)
    when :tip then "<font color='red'>#{issue.tip}</font>".html_safe
    when :assigned_to then issue.assigned_to_id ? link_to_principal(issue.assigned_to) : ''
    when :estimated_hours then issue.estimated_hours_plus
    when :worker then issue.worker_id ? link_to_principal(issue.worker) : ''
    else
      issue.send(column)
    end
  end

  module_function :get_column_sort_value, :progress_bar, :get_column_value
  
  # 디스크 사용량 체크 메서드
  def self.check_disk_usage
    # Redmine이 설치된 디렉토리의 파티션 체크
    redmine_path = Rails.root.to_s
    
    # df 명령어로 파티션 정보 가져오기
    df_output = `df -h #{redmine_path} 2>/dev/null`.lines
    
    return nil if df_output.size < 2
    
    # 헤더 라인 건너뛰고 데이터 라인 파싱
    data_line = df_output[1].strip.split(/\s+/)
    
    # 데이터 형식: Filesystem Size Used Avail Capacity Mounted
    # 예: /dev/disk1s1 233Gi 150Gi 80Gi 66% /
    {
      filesystem: data_line[0],
      total: data_line[1],
      used: data_line[2],
      available: data_line[3],
      percent: data_line[4].to_i,
      mount: data_line[5] || '/'
    }
  rescue => e
    Rails.logger.error "Failed to check disk usage: #{e.message}"
    nil
  end
end
