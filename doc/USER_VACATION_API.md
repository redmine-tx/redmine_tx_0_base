# User Vacation API 사용 가이드

## 개요

`TxBaseHelper::UserVacationApi`는 사용자의 휴가 및 근무 상태 정보를 제공하는 통합 인터페이스입니다.

**현재 구현**: `user_status` 플러그인의 UserStatusHelper에 위임
**향후 계획**: 필요시 `redmine_tx_0_base` 플러그인으로 구현 이동 가능

## 의존성

- `user_status` 플러그인이 설치되어 있어야 합니다.
- 플러그인이 없으면 `NotImplementedError`가 발생합니다.

## 주요 기능

### 1. 휴가 정보 조회

#### 특정 날짜의 전체 사용자 휴가 정보
```ruby
# 오늘 휴가 정보
vacation_info = TxBaseHelper::UserVacationApi.get_vacation_info(Date.today)
# => {
#   'john' => { name: 'John Doe', status: '휴가', vacation_type: '연차', vacation_category: '휴가' },
#   'jane' => { name: 'Jane Smith', status: '오전반차', vacation_type: '반차(오전)', vacation_category: '오전반차' }
# }

# 날짜 범위
vacation_info = TxBaseHelper::UserVacationApi.get_vacation_info(Date.today..(Date.today + 7.days))
# => {
#   Date(2024-01-01) => { 'john' => { ... }, 'jane' => { ... } },
#   Date(2024-01-02) => { 'bob' => { ... } },
#   ...
# }
```

#### 특정 사용자의 휴가 여부 확인
```ruby
# User 객체로 확인
if TxBaseHelper::UserVacationApi.on_vacation?(User.current)
  puts "오늘은 휴가입니다!"
end

# 로그인 ID로 확인
if TxBaseHelper::UserVacationApi.on_vacation?('john', Date.today)
  puts "John은 오늘 휴가입니다!"
end
```

### 2. 근무 상태 조회

#### 특정 사용자의 근무 상태
```ruby
status = TxBaseHelper::UserVacationApi.work_status(User.current)
# => '근무중', '휴가', '출근전', '퇴근', '오전반차', '오후반차', '조퇴', '포괄임금' 등

case status
when '근무중'
  puts "현재 근무 중입니다"
when '휴가'
  puts "휴가입니다"
when '오전반차', '오후반차'
  puts "반차입니다"
end
```

#### 반차 여부 확인
```ruby
half_day = TxBaseHelper::UserVacationApi.half_day_off?(User.current)

case half_day
when :morning
  puts "오전 반차입니다"
when :afternoon
  puts "오후 반차입니다"
when nil
  puts "반차가 아닙니다"
end
```

### 3. 휴가자/근무자 목록 조회

#### 오늘 휴가자 목록
```ruby
# 모든 휴가자 (휴가, 휴직, 병가, 반차 포함)
vacationers = TxBaseHelper::UserVacationApi.users_on_vacation(Date.today)
# => [
#   { login: 'john', name: 'John Doe', status: '휴가', vacation_type: '연차' },
#   { login: 'jane', name: 'Jane Smith', status: '오전반차', vacation_type: '반차(오전)' }
# ]

vacationers.each do |user|
  puts "#{user[:name]}: #{user[:status]}"
end
```

#### 전체 휴가자만 조회 (반차 제외)
```ruby
full_day_vacationers = TxBaseHelper::UserVacationApi.users_on_vacation(
  Date.today,
  status_filter: '휴가'
)
```

#### 반차자 조회
```ruby
half_day_users = TxBaseHelper::UserVacationApi.users_on_vacation(
  Date.today,
  status_filter: ['오전반차', '오후반차']
)
```

#### 근무자 목록
```ruby
workers = TxBaseHelper::UserVacationApi.users_working(Date.today)
# => [
#   { login: 'bob', name: 'Bob Wilson', status: '근무중' },
#   { login: 'alice', name: 'Alice Brown', status: '포괄임금' }
# ]
```

### 4. 휴가 캘린더

```ruby
# 이번 주 휴가 현황
calendar = TxBaseHelper::UserVacationApi.vacation_calendar(
  Date.today.beginning_of_week,
  Date.today.end_of_week
)

# => {
#   Date(2024-01-01) => { 'john' => '휴가', 'jane' => '오전반차' },
#   Date(2024-01-02) => { 'john' => '휴가' },
#   Date(2024-01-03) => {},
#   ...
# }

# 캘린더 형식으로 출력
calendar.each do |date, users|
  puts "#{date} (#{Date::DAYNAMES[date.wday]})"
  if users.any?
    users.each do |login, status|
      puts "  - #{login}: #{status}"
    end
  else
    puts "  (휴가자 없음)"
  end
end
```

### 5. 캐시 관리

```ruby
# 기능 사용 가능 여부 확인
if TxBaseHelper::UserVacationApi.available?
  # API 사용
else
  # 대체 로직
end

# 강제 갱신 (캐시 무시)
fresh_data = TxBaseHelper::UserVacationApi.refresh!(Date.today)
```

## 실제 사용 예제

### 간트 차트에서 휴가 표시

