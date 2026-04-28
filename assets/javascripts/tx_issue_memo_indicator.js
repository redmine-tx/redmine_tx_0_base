(function($) {
  var refreshTimer = null;
  var requestInFlight = false;
  var refreshQueued = false;
  var requestsDisabled = false;
  var lastLoadedKey = null;
  var memoCache = {};
  var memoTooltip = null;

  function memoConfig() {
    return window.txIssueMemoIndicatorConfig || {};
  }

  function memoEnabled() {
    var config = memoConfig();
    return !!(config.enabled && config.lookupUrl);
  }

  function findContextMenuIssues(root) {
    var $root = $(root || document);
    return $root.find('.hascontextmenu').add($root.filter('.hascontextmenu'));
  }

  function looksLikeIssueElement(element) {
    var className = element.className || '';
    return /(?:^|\s)issue(?:\s|$)/.test(className) ||
      !!element.querySelector('[data-issue-tooltip], a.issue, a[href*="/issues/"]');
  }

  function extractIssueId(element) {
    var idMatch = (element.id || '').match(/^issue-(\d+)$/);
    if (idMatch) {
      return parseInt(idMatch[1], 10);
    }

    var classMatch = (element.className || '').match(/(?:^|\s)issue-(\d+)(?:\s|$)/);
    if (classMatch) {
      return parseInt(classMatch[1], 10);
    }

    if (!looksLikeIssueElement(element)) {
      return null;
    }

    var checkbox = element.querySelector('input[type="checkbox"][name="ids[]"][value]');
    if (checkbox && /^\d+$/.test(checkbox.value)) {
      return parseInt(checkbox.value, 10);
    }

    return null;
  }

  function findIssueAnchor($element) {
    var $anchors = $element.find('a').filter(function() {
      var $anchor = $(this);
      if ($anchor.hasClass('icon-only') || $anchor.hasClass('icon') || $anchor.hasClass('submenu')) {
        return false;
      }

      var href = this.getAttribute('href') || '';
      return $anchor.hasClass('issue') || /\/issues\/\d+/.test(href);
    });

    return $anchors.last()[0] || null;
  }

  function findIndicatorHost(element) {
    var $element = $(element);
    var $host = $element.find('.issue-subject-link').first();
    if ($host.length) {
      var subjectAnchor = findIssueAnchor($host);
      return subjectAnchor ? { element: subjectAnchor, insertAfter: true } : { element: $host[0], insertAfter: false };
    }

    $host = $element.find('td.subject').first();
    if ($host.length) {
      var subjectCellAnchor = findIssueAnchor($host);
      return subjectCellAnchor ? { element: subjectCellAnchor, insertAfter: true } : { element: $host[0], insertAfter: false };
    }

    $host = $element.find('.subject').first();
    if ($host.length) {
      var subjectContainerAnchor = findIssueAnchor($host);
      return subjectContainerAnchor ? { element: subjectContainerAnchor, insertAfter: true } : { element: $host[0], insertAfter: false };
    }

    if ($element.is('.issue-subject-link, td.subject, .subject, .task-name')) {
      var directAnchor = findIssueAnchor($element);
      return directAnchor ? { element: directAnchor, insertAfter: true } : { element: element, insertAfter: false };
    }

    var anchor = findIssueAnchor($element);
    if (anchor) {
      return { element: anchor, insertAfter: true };
    }

    return { element: element, insertAfter: false };
  }

  function normalizeMemoEntry(entry) {
    var normalized = {
      value: '',
      authorName: '',
      updatedOn: ''
    };

    if (!entry) {
      return normalized;
    }

    if (typeof entry === 'object') {
      normalized.value = entry.value || entry.memo || '';
      if (entry.author && entry.author.name) {
        normalized.authorName = entry.author.name;
      } else {
        normalized.authorName = entry.author_name || entry.authorName || '';
      }
      normalized.updatedOn = entry.updated_on || entry.updatedOn || '';
    } else {
      normalized.value = entry;
    }

    normalized.value = normalized.value == null ? '' : String(normalized.value);
    normalized.authorName = normalized.authorName == null ? '' : String(normalized.authorName);
    normalized.updatedOn = normalized.updatedOn == null ? '' : String(normalized.updatedOn);
    return normalized;
  }

  function normalizeMemoElement(target) {
    return {
      value: target.getAttribute('data-tx-memo') || '',
      authorName: target.getAttribute('data-tx-memo-author-name') || '',
      updatedOn: target.getAttribute('data-tx-memo-updated-on') || ''
    };
  }

  function memoAriaLabel(memoData) {
    var meta = memoMetaText(memoData);
    if (meta) {
      return meta + '\n' + memoData.value;
    }

    return memoData.value;
  }

  function formatMemoUpdatedOn(value) {
    if (!value) {
      return '';
    }

    var date = new Date(value);
    if (isNaN(date.getTime())) {
      return value;
    }

    function pad(number) {
      return number < 10 ? '0' + number : String(number);
    }

    return date.getFullYear() + '-' +
      pad(date.getMonth() + 1) + '-' +
      pad(date.getDate()) + ' ' +
      pad(date.getHours()) + ':' +
      pad(date.getMinutes());
  }

  function memoMetaText(memoData) {
    var parts = [];
    var updatedOn = formatMemoUpdatedOn(memoData.updatedOn);

    if (memoData.authorName) {
      parts.push('작성자: ' + memoData.authorName);
    }
    if (updatedOn) {
      parts.push('수정: ' + updatedOn);
    }

    return parts.join(' · ');
  }

  function setIndicatorMemoData(indicator, memoEntry) {
    var memoData = normalizeMemoEntry(memoEntry);
    indicator.setAttribute('data-tx-memo', memoData.value);
    indicator.setAttribute('data-tx-memo-author-name', memoData.authorName);
    indicator.setAttribute('data-tx-memo-updated-on', memoData.updatedOn);
    indicator.setAttribute('aria-label', memoAriaLabel(memoData));
    return memoData;
  }

  function buildIndicator(issueId, memoEntry) {
    var indicator = document.createElement('span');
    indicator.className = 'tx-issue-memo-indicator tx-issue-no-tooltip';
    indicator.setAttribute('data-issue-id', issueId);
    indicator.setAttribute('role', 'note');
    indicator.setAttribute('tabindex', '0');
    indicator.textContent = '📝';
    setIndicatorMemoData(indicator, memoEntry);
    return indicator;
  }

  function memoTooltipElement() {
    if (memoTooltip) {
      return memoTooltip;
    }

    memoTooltip = document.createElement('div');
    memoTooltip.className = 'tx-memo-tooltip';
    memoTooltip.style.display = 'none';
    memoTooltip.setAttribute('aria-hidden', 'true');
    document.body.appendChild(memoTooltip);
    return memoTooltip;
  }

  function hideIssueTooltip() {
    if (typeof window.tooltipTimer !== 'undefined') {
      clearTimeout(window.tooltipTimer);
    }
    if (typeof window.hideTimer !== 'undefined') {
      clearTimeout(window.hideTimer);
    }
    if (window.tooltip && typeof window.tooltip.css === 'function') {
      window.tooltip.css('display', 'none');
    }
  }

  function positionMemoTooltip(target, tooltip) {
    var rect = target.getBoundingClientRect();
    var scrollLeft = window.pageXOffset || document.documentElement.scrollLeft || 0;
    var scrollTop = window.pageYOffset || document.documentElement.scrollTop || 0;
    var left = scrollLeft + rect.left - 8;
    var top = scrollTop + rect.bottom + 10;
    var viewportRight = scrollLeft + window.innerWidth - 12;
    var viewportBottom = scrollTop + window.innerHeight - 12;

    if (left + tooltip.offsetWidth > viewportRight) {
      left = viewportRight - tooltip.offsetWidth;
    }
    if (left < scrollLeft + 12) {
      left = scrollLeft + 12;
    }
    if (top + tooltip.offsetHeight > viewportBottom) {
      top = scrollTop + rect.top - tooltip.offsetHeight - 10;
    }
    if (top < scrollTop + 12) {
      top = scrollTop + 12;
    }

    tooltip.style.left = left + 'px';
    tooltip.style.top = top + 'px';
  }

  function showMemoTooltip(target) {
    var memoData = normalizeMemoElement(target);
    if (!memoData.value) {
      return;
    }

    hideIssueTooltip();

    var tooltip = memoTooltipElement();
    tooltip.textContent = '';

    var body = document.createElement('div');
    body.className = 'tx-memo-tooltip-body';
    body.textContent = memoData.value;
    tooltip.appendChild(body);

    var metaText = memoMetaText(memoData);
    if (metaText) {
      var meta = document.createElement('div');
      meta.className = 'tx-memo-tooltip-meta';
      meta.textContent = metaText;
      tooltip.appendChild(meta);
    }

    tooltip.style.display = 'block';
    tooltip.style.visibility = 'hidden';
    positionMemoTooltip(target, tooltip);
    tooltip.style.visibility = 'visible';
    tooltip.setAttribute('aria-hidden', 'false');
  }

  function hideMemoTooltip() {
    if (!memoTooltip) {
      return;
    }

    memoTooltip.style.display = 'none';
    memoTooltip.style.visibility = 'hidden';
    memoTooltip.setAttribute('aria-hidden', 'true');
  }

  function upsertIndicator(element, issueId, memoEntry) {
    var selector = '.tx-issue-memo-indicator[data-issue-id="' + issueId + '"]';
    var indicator = element.querySelector(selector);
    var memoData = normalizeMemoEntry(memoEntry);

    if (!memoData.value) {
      if (indicator) {
        indicator.remove();
      }
      return;
    }

    if (!indicator) {
      var host = findIndicatorHost(element);
      indicator = buildIndicator(issueId, memoData);

      if (host.insertAfter) {
        host.element.insertAdjacentElement('afterend', indicator);
      } else {
        host.element.appendChild(indicator);
      }
    } else {
      setIndicatorMemoData(indicator, memoData);
    }
  }

  function applyMemoMap(memoMap) {
    findContextMenuIssues(document).each(function() {
      var issueId = extractIssueId(this);
      if (!issueId) {
        return;
      }

      upsertIndicator(this, issueId, memoMap[String(issueId)] || '');
    });
  }

  function currentIssueIds() {
    var issueIds = [];

    findContextMenuIssues(document).each(function() {
      var issueId = extractIssueId(this);
      if (issueId && $.inArray(issueId, issueIds) === -1) {
        issueIds.push(issueId);
      }
    });

    return issueIds.sort(function(left, right) {
      return left - right;
    });
  }

  function refreshIndicators() {
    if (requestsDisabled) {
      return;
    }

    if (!memoEnabled()) {
      memoCache = {};
      lastLoadedKey = null;
      applyMemoMap({});
      return;
    }

    var issueIds = currentIssueIds();
    var issueKey = issueIds.join(',');

    if (!issueIds.length) {
      memoCache = {};
      lastLoadedKey = null;
      applyMemoMap({});
      return;
    }

    if (issueKey === lastLoadedKey) {
      applyMemoMap(memoCache);
      return;
    }

    if (requestInFlight) {
      refreshQueued = true;
      return;
    }

    requestInFlight = true;

    $.ajax({
      url: memoConfig().lookupUrl,
      dataType: 'json',
      data: { ids: issueIds }
    }).done(function(response) {
      memoCache = (response && (response.issue_memo_details || response.issue_memos)) || {};
      lastLoadedKey = issueKey;
      applyMemoMap(memoCache);
    }).fail(function(xhr) {
      if (xhr && (xhr.status === 401 || xhr.status === 403)) {
        requestsDisabled = true;
      }
    }).always(function() {
      requestInFlight = false;

      if (refreshQueued) {
        refreshQueued = false;
        scheduleRefresh();
      }
    });
  }

  function scheduleRefresh() {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(refreshIndicators, 50);
  }

  window.TxIssueMemoIndicator = {
    refresh: scheduleRefresh,
    setMemo: function(issueId, memo) {
      var normalizedId = parseInt(issueId, 10);
      if (!normalizedId) {
        return;
      }

      lastLoadedKey = currentIssueIds().join(',');
      var memoData = normalizeMemoEntry(memo);
      if (memoData.value) {
        memoCache[String(normalizedId)] = memo;
      } else {
        delete memoCache[String(normalizedId)];
      }

      findContextMenuIssues(document).each(function() {
        if (extractIssueId(this) === normalizedId) {
          upsertIndicator(this, normalizedId, memoData);
        }
      });
    }
  };

  $(scheduleRefresh);
  $(document).ajaxComplete(function(_event, _xhr, settings) {
    if (settings && settings.url && settings.url.indexOf(memoConfig().lookupUrl) === 0) {
      return;
    }

    scheduleRefresh();
  });
  $(document)
    .on('mouseenter focus', '.tx-issue-memo-indicator', function() {
      showMemoTooltip(this);
    })
    .on('mouseleave blur', '.tx-issue-memo-indicator', function() {
      hideMemoTooltip();
    });
  $(window).on('scroll resize', hideMemoTooltip);
})(jQuery);
