import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleeunit/should

pub fn permanent_child_restarts_test() {
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

pub fn rest_for_one_restarts_later_children_test() {
  let db_name = process.new_name("otp_test_db")
  let http_name = process.new_name("otp_test_http")

  let db_child = fake_child(db_name)
  let http_child = fake_child(http_name)

  let assert Ok(started) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.restart_tolerance(3, 10)
    |> supervisor.add(db_child)
    |> supervisor.add(http_child)
    |> supervisor.start

  let assert Ok(db_pid_1) = wait_for_named_process(db_name, 10)
  let assert Ok(http_pid_1) = wait_for_named_process(http_name, 10)

  process.send_abnormal_exit(db_pid_1, "db child failure")

  let assert Ok(db_pid_2) = wait_for_new_process(db_name, db_pid_1, 20)
  let assert Ok(http_pid_2) = wait_for_new_process(http_name, http_pid_1, 20)

  db_pid_2
  |> process.is_alive
  |> should.equal(True)

  http_pid_2
  |> process.is_alive
  |> should.equal(True)

  process.send_abnormal_exit(http_pid_2, "http child failure")

  let assert Ok(http_pid_3) = wait_for_new_process(http_name, http_pid_2, 20)

  db_pid_2
  |> process.is_alive
  |> should.equal(True)

  http_pid_3
  |> process.is_alive
  |> should.equal(True)

  process.send_exit(started.pid)
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
