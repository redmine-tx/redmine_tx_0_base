#!/usr/bin/env ruby
# Holiday API 사용 예제

# Rails 콘솔에서 실행:
# load 'plugins/redmine_tx_0_base/doc/holiday_api_example.rb'

puts "=" * 80
puts "Holiday API 사용 예제"
puts "=" * 80
puts ""

# 1. 기능 사용 가능 여부 확인
puts "1. 기능 사용 가능 여부 확인"
if TxBaseHelper::HolidayApi.available?
  puts "   ✓ Holiday API 사용 가능"
else
  puts "   ✗ Holiday API 사용 불가 (redmine_tx_more_calendar 플러그인 필요)"
  exit
end
puts ""

# 2. 오늘이 공휴일인지 확인
puts "2. 오늘 날짜 확인"
today = Date.today
is_holiday = TxBaseHelper::HolidayApi.holiday?(today)
puts "   오늘 날짜: #{today}"
puts "   공휴일 여부: #{is_holiday ? '✓ 공휴일' : '✗ 평일'}"
puts ""

# 3. 이번 달 공휴일 목록
puts "3. 이번 달 공휴일 목록"
start_date = Date.today.beginning_of_month
end_date = Date.today.end_of_month
holidays = TxBaseHelper::HolidayApi.for_date_range(start_date, end_date)

if holidays.any?
  holidays.each do |date, info|
    puts "   #{date} (#{Date::DAYNAMES[date.wday]}): #{info[:name]}"
  end
else
  puts "   이번 달에는 공휴일이 없습니다."
end
puts ""

# 4. 올해 공휴일 전체 목록
puts "4. 올해 공휴일 전체 목록"
year_start = Date.new(Date.today.year, 1, 1)
year_end = Date.new(Date.today.year, 12, 31)
year_holidays = TxBaseHelper::HolidayApi.for_date_range(year_start, year_end)

if year_holidays.any?
  year_holidays.each do |date, info|
    day_name = %w[일 월 화 수 목 금 토][date.wday]
    puts "   #{date} (#{day_name}): #{info[:name]}"
  end
  puts "   총 #{year_holidays.size}개의 공휴일"
else
  puts "   올해 공휴일 데이터가 없습니다."
end
puts ""

# 5. 업무일 계산 예제
puts "5. 업무일 계산 예제"
def add_business_days(start_date, days)
  current_date = start_date
  business_days_added = 0

  while business_days_added < days
    current_date += 1.day
    unless current_date.saturday? || current_date.sunday? || TxBaseHelper::HolidayApi.holiday?(current_date)
      business_days_added += 1
    end
  end

  current_date
end

target_date = add_business_days(Date.today, 5)
puts "   오늘부터 5 업무일 후: #{target_date}"
puts ""

# 6. 향후 30일간 업무일 계산
puts "6. 향후 30일간 업무일 계산"
working_days = (Date.today..(Date.today + 30.days)).select do |date|
  !date.saturday? && !date.sunday? && !TxBaseHelper::HolidayApi.holiday?(date)
end
puts "   향후 30일간 업무일: #{working_days.count}일"
puts ""

# 7. 캐시 정보
puts "7. 캐시 정보"
cache_info = TxBaseHelper::HolidayApi.cache_info
puts "   캐시된 범위 수: #{cache_info[:cached_ranges_count]}"
puts "   캐시된 공휴일 수: #{cache_info[:cached_holidays_count]}"
puts "   예상 메모리 사용량: #{cache_info[:memory_usage_estimate]}"
if cache_info[:cached_ranges].any?
  puts "   캐시된 범위:"
  cache_info[:cached_ranges].each do |range|
    puts "     - #{range}"
  end
end
puts ""

# 8. 다가오는 공휴일 찾기
puts "8. 다가오는 공휴일 찾기"
next_90_days = (Date.today..(Date.today + 90.days))
upcoming_holidays = TxBaseHelper::HolidayApi.for_date_range(Date.today, Date.today + 90.days)

if upcoming_holidays.any?
  upcoming_holidays.first(5).each do |date, info|
    days_until = (date - Date.today).to_i
    day_name = %w[일 월 화 수 목 금 토][date.wday]
    if days_until == 0
      puts "   오늘: #{info[:name]}"
    elsif days_until == 1
      puts "   내일: #{info[:name]} (#{date})"
    else
      puts "   D-#{days_until}: #{info[:name]} (#{date}, #{day_name})"
    end
  end
else
  puts "   향후 90일 이내에 공휴일이 없습니다."
end
puts ""

puts "=" * 80
puts "예제 실행 완료"
puts "=" * 80
