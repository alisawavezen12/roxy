import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleeunit/should

pub fn root_supervisor_stops_children_in_dependency_order_test() {
  let db_name = process.new_name("shutdown_policy_db")
  let limiter_name = process.new_name("shutdown_policy_limiter")
  let http_name = process.new_name("shutdown_policy_http")

  let assert Ok(started) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.add(fake_child(db_name))
    |> supervisor.add(fake_child(limiter_name))
    |> supervisor.add(fake_child(http_name))
    |> supervisor.start

  let assert Ok(db_pid) = wait_for_named_process(db_name, 10)
  let assert Ok(limiter_pid) = wait_for_named_process(limiter_name, 10)
  let assert Ok(http_pid) = wait_for_named_process(http_name, 10)

  process.send_exit(started.pid)
  process.sleep(50)

  process.is_alive(http_pid)
  |> should.equal(False)
  process.is_alive(limiter_pid)
  |> should.equal(False)
  process.is_alive(db_pid)
  |> should.equal(False)
}

fn fake_child(name: process.Name(Nil)) -> supervision.ChildSpecification(Nil) {
  supervision.worker(fn() {
    let pid =
      process.spawn(fn() {
        let _ = process.register(process.self(), name)
        process.sleep_forever()
      })
    Ok(actor.Started(pid, Nil))
  })
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
