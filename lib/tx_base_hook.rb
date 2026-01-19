class TxBaseHook < Redmine::Hook::ViewListener
  def view_layouts_base_body_top(context = {})
    return '' unless User.current.admin?
    
    begin
      disk_usage = TxBaseHelper.check_disk_usage
      
      if disk_usage && disk_usage[:percent] >= 95
        render_disk_warning(context, disk_usage)
      else
        ''
      end
    rescue => e
      Rails.logger.error "Disk usage check failed: #{e.message}"
      ''
    end
  end
  
  private
  
  def render_disk_warning(context, disk_usage)
    html = <<-HTML
      <div class="disk-warning-banner" style="background-color: #d9534f; color: white; padding: 15px; margin: 0; text-align: center; border-bottom: 3px solid #c9302c; font-size: 14px; font-weight: bold;">
        <span style="font-size: 18px; margin-right: 10px;">⚠️</span>
        디스크 용량 경고: #{disk_usage[:mount]} 파티션 사용률이 #{disk_usage[:percent]}%입니다. 
        (사용중: #{disk_usage[:used]}, 전체: #{disk_usage[:total]}, 여유: #{disk_usage[:available]})
        <span style="font-size: 18px; margin-left: 10px;">⚠️</span>
      </div>
    HTML
    html.html_safe
  end
end

