#!/usr/bin/env ruby
# User Vacation API 사용 예제

# Rails 콘솔에서 실행:
# load 'plugins/redmine_tx_0_base/doc/user_vacation_api_example.rb'

puts "=" * 80
puts "User Vacation API 사용 예제"
puts "=" * 80
puts ""

# 1. 기능 사용 가능 여부 확인
puts "1. 기능 사용 가능 여부 확인"
if TxBaseHelper::UserVacationApi.available?
  puts "   ✓ User Vacation API 사용 가능"
else
  puts "   ✗ User Vacation API 사용 불가 (user_status 플러그인 필요)"
  exit
end
puts ""

# 2. 오늘 전체 휴가 정보 조회
puts "2. 오늘 휴가 정보"
today = Date.today
vacation_info = TxBaseHelper::UserVacationApi.get_vacation_info(today)

if vacation_info.any?
  puts "   총 #{vacation_info.size}명의 상태 정보"
  vacation_info.first(5).each do |login, info|
    puts "   - #{login} (#{info[:name]}): #{info[:status]}"
  end
  puts "   ..." if vacation_info.size > 5
else
  puts "   조회된 정보가 없습니다"
end
puts ""

# 3. 현재 사용자 상태 확인
puts "3. 현재 사용자 상태"
current_user = User.current
if current_user.logged?
  status = TxBaseHelper::UserVacationApi.work_status(current_user)
  puts "   사용자: #{current_user.name}"
  puts "   상태: #{status || '정보 없음'}"

  if TxBaseHelper::UserVacationApi.on_vacation?(current_user)
    puts "   ✓ 현재 휴가 중입니다"
  else
    half_day = TxBaseHelper::UserVacationApi.half_day_off?(current_user)
    case half_day
    when :morning
      puts "   ✓ 오전 반차입니다"
    when :afternoon
      puts "   ✓ 오후 반차입니다"
    else
      puts "   ✓ 근무일입니다"
    end
  end
else
  puts "   로그인이 필요합니다"
end
puts ""

# 4. 오늘 휴가자 목록
puts "4. 오늘 휴가자 목록"
vacationers = TxBaseHelper::UserVacationApi.users_on_vacation(today)

if vacationers.any?
  puts "   총 #{vacationers.size}명"

  # 상태별로 그룹화
  by_status = vacationers.group_by { |u| u[:status] }

  by_status.each do |status, users|
    puts "   [#{status}] #{users.size}명"
    users.first(3).each do |user|
      puts "     - #{user[:name]} (#{user[:login]})"
    end
    puts "     ..." if users.size > 3
  end
else
  puts "   오늘은 휴가자가 없습니다"
end
puts ""

# 5. 오늘 근무자 목록
puts "5. 오늘 근무자 목록"
workers = TxBaseHelper::UserVacationApi.users_working(today)

if workers.any?
  puts "   총 #{workers.size}명 근무 중"
  workers.first(5).each do |user|
    puts "   - #{user[:name]} (#{user[:login]}): #{user[:status]}"
  end
  puts "   ..." if workers.size > 5
else
  puts "   근무 중인 사용자 정보가 없습니다"
end
puts ""

# 6. 이번 주 휴가 캘린더
puts "6. 이번 주 휴가 캘린더"
week_start = Date.today.beginning_of_week
week_end = Date.today.end_of_week

puts "   기간: #{week_start} ~ #{week_end}"
calendar = TxBaseHelper::UserVacationApi.vacation_calendar(week_start, week_end)

calendar.each do |date, users|
  day_name = %w[일 월 화 수 목 금 토][date.wday]
  is_today = date == Date.today

  line = "   #{date} (#{day_name})"
  line += " ◀ 오늘" if is_today

  if users.any?
    puts line
    users.first(3).each do |login, status|
      puts "     - #{login}: #{status}"
    end
    puts "     ... 외 #{users.size - 3}명" if users.size > 3
  else
    puts "#{line}: 휴가자 없음"
  end
end
puts ""

# 7. 특정 사용자 조회
puts "7. 특정 사용자 조회"
test_user = User.active.where("login IS NOT NULL AND login != ''").first

if test_user
  puts "   대상: #{test_user.name} (#{test_user.login})"
  status = TxBaseHelper::UserVacationApi.work_status(test_user)
  puts "   상태: #{status || '정보 없음'}"

  if TxBaseHelper::UserVacationApi.on_vacation?(test_user)
    puts "   → 휴가 중"
  else
    half_day = TxBaseHelper::UserVacationApi.half_day_off?(test_user)
    case half_day
    when :morning
      puts "   → 오전 반차"
    when :afternoon
      puts "   → 오후 반차"
    else
      puts "   → 근무 가능"
    end
  end
else
  puts "   테스트할 사용자를 찾을 수 없습니다"
end
puts ""

# 8. 팀 현황 요약
puts "8. 팀 현황 요약"
all_users_count = User.active.count
working_count = workers.size
vacation_count = vacationers.count

full_day = vacationers.count { |u| u[:status] == '휴가' }
morning_half = vacationers.count { |u| u[:status] == '오전반차' }
afternoon_half = vacationers.count { |u| u[:status] == '오후반차' }

puts "   전체 사용자: #{all_users_count}명"
puts "   근무 중: #{working_count}명"
puts "   휴가: #{vacation_count}명"
puts "     - 전일 휴가: #{full_day}명"
puts "     - 오전 반차: #{morning_half}명"
puts "     - 오후 반차: #{afternoon_half}명"

if all_users_count > 0
  attendance_rate = ((working_count.to_f / all_users_count) * 100).round(1)
  puts "   출근율: #{attendance_rate}%"
end
puts ""

# 9. 업무일 계산 예제
puts "9. 업무일 계산 (공휴일 + 개인 휴가 고려)"
if test_user
  puts "   대상: #{test_user.name}"

  work_days_count = 0
  current_date = Date.today
  checked_days = 0
  max_check_days = 30

  while work_days_count < 5 && checked_days < max_check_days
    checked_days += 1

    # 주말 체크
    next if current_date.saturday? || current_date.sunday?

    # 공휴일 체크
    if TxBaseHelper::HolidayApi.available?
      next if TxBaseHelper::HolidayApi.holiday?(current_date)
    end

    # 개인 휴가 체크
    next if TxBaseHelper::UserVacationApi.on_vacation?(test_user, current_date)

    work_days_count += 1
    current_date += 1.day
  end

  puts "   5 업무일 후: #{current_date - 1.day}"
else
  puts "   테스트할 사용자를 찾을 수 없습니다"
end
puts ""

# 10. 캐시 갱신 예제
puts "10. 캐시 관리"
puts "   현재 캐시된 데이터 사용 중"
puts "   강제 갱신을 원하시면 다음 명령을 실행하세요:"
puts "   TxBaseHelper::UserVacationApi.refresh!(Date.today)"
puts ""

puts "=" * 80
puts "예제 실행 완료"
puts "=" * 80