```ruby
# app/views/milestone/_gantt_chart.html.erb
vacation_info = if TxBaseHelper::UserVacationApi.available?
                  TxBaseHelper::UserVacationApi.get_vacation_info(start_date..end_date)
                else
                  {}
                end

# 날짜별로 휴가자 표시
(start_date..end_date).each do |date|
  day_vacations = vacation_info[date] || {}

  # 해당 날짜에 휴가인 사용자 강조
  if day_vacations[user.login]
    vacation = day_vacations[user.login]

    css_class = case vacation[:status]
                when '휴가', '휴직', '병가'
                  'full-day-vacation'
                when '오전반차'
                  'morning-half-day'
                when '오후반차'
                  'afternoon-half-day'
                end

    # 휴가 표시 렌더링
  end
end
```

### 업무일 계산 (공휴일 + 개인 휴가 고려)

```ruby
def calculate_working_days(user, start_date, days_count)
  current_date = start_date
  working_days = 0

  while working_days < days_count
    # 주말 체크
    unless current_date.saturday? || current_date.sunday?
      # 공휴일 체크
      unless TxBaseHelper::HolidayApi.holiday?(current_date)
        # 개인 휴가 체크
        unless TxBaseHelper::UserVacationApi.on_vacation?(user, current_date)
          working_days += 1
        end
      end
    end

    current_date += 1.day
  end

  current_date
end

deadline = calculate_working_days(User.current, Date.today, 10)
puts "#{User.current.name}님의 10 업무일 후: #{deadline}"
```

### 팀 현황 대시보드

```ruby
def team_status_summary(date = Date.today)
  return unless TxBaseHelper::UserVacationApi.available?

  vacationers = TxBaseHelper::UserVacationApi.users_on_vacation(date)
  workers = TxBaseHelper::UserVacationApi.users_working(date)

  {
    total_vacationers: vacationers.count,
    full_day_off: vacationers.count { |u| u[:status] == '휴가' },
    morning_half: vacationers.count { |u| u[:status] == '오전반차' },
    afternoon_half: vacationers.count { |u| u[:status] == '오후반차' },
    working: workers.count
  }
end

summary = team_status_summary(Date.today)
puts "오늘 근무 현황:"
puts "  근무자: #{summary[:working]}명"
puts "  휴가자: #{summary[:total_vacationers]}명"
puts "    - 전일 휴가: #{summary[:full_day_off]}명"
puts "    - 오전 반차: #{summary[:morning_half]}명"
puts "    - 오후 반차: #{summary[:afternoon_half]}명"
```

### 회의 가능 시간 체크

```ruby
def can_attend_meeting?(user, meeting_date, meeting_hour)
  return true unless TxBaseHelper::UserVacationApi.available?

  half_day = TxBaseHelper::UserVacationApi.half_day_off?(user, meeting_date)

  case half_day
  when :morning
    meeting_hour >= 13  # 오전 반차는 오후 1시 이후 가능
  when :afternoon
    meeting_hour < 13   # 오후 반차는 오전만 가능
  when nil
    !TxBaseHelper::UserVacationApi.on_vacation?(user, meeting_date)
  end
end

meeting_date = Date.new(2024, 1, 15)
meeting_time = 14  # 오후 2시

if can_attend_meeting?(User.current, meeting_date, meeting_time)
  puts "회의 참석 가능합니다"
else
  puts "해당 시간에 참석이 어렵습니다"
end
```

## 근무 상태 종류

API에서 반환하는 주요 상태값:

- **'근무중'**: 현재 근무 중
- **'출근전'**: 아직 출근하지 않음
- **'퇴근'**: 퇴근 완료
- **'휴가'**: 전일 휴가
- **'오전반차'**: 오전 반차
- **'오후반차'**: 오후 반차
- **'조퇴'**: 조퇴
- **'휴직'**: 장기 휴직
- **'병가'**: 병가
- **'포괄임금'**: 포괄임금제 (임원 등)

## 성능 최적화

User Vacation API는 다음과 같은 캐싱 전략을 사용합니다:

1. **Redis 캐시**: 외부 API 조회 결과를 캐시
2. **시간별 캐시 만료**:
   - 오늘: 10분
   - 과거/미래: 1일
3. **강제 갱신**: `refresh!` 메소드로 캐시 무시 가능

```ruby
# 캐시된 데이터 사용 (빠름)
vacation_info = TxBaseHelper::UserVacationApi.get_vacation_info(Date.today)

# 강제 갱신 (느림, 최신 데이터 필요 시)
vacation_info = TxBaseHelper::UserVacationApi.refresh!(Date.today)

# 또는
vacation_info = TxBaseHelper::UserVacationApi.get_vacation_info(Date.today, force: true)
```

## 에러 처리

```ruby
begin
  vacation_info = TxBaseHelper::UserVacationApi.get_vacation_info(Date.today)
rescue NotImplementedError => e
  # user_status 플러그인이 설치되지 않음
  Rails.logger.error "User Vacation API not available: #{e.message}"
  vacation_info = {}
end

# 또는 available? 체크
if TxBaseHelper::UserVacationApi.available?
  vacation_info = TxBaseHelper::UserVacationApi.get_vacation_info(Date.today)
else
  vacation_info = {}
end
```

## 외부 시스템 연동

user_status 플러그인은 스마일게이트 EHR 시스템과 연동하여 휴가 정보를 가져옵니다:

- API: `https://mis-kong.smilegate.net/if/tlm/v1/supercreative/work-status/attendance`
- 인증: API Key 방식
- 갱신: 10분마다 자동 갱신 (hook 방식)

## 참고

- 개발 환경에서는 항상 빈 결과를 반환합니다. (`Rails.env.development?` 체크)
- 실제 데이터는 프로덕션 환경에서만 조회됩니다.
- 캐시 키는 API URL과 날짜를 조합하여 생성됩니다.
