require "test_helper"
require "timeout"

class RecordChildQualificationConcurrencyTest <
    ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )

    @series = Record.create!(
      french_title: "Série du test concurrent",
      record_kind: "series",
      language_version: @language_version
    )

    @child = @series.children.create!(
      french_title: "Enfant à qualifier",
      record_kind: "undetermined",
      language_version: @language_version
    )
  end

  teardown do
    @series&.destroy!
    @language_version&.destroy!
  end

  test "rechecks eligibility after a concurrent change commits" do
    worker = nil
    worker_pid = Queue.new

    Record.connection_pool.with_connection do |connection|
      connection.transaction do
        @child.update!(record_kind: "episode")

        worker = Thread.new do
          Record.connection_pool.with_connection do |worker_connection|
            worker_connection.execute("SET lock_timeout = '5s'")

            begin
              parent = Record.find(@series.id)
              worker_pid << worker_connection.select_value(
                "SELECT pg_backend_pid()"
              )

              operation = RecordChildQualification.new(
                parent: parent,
                child_ids: [@child.id],
                record_kind: "season"
              )

              [operation.call, operation.errors[:child_ids].any?]
            ensure
              worker_connection.execute("RESET lock_timeout")
            end
          end
        end

        pid = Timeout.timeout(3) { worker_pid.pop }

        assert_not_equal(
          connection.select_value("SELECT pg_backend_pid()").to_i,
          pid.to_i,
          "Le test doit utiliser deux connexions PostgreSQL distinctes"
        )

        wait_until_blocked(connection, pid, worker)
      end
    end

    assert worker.join(7), "La qualification concurrente ne termine pas"

    success, selection_error = worker.value

    assert_equal false, success
    assert selection_error
    assert_equal "episode", @child.reload.record_kind
  ensure
    worker&.join(7)
  end

  private

  def wait_until_blocked(connection, pid, worker)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3

    loop do
      unless worker.alive?
        result = worker.value
        flunk "La qualification a terminé sans attendre : #{result.inspect}"
      end

      blocked = Record.uncached do
        connection.select_value(
          "SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0"
        )
      end

      return if blocked

      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        flunk "La qualification n’a pas attendu la transaction concurrente"
      end

      sleep 0.01
    end
  end
end
