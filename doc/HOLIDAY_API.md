# Holiday API 사용 가이드

## 개요

`TxBaseHelper::HolidayApi`는 한국 공휴일 정보를 제공하는 통합 인터페이스입니다.

**현재 구현**: `redmine_tx_more_calendar` 플러그인의 Holiday 모델에 위임
**향후 계획**: `redmine_tx_0_base` 플러그인으로 구현 이동 예정

## 의존성

- `redmine_tx_more_calendar` 플러그인이 설치되어 있어야 합니다.
- 플러그인이 없으면 `NotImplementedError`가 발생합니다.

## 사용법

### 1. 특정 날짜가 공휴일인지 확인

```ruby
# 오늘이 공휴일인지 확인
if TxBaseHelper::HolidayApi.holiday?(Date.today)
  puts "오늘은 공휴일입니다!"
end

# 특정 날짜 확인
if TxBaseHelper::HolidayApi.holiday?(Date.new(2024, 1, 1))
  puts "신정입니다!"
end
```

### 2. 날짜 범위의 공휴일 목록 조회

```ruby
# 이번 달 공휴일 조회
start_date = Date.today.beginning_of_month
end_date = Date.today.end_of_month
holidays = TxBaseHelper::HolidayApi.for_date_range(start_date, end_date)

holidays.each do |date, info|
  puts "#{date}: #{info[:name]}"
end
# 출력 예: 2024-01-01: 신정
```

### 3. 공휴일 데이터 업데이트

```ruby
# 작년, 올해, 내년 공휴일 데이터 업데이트
TxBaseHelper::HolidayApi.update!

# 특정 연도만 업데이트
new_count, total_count = TxBaseHelper::HolidayApi.sync(2024)
puts "신규 #{new_count}개, 총 #{total_count}개의 공휴일"
```

### 4. 기능 사용 가능 여부 확인

```ruby
if TxBaseHelper::HolidayApi.available?
  # 공휴일 API 사용
  is_holiday = TxBaseHelper::HolidayApi.holiday?(Date.today)
else
  # 대체 로직
  Rails.logger.warn "Holiday API not available"
end
```

### 5. 캐시 관리

```ruby
# 캐시 정보 확인
info = TxBaseHelper::HolidayApi.cache_info
puts "캐시된 공휴일 수: #{info[:cached_holidays_count]}"

# 캐시 클리어 (테스트나 메모리 관리용)
TxBaseHelper::HolidayApi.clear_cache!
```

## 실제 사용 예제

### 업무일 계산

```ruby
# 오늘부터 5 업무일 후 날짜 계산
def add_business_days(start_date, days)
  current_date = start_date
  business_days_added = 0

  while business_days_added < days
    current_date += 1.day

    # 주말이나 공휴일이 아니면 업무일로 카운트
    unless current_date.saturday? || current_date.sunday? ||
           TxBaseHelper::HolidayApi.holiday?(current_date)
      business_days_added += 1
    end
  end

  current_date
end

delivery_date = add_business_days(Date.today, 5)
puts "5 업무일 후: #{delivery_date}"
```

### 공휴일 표시

```ruby
# 캘린더에 공휴일 표시
def render_calendar_day(date)
  css_class = []
  css_class << "weekend" if date.saturday? || date.sunday?
  css_class << "holiday" if TxBaseHelper::HolidayApi.holiday?(date)

  content_tag :div, class: css_class.join(" ") do
    date.day
  end
end
```

### 공휴일 일정 제외

```ruby
# 공휴일이 아닌 날짜만 필터링
def working_days_in_range(start_date, end_date)
  (start_date..end_date).select do |date|
    !date.saturday? &&
    !date.sunday? &&
    !TxBaseHelper::HolidayApi.holiday?(date)
  end
end

working_days = working_days_in_range(Date.today, Date.today + 30.days)
puts "향후 30일간 업무일: #{working_days.count}일"
```

## 성능 최적화

Holiday API는 다음과 같은 캐싱 전략을 사용합니다:

1. **메모리 캐시**: 조회된 공휴일 데이터를 메모리에 캐시
2. **범위 병합**: 연속된 날짜 범위를 병합하여 DB 쿼리 최소화
3. **선제적 캐싱**: 요청된 범위보다 넓게 (최소 2개월) 캐시하여 향후 요청에 대비
4. **스레드 안전**: Mutex를 사용하여 멀티스레드 환경에서도 안전

```ruby
# 성능 확인
info = TxBaseHelper::HolidayApi.cache_info
puts "캐시된 범위: #{info[:cached_ranges]}"
puts "캐시된 공휴일 수: #{info[:cached_holidays_count]}"
```

## 에러 처리

```ruby
begin
  is_holiday = TxBaseHelper::HolidayApi.holiday?(Date.today)
rescue NotImplementedError => e
  # redmine_tx_more_calendar 플러그인이 설치되지 않음
  Rails.logger.error "Holiday API not available: #{e.message}"
  is_holiday = false
end
```

## 마이그레이션 계획

향후 Holiday 모델을 `redmine_tx_0_base`로 이동할 때:

1. ✅ API 인터페이스는 유지 (하위 호환성)
2. ✅ 기존 코드 수정 불필요
3. ✅ `redmine_tx_more_calendar` 플러그인은 deprecated로 표시
4. ✅ 데이터 마이그레이션 스크립트 제공

## 참고

- 공휴일 데이터 출처: [holidays-kr](https://github.com/DaeHyeoNi/holidays-kr)
- 데이터는 GitHub에서 JSON 형식으로 제공됩니다.
- 연도별로 1주일 동안 캐시됩니다. (Rails.cache)
