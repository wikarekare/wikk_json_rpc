# Temporary addition to RCP, while we hunt and kill its current use.
class RPC
  # Iterator for time ranges.
  # @param start_time (Time) first date
  # @param end_time (Time) upto, but not including this date
  # @param step (Integer) seconds to increment time by
  # @yield (Time) times in the range
  def time_range(start_time:, end_time:, step: 60)
    while start_time < end_time
      yield(start_time)
      start_time += step
    end
  end
end
