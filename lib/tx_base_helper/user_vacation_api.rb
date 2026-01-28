module TxBaseHelper
  # 사용자 휴가/근무 상태 API 인터페이스
  # 실제 구현은 user_status 플러그인에 위임
  # 향후 구현을 이 플러그인으로 이동할 수도 있음
  class UserVacationApi
    class << self
      # 특정 날짜의 모든 사용자 휴가 정보 조회
      # @param date [Date, Range] 조회할 날짜 또는 날짜 범위
      # @param force [Boolean] 캐시 무시 여부 (기본값: false)
      # @return [Hash] { user_login => { name: '이름', status: '휴가', vacation_type: '연차', ... } }
      # @example
      #   # 오늘 휴가 정보
      #   TxBaseHelper::UserVacationApi.get_vacation_info(Date.today)
      #   # => { 'john' => { name: 'John Doe', status: '휴가', vacation_type: '연차' }, ... }
      #
      #   # 날짜 범위
      #   TxBaseHelper::UserVacationApi.get_vacation_info(Date.today..(Date.today + 7.days))
      #   # => { Date(2024-01-01) => { 'john' => { ... } }, Date(2024-01-02) => { ... } }
      def get_vacation_info(date = Date.today, force: false)
        ensure_available!
        UserStatusHelper.get_user_vacation_info(date, force)
      end

      # 특정 사용자가 특정 날짜에 휴가인지 확인
      # @param user [User, String] User 객체 또는 로그인 ID
      # @param date [Date] 확인할 날짜 (기본값: 오늘)
      # @return [Boolean] 휴가 여부
      # @example
      #   TxBaseHelper::UserVacationApi.on_vacation?(User.current)
      #   TxBaseHelper::UserVacationApi.on_vacation?('john', Date.today)
      def on_vacation?(user, date = Date.today)
        ensure_available!

        login = user.is_a?(String) ? user : user.login
        vacation_info = get_vacation_info(date)

        return false unless vacation_info[login]

        status = vacation_info[login][:status]
        ['휴가', '휴직', '병가'].include?(status)
      end

      # 특정 사용자의 근무 상태 조회
      # @param user [User, String] User 객체 또는 로그인 ID
      # @param date [Date] 확인할 날짜 (기본값: 오늘)
      # @return [String, nil] 근무 상태 ('근무중', '휴가', '출근전', '퇴근', '오전반차', '오후반차', '조퇴', '포괄임금' 등)
      # @example
      #   TxBaseHelper::UserVacationApi.work_status(User.current)
      #   # => '근무중'
      def work_status(user, date = Date.today)
        ensure_available!

        login = user.is_a?(String) ? user : user.login
        vacation_info = get_vacation_info(date)

        vacation_info.dig(login, :status)
      end

      # 특정 사용자가 반차인지 확인
      # @param user [User, String] User 객체 또는 로그인 ID
      # @param date [Date] 확인할 날짜 (기본값: 오늘)
      # @return [Symbol, nil] :morning (오전반차), :afternoon (오후반차), nil (반차 아님)
      # @example
      #   TxBaseHelper::UserVacationApi.half_day_off?(User.current)
      #   # => :morning
      def half_day_off?(user, date = Date.today)
        status = work_status(user, date)
        return nil unless status

        case status
        when '오전반차'
          :morning
        when '오후반차'
          :afternoon
        else
          nil
        end
      end

      # 특정 날짜의 휴가자 목록 조회
      # @param date [Date] 조회할 날짜 (기본값: 오늘)
      # @param status_filter [Array<String>, String, nil] 필터링할 상태 (기본값: nil, 모든 휴가 상태)
      # @return [Array<Hash>] 휴가자 정보 배열
      # @example
      #   # 모든 휴가자
      #   TxBaseHelper::UserVacationApi.users_on_vacation(Date.today)
      #   # => [{ login: 'john', name: 'John Doe', status: '휴가', vacation_type: '연차' }, ...]
      #
      #   # 전체 휴가자만
      #   TxBaseHelper::UserVacationApi.users_on_vacation(Date.today, status_filter: '휴가')
      #
      #   # 반차 포함
      #   TxBaseHelper::UserVacationApi.users_on_vacation(Date.today, status_filter: ['휴가', '오전반차', '오후반차'])
      def users_on_vacation(date = Date.today, status_filter: nil)
        ensure_available!

        vacation_info = get_vacation_info(date)

        users = vacation_info.map do |login, info|
          info.merge(login: login)
        end

        if status_filter
          filter_array = Array(status_filter)
          users.select { |user| filter_array.include?(user[:status]) }
        else
          # 기본적으로 휴가 관련 상태만 필터링
          users.select { |user| ['휴가', '휴직', '병가', '오전반차', '오후반차'].include?(user[:status]) }
        end
      end

      # 특정 날짜의 근무자 목록 조회
      # @param date [Date] 조회할 날짜 (기본값: 오늘)
      # @return [Array<Hash>] 근무자 정보 배열
      # @example
      #   TxBaseHelper::UserVacationApi.users_working(Date.today)
      #   # => [{ login: 'jane', name: 'Jane Smith', status: '근무중' }, ...]
      def users_working(date = Date.today)
        ensure_available!

        vacation_info = get_vacation_info(date)

        vacation_info.map do |login, info|
          info.merge(login: login)
        end.select { |user| ['근무중', '포괄임금'].include?(user[:status]) }
      end

      # 날짜 범위의 휴가 정보를 간단한 형식으로 변환
      # @param start_date [Date] 시작 날짜
      # @param end_date [Date] 종료 날짜
      # @return [Hash] { date => { user_login => status } }
      # @example
      #   TxBaseHelper::UserVacationApi.vacation_calendar(Date.today, Date.today + 7.days)
      #   # => {
      #   #   Date(2024-01-01) => { 'john' => '휴가', 'jane' => '오전반차' },
      #   #   Date(2024-01-02) => { 'john' => '휴가' },
      #   #   ...
      #   # }
      def vacation_calendar(start_date, end_date)
        ensure_available!

        vacation_info = get_vacation_info(start_date..end_date)

        vacation_info.transform_values do |day_info|
          day_info.transform_values { |user_info| user_info[:status] }
        end
      end

      # 사용자 휴가 API 사용 가능 여부 확인
      # @return [Boolean]
      def available?
        defined?(UserStatusHelper) && UserStatusHelper.respond_to?(:get_user_vacation_info)
      end

      # 휴가 정보 강제 갱신 (캐시 무시)
      # @param date [Date] 갱신할 날짜 (기본값: 오늘)
      # @return [Hash] 갱신된 휴가 정보
      # @example
      #   TxBaseHelper::UserVacationApi.refresh!(Date.today)
      def refresh!(date = Date.today)
        ensure_available!
        get_vacation_info(date, force: true)
      end

      private

      # UserStatusHelper가 없으면 에러 발생
      def ensure_available!
        unless available?
          raise NotImplementedError,
            "User vacation feature is not available. Please install user_status plugin."
        end
      end
    end
  end
end
