class TxBaseHook < Redmine::Hook::ViewListener
  PROJECTS_CACHE_KEY = 'tx_base_top_projects_links'
  PROJECTS_CACHE_DURATION = 12.hours
  
  def view_layouts_base_body_top(context = {})
    html = ''
    
    # 디스크 용량 경고 (관리자 전용)
    if User.current.admin?
      begin
        disk_usage = TxBaseHelper.check_disk_usage
        if disk_usage && disk_usage[:percent] >= 95
          html += render_disk_warning(context, disk_usage)
        end
      rescue => e
        Rails.logger.error "Disk usage check failed: #{e.message}"
      end
    end
    
    html.html_safe
  end
  
  # 이슈 페이지 action menu에 링크 복사 버튼 추가
  def view_issues_show_details_bottom(context = {})
    issue = context[:issue]
    view = context[:controller].view_context

    tracker_name = issue.tracker.name
    link_text = "#{tracker_name} ##{issue.id} #{issue.subject}"
    issue_full_url = view.issue_url(issue, only_path: false)
    icons_path = view.asset_path('icons.svg')

    # to_json으로 JS 문자열 이스케이프, </ 방지로 script 태그 안전 처리
    js_url = issue_full_url.to_json.gsub('</', '<\/')
    js_text = link_text.to_json.gsub('</', '<\/')

    <<~HTML.html_safe
      <script>
        $(function() {
          // setTimeout(0)으로 다른 플러그인 훅(간트, 일정요약 등) 이후 실행 → prepend 시 가장 왼쪽 배치
          setTimeout(function() {
            var issueUrl = #{js_url};
            var linkText = #{js_text};

            var $ctx = $('div.main div.content div.contextual').first();
            if ($ctx.length === 0) $ctx = $('#main .content div.contextual').first();

            if ($ctx.length > 0 && !$ctx.find('#tx-copy-link-btn').length) {
              var $btn = $('<a>', {
                href: '#',
                id: 'tx-copy-link-btn',
                'class': 'icon icon-copy-link',
                title: '링크 복사'
              }).append(
                '<svg class="s18 icon-svg" aria-hidden="true"><use href="#{icons_path}#icon--copy-link"></use></svg>',
                $('<span>', { 'class': 'icon-label', text: '링크복사' })
              ).on('click', function(e) {
                e.preventDefault();
                var el = this;
                var htmlContent = '<a href="' + issueUrl + '">' + $('<span>').text(linkText).html() + '</a>';

                if (navigator.clipboard && window.ClipboardItem) {
                  navigator.clipboard.write([new ClipboardItem({
                    'text/html': new Blob([htmlContent], { type: 'text/html' }),
                    'text/plain': new Blob([linkText], { type: 'text/plain' })
                  })]).then(function() {
                    showFeedback(el);
                  }).catch(function() {
                    fallbackCopy(linkText);
                    showFeedback(el);
                  });
                } else {
                  fallbackCopy(linkText);
                  showFeedback(el);
                }
              });

              $ctx.prepend(' ').prepend($btn);
            }

            function fallbackCopy(text) {
              var ta = document.createElement('textarea');
              ta.value = text;
              ta.style.position = 'fixed';
              ta.style.opacity = '0';
              document.body.appendChild(ta);
              ta.select();
              document.execCommand('copy');
              document.body.removeChild(ta);
            }

            function showFeedback(el) {
              var $label = $(el).find('.icon-label');
              $label.text('복사됨!');
              setTimeout(function() { $label.text('링크복사'); }, 1500);
            }
          }, 0);
        });
      </script>
    HTML
  end

  # 일감 상태 목록 페이지에 병합 버튼 주입
  def view_layouts_base_body_bottom(context = {})
    return '' unless User.current.admin?

    controller = context[:controller]
    return '' unless controller.is_a?(IssueStatusesController) && controller.action_name == 'index'

    statuses = IssueStatus.sorted.to_a
    merge_links = {}
    statuses.each do |s|
      url = Rails.application.routes.url_helpers.tx_status_merge_path(s)
      merge_links[s.id] = url
    end

    javascript = <<~JS
      <script>
      document.addEventListener('DOMContentLoaded', function() {
        var mergeLinks = #{merge_links.to_json};
        var rows = document.querySelectorAll('table.issue_statuses tbody tr');
        rows.forEach(function(row) {
          var deleteLink = row.querySelector('td.buttons a.icon-del, td.buttons a[data-method="delete"]');
          if (!deleteLink) return;

          var nameCell = row.querySelector('td.name a');
          if (!nameCell) return;

          var href = nameCell.getAttribute('href');
          var match = href && href.match(/issue_statuses\\/(\\d+)/);
          if (!match) return;

          var statusId = parseInt(match[1]);
          if (!mergeLinks[statusId]) return;

          var mergeLink = document.createElement('a');
          mergeLink.href = mergeLinks[statusId];
          mergeLink.className = 'icon icon-copy';
          mergeLink.title = '#{I18n.t(:button_merge)}';
          mergeLink.textContent = '#{I18n.t(:button_merge)}';

          deleteLink.parentNode.insertBefore(mergeLink, deleteLink);
          deleteLink.parentNode.insertBefore(document.createTextNode(' '), deleteLink);
        });
      });
      </script>
    JS

    javascript.html_safe
  end

  # 상단 메뉴바에 프로젝트 링크 추가
  def view_layouts_base_html_head(context = {})
    return '' unless User.current.logged?
    
    # 설정에서 기능이 꺼져 있으면 표시하지 않음
    return '' unless Setting.plugin_redmine_tx_0_base[:show_top_projects] == '1'
    
    # 12시간 캐시된 프로젝트 링크 사용
    project_links = Rails.cache.fetch(PROJECTS_CACHE_KEY, expires_in: PROJECTS_CACHE_DURATION) do
      fetch_project_links
    end
    
    return '' if project_links.blank?
    
    # 컨텍스트 메뉴 항목 파싱
    context_menu_items = parse_context_menu_items
    context_menu_json = context_menu_items.to_json
    has_context_menu = context_menu_items.any?
    
    html = <<-HTML
      <style>
        #tx-top-projects {
          float: left;
          list-style: none;
          margin-left: 15px;
          padding-left: 15px;
          border-left: 1px solid rgba(255,255,255,0.3);
        }
        #tx-top-projects .tx-project-wrapper {
          display: inline-block;
          position: relative;
        }
        #tx-top-projects .tx-project-link {
          color: rgba(255,255,255,0.65);
          padding: 0 6px;
          font-size: 10px;
          text-decoration: none;
        }
        #tx-top-projects .tx-project-link:hover {
          color: #fff;
          text-decoration: underline;
        }
        #tx-top-projects .tx-context-menu {
          display: none;
          position: absolute;
          top: 100%;
          left: 0;
          background: #fff;
          border: 1px solid #ddd;
          border-radius: 4px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.15);
          min-width: 120px;
          z-index: 9999;
          padding: 4px 0;
        }
        #tx-top-projects .tx-project-wrapper:hover .tx-context-menu {
          display: block;
        }
        #tx-top-projects .tx-context-menu a {
          display: block;
          padding: 6px 12px;
          color: #333;
          text-decoration: none;
          font-size: 11px;
          white-space: nowrap;
        }
        #tx-top-projects .tx-context-menu a:hover {
          background: #f5f5f5;
          color: #000;
        }
      </style>
      <script>
        document.addEventListener('DOMContentLoaded', function() {
          var topMenu = document.getElementById('top-menu');
          if (!topMenu) return;
          
          var contextMenuItems = #{context_menu_json};
          var hasContextMenu = #{has_context_menu};
          
          var projectsContainer = document.createElement('li');
          projectsContainer.id = 'tx-top-projects';
          
          var linksHtml = '#{project_links.gsub("'", "\\\\'")}';
          
          if (hasContextMenu && contextMenuItems.length > 0) {
            // 컨텍스트 메뉴가 있는 경우 wrapper로 감싸기
            var tempDiv = document.createElement('div');
            tempDiv.innerHTML = linksHtml;
            var links = tempDiv.querySelectorAll('a.tx-project-link');
            
            links.forEach(function(link) {
              var wrapper = document.createElement('span');
              wrapper.className = 'tx-project-wrapper';
              
              var projectUrl = link.getAttribute('href');
              var clonedLink = link.cloneNode(true);
              wrapper.appendChild(clonedLink);
              
              // 컨텍스트 메뉴 생성
              var menu = document.createElement('div');
              menu.className = 'tx-context-menu';
              contextMenuItems.forEach(function(item) {
                var menuLink = document.createElement('a');
                menuLink.href = projectUrl + item.path;
                menuLink.textContent = item.label;
                menu.appendChild(menuLink);
              });
              wrapper.appendChild(menu);
              
              projectsContainer.appendChild(wrapper);
            });
          } else {
            projectsContainer.innerHTML = linksHtml;
          }
          
          var menuUl = topMenu.querySelector(':scope > ul');
          if (menuUl) {
            menuUl.appendChild(projectsContainer);
          } else {
            topMenu.appendChild(projectsContainer);
          }
        });
      </script>
    HTML
    
    html.html_safe
  end
  
  private
  
  # 컨텍스트 메뉴 항목 파싱
  def parse_context_menu_items
    menu_text = Setting.plugin_redmine_tx_0_base[:project_context_menu].to_s.strip
    return [] if menu_text.blank?
    
    menu_text.split("\n").map do |line|
      line = line.strip
      next if line.blank?
      
      # "라벨 : /경로" 형식 파싱
      if line.include?(':')
        parts = line.split(':', 2)
        label = parts[0].strip
        path = parts[1].strip
        { label: label, path: path } if label.present? && path.present?
      end
    end.compact
  end
  
  # 프로젝트 링크 HTML 생성 (캐시용)
  def fetch_project_links
    projects = Project.active
                      .select("projects.*, (SELECT COUNT(*) FROM issues WHERE issues.project_id = projects.id) AS issues_count")
                      .order("issues_count DESC")
                      .limit(5)
    
    return '' if projects.empty?
    
    projects.map do |project|
      issues_count = project.respond_to?(:issues_count) ? project.issues_count : 0
      url = Rails.application.routes.url_helpers.project_path(project)
      "<a class=\"tx-project-link\" href=\"#{url}\" title=\"#{ERB::Util.html_escape(project.name)} (#{issues_count})\">#{ERB::Util.html_escape(project.name)}</a>"
    end.join('')
  end
  
  def render_disk_warning(context, disk_usage)
    <<-HTML
      <div class="disk-warning-banner" style="background-color: #d9534f; color: white; padding: 15px; margin: 0; text-align: center; border-bottom: 3px solid #c9302c; font-size: 14px; font-weight: bold;">
        <span style="font-size: 18px; margin-right: 10px;">⚠️</span>
        디스크 용량 경고: #{disk_usage[:mount]} 파티션 사용률이 #{disk_usage[:percent]}%입니다. 
        (사용중: #{disk_usage[:used]}, 전체: #{disk_usage[:total]}, 여유: #{disk_usage[:available]})
        <span style="font-size: 18px; margin-left: 10px;">⚠️</span>
      </div>
    HTML
  end
end

