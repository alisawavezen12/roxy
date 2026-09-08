import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleeunit/should

pub fn rest_for_one_restarts_failed_child_test() {
  let name = process.new_name("otp_test_child")
  let child =
    supervision.worker(fn() {
      let pid =
        process.spawn(fn() {
          let _ = process.register(process.self(), name)
          process.sleep_forever()
        })
      Ok(actor.Started(pid, Nil))
    })

  let assert Ok(started) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.restart_tolerance(1, 10)
    |> supervisor.add(child)
    |> supervisor.start

  let assert Ok(first_pid) = wait_for_named_process(name, 10)

  first_pid
  |> process.is_alive
  |> should.equal(True)

  process.send_abnormal_exit(first_pid, "test failure")
  process.sleep(20)

  let assert Ok(second_pid) = wait_for_new_process(name, first_pid, 10)
  second_pid
  |> process.is_alive
  |> should.equal(True)

  process.send_exit(started.pid)
}

fn wait_for_named_process(
  name: process.Name(Nil),
  attempts: Int,
) -> Result(process.Pid, Nil) {
  case process.named(name) {
    Ok(pid) -> Ok(pid)
    Error(_) if attempts > 0 -> {
      process.sleep(10)
      wait_for_named_process(name, attempts - 1)
    }
    Error(_) -> Error(Nil)
  }
}

fn wait_for_new_process(
  name: process.Name(Nil),
  previous: process.Pid,
  attempts: Int,
) -> Result(process.Pid, Nil) {
  case process.named(name) {
    Ok(pid) if pid != previous -> Ok(pid)
    _ if attempts > 0 -> {
      process.sleep(10)
      wait_for_new_process(name, previous, attempts - 1)
    }
    _ -> Error(Nil)
  }
}
