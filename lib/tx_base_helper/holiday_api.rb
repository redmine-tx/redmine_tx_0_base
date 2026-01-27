module TxBaseHelper
  # 공휴일 API 인터페이스
  # 실제 구현은 redmine_tx_more_calendar 플러그인에 위임
  # 향후 구현을 이 플러그인으로 이동할 예정
  class HolidayApi
    class << self
      # 특정 날짜가 공휴일인지 확인
      # @param date [Date, Time, String] 확인할 날짜
      # @return [Boolean] 공휴일 여부
      # @example
      #   TxBaseHelper::HolidayApi.holiday?(Date.today)
      #   # => true or false
      def holiday?(date)
        ensure_holiday_available!
        Holiday.holiday?(date)
      end

      # 날짜 범위 내의 공휴일 목록 조회
      # @param start_date [Date, Time, String] 시작 날짜
      # @param end_date [Date, Time, String] 종료 날짜
      # @return [Hash] { date => { id: x, date: date, name: name } }
      # @example
      #   TxBaseHelper::HolidayApi.for_date_range(Date.today, Date.today + 30.days)
      #   # => { Date(2024-01-01) => { id: 1, date: Date(2024-01-01), name: "신정" }, ... }
      def for_date_range(start_date, end_date)
        ensure_holiday_available!
        Holiday.for_date_range(start_date, end_date)
      end

      # 공휴일 데이터 업데이트 (작년, 올해, 내년)
      # @return [void]
      # @example
      #   TxBaseHelper::HolidayApi.update!
      def update!
        ensure_holiday_available!
        Holiday.update
      end

      # 특정 연도의 공휴일 동기화
      # @param year [Integer] 연도
      # @return [Array<Integer>] [신규 추가된 공휴일 수, 전체 공휴일 수]
      # @example
      #   TxBaseHelper::HolidayApi.sync(2024)
      #   # => [5, 15]
      def sync(year)
        ensure_holiday_available!
        Holiday.sync(year)
      end

      # 캐시 클리어 (테스트나 메모리 관리용)
      # @return [void]
      def clear_cache!
        return unless holiday_available?
        Holiday.clear_cache!
      end

      # 캐시 상태 확인 (디버깅용)
      # @return [Hash] 캐시 정보
      # @example
      #   TxBaseHelper::HolidayApi.cache_info
      #   # => { cached_ranges_count: 2, cached_holidays_count: 20, ... }
      def cache_info
        ensure_holiday_available!
        Holiday.cache_info
      end

      # 공휴일 기능 사용 가능 여부 확인
      # @return [Boolean]
      def available?
        holiday_available?
      end

      private

      # Holiday 모델이 로드되었는지 확인
      def holiday_available?
        defined?(Holiday) && Holiday.respond_to?(:holiday?)
      end

      # Holiday 모델이 없으면 에러 발생
      def ensure_holiday_available!
        unless holiday_available?
          raise NotImplementedError,
            "Holiday feature is not available. Please install redmine_tx_more_calendar plugin."
        end
      end
    end
  end
end
